"""Idle compaction through the existing Codex daemon. No transcript rewriting."""

from __future__ import annotations

import argparse
import contextlib
import json
import os
from pathlib import Path
import queue
import re
import shutil
import socket
import sqlite3
import subprocess
import sys
import threading
import time
import tomllib
import uuid


IDLE_SECONDS = 25 * 60
RPC_TIMEOUT = 15
POLL_SECONDS = 2


def data_dir() -> Path:
    configured = os.environ.get("PLUGIN_DATA")
    if configured:
        return Path(configured)
    codex_dir = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
    return codex_dir / "idle-compact"


def supports_cache_policy(model: str) -> bool:
    """30m TTL is documented for GPT-5.6 and later; unknown models opt out."""
    match = re.match(r"^gpt-(\d+)(?:\.(\d+))?(?:-|$)", model)
    return bool(match and (int(match[1]), int(match[2] or 0)) >= (5, 6))


def plugin_enabled() -> bool:
    codex_dir = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
    try:
        config = tomllib.loads((codex_dir / "config.toml").read_text(encoding="utf-8"))
        return config.get("plugins", {}).get("idle-compact@chezmoi-local", {}).get("enabled") is True
    except (OSError, ValueError):
        return False


class State:
    def __init__(self, directory: Path):
        directory.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(directory / "state.sqlite3", timeout=1)
        self.db.execute("CREATE TABLE IF NOT EXISTS sessions (id TEXT PRIMARY KEY, state TEXT NOT NULL)")
        self.db.commit()

    @contextlib.contextmanager
    def edit(self, session: str):
        self.db.execute("BEGIN IMMEDIATE")
        try:
            row = self.db.execute("SELECT state FROM sessions WHERE id = ?", (session,)).fetchone()
            state = json.loads(row[0]) if row else {}
            yield state
            self.db.execute("INSERT OR REPLACE INTO sessions VALUES (?, ?)", (session, json.dumps(state)))
            self.db.commit()
        except BaseException:
            self.db.rollback()
            raise

    def read(self, session: str) -> dict:
        row = self.db.execute("SELECT state FROM sessions WHERE id = ?", (session,)).fetchone()
        return json.loads(row[0]) if row else {}

    def close(self):
        self.db.close()


def event_update(state: dict, event: dict, now: float) -> tuple[dict, str | None]:
    """Return hook output and an optional worker generation to launch."""
    kind = event.get("hook_event_name")
    turn = event.get("turn_id")
    if kind == "UserPromptSubmit":
        state.update(generation=uuid.uuid4().hex, phase="active", dirty=True, turn=turn,
                     model=event.get("model", ""), updated=now)
    elif kind == "Stop":
        # Do not rearm compaction turns, duplicated hooks, or an older turn's late Stop.
        if not state.get("dirty") or state.get("turn") != turn or state.get("phase") != "active":
            return {}, None
        model = event.get("model") or state.get("model", "")
        if not supports_cache_policy(model):
            state.update(phase="unsupported-model", dirty=False)
            return {}, None
        generation = uuid.uuid4().hex
        state.update(generation=generation, phase="armed", model=model, updated=now,
                     deadline=now + IDLE_SECONDS, transcript=event.get("transcript_path"),
                     cwd=event.get("cwd"), result=None)
        return {}, generation
    elif kind == "PreCompact":
        # Final cancellation check if input arrived between our status read and RPC.
        if state.get("pending_until", 0) > now and state.get("pending_generation") != state.get("generation"):
            state.pop("pending_until", None)
            return {"continue": False, "stopReason": "Idle compaction cancelled because new input arrived."}, None
        state.update(generation=uuid.uuid4().hex, phase="compacting", dirty=False, updated=now)
    elif kind == "PostCompact":
        state.update(generation=uuid.uuid4().hex, phase="compacted", dirty=False,
                     updated=now, result="compaction-completed")
        state.pop("pending_until", None)
    elif kind in ("Interrupt", "SessionEnd", "SessionStart"):
        state.update(generation=uuid.uuid4().hex, phase="cancelled", dirty=False, updated=now)
    return {}, None


def resolve_codex() -> str:
    for name in ("CODEX_IDLE_COMPACT_CODEX", "CODEX_CLI_PATH"):
        value = os.environ.get(name)
        if value and Path(value).is_file():
            return value
    found = shutil.which("codex")
    if found:
        return found
    codex_dir = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
    executable = "codex.exe" if os.name == "nt" else "codex"
    managed = codex_dir / "packages" / "app-server-daemon" / "current" / "bin" / executable
    if managed.is_file():
        return str(managed)
    raise RuntimeError("Codex CLI unavailable; set CODEX_IDLE_COMPACT_CODEX to its executable.")


class ProxySocket:
    """Socket adapter for WebSocket over `codex app-server proxy` pipes.

    The control socket speaks WebSocket, not JSONL. The proxy also handles
    Windows, where Python may not expose AF_UNIX. No new daemon is started.
    """

    def __init__(self, executable: str):
        options = {"creationflags": subprocess.CREATE_NO_WINDOW} if os.name == "nt" else {}
        self.proc = subprocess.Popen([executable, "app-server", "proxy"], stdin=subprocess.PIPE,
                                     stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, **options)
        self.timeout = RPC_TIMEOUT
        self.buffer = bytearray()
        self.chunks = queue.Queue()
        self.closed = False
        self.eof = False
        threading.Thread(target=self._read, daemon=True).start()

    def _read(self):
        try:
            while True:
                chunk = os.read(self.proc.stdout.fileno(), 65536)
                self.chunks.put(chunk)
                if not chunk:
                    return
        except OSError:
            self.chunks.put(b"")

    def gettimeout(self):
        return self.timeout

    def settimeout(self, value):
        self.timeout = value

    def send(self, data):
        self.proc.stdin.write(data)
        self.proc.stdin.flush()
        return len(data)

    def recv(self, size):
        if not self.buffer and not self.eof:
            try:
                chunk = self.chunks.get(timeout=self.timeout)
            except queue.Empty as exc:
                raise socket.timeout("Codex control socket timed out") from exc
            self.eof = not chunk
            self.buffer.extend(chunk)
        data = bytes(self.buffer[:size])
        del self.buffer[:size]
        return data

    def shutdown(self, *_):
        pass

    def close(self):
        if self.closed:
            return
        self.closed = True
        if self.proc.poll() is None:
            self.proc.terminate()
        try:
            self.proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait(timeout=3)
        self.proc.stdin.close()
        self.proc.stdout.close()


class Rpc:
    def __init__(self):
        import websocket

        self.transport = ProxySocket(resolve_codex())
        self.counter = 0
        try:
            self.ws = websocket.create_connection("ws://localhost/", socket=self.transport,
                                                  timeout=RPC_TIMEOUT, suppress_origin=True)
            self.call("initialize", {"clientInfo": {"name": "idle_compact", "version": "0.1.0"},
                                     "capabilities": {"experimentalApi": True}})
            self.ws.send(json.dumps({"method": "initialized"}))
        except BaseException:
            self.close()
            raise

    def call(self, method: str, params: dict):
        self.counter += 1
        request_id = self.counter
        self.ws.send(json.dumps({"id": request_id, "method": method, "params": params}))
        deadline = time.monotonic() + RPC_TIMEOUT
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError(f"{method} timed out")
            self.ws.settimeout(remaining)
            packet = json.loads(self.ws.recv())
            if packet.get("id") == request_id and "method" not in packet:
                if "error" in packet:
                    raise RuntimeError(f"{method}: {packet['error'].get('message', 'RPC error')}")
                return packet["result"]
            if "method" in packet and "id" in packet:
                # This helper never approves tools or answers user questions.
                self.ws.send(json.dumps({"id": packet["id"], "error": {
                    "code": -32601, "message": "Idle Compact does not handle approval requests"}}))

    def close(self):
        self.transport.close()


def same_path(first, second) -> bool:
    return bool(first and second and os.path.normcase(os.path.abspath(first)) ==
                os.path.normcase(os.path.abspath(second)))


def compact_if_idle(store: State, session: str, generation: str, rpc, now=None) -> str:
    now = time.time() if now is None else now
    state = store.read(session)
    if state.get("generation") != generation or state.get("phase") != "armed":
        return "cancelled"
    if now < state["deadline"]:
        return "not-due"
    thread = rpc.call("thread/read", {"threadId": session, "includeTurns": False})["thread"]
    if thread.get("status", {}).get("type") != "idle":
        return "not-idle"
    # Avoid treating a shared session-tree id as the id of a fork or subagent.
    if thread.get("id") != session or not same_path(thread.get("path"), state.get("transcript")):
        return "thread-mismatch"
    if thread.get("updatedAt", 0) > state["updated"] + 1:
        return "new-activity"
    terminals = rpc.call("thread/backgroundTerminals/list", {"threadId": session, "limit": 1})
    if terminals.get("data") or terminals.get("nextCursor"):
        return "background-terminal"
    with store.edit(session) as current:
        if current.get("generation") != generation or current.get("phase") != "armed":
            return "cancelled"
        current.update(phase="requested", dirty=False, pending_generation=generation,
                       pending_until=time.time() + 30, result="compaction-requested")
    # Do not hold the database lock while Codex invokes PreCompact/PostCompact.
    rpc.call("thread/compact/start", {"threadId": session})
    return "compaction-requested"


def worker(directory: Path, session: str, generation: str):
    store = State(directory)
    rpc = None
    try:
        while True:
            state = store.read(session)
            if state.get("generation") != generation or state.get("phase") != "armed":
                return
            remaining = state["deadline"] - time.time()
            if remaining <= 0:
                break
            # A backward clock jump must not keep a worker alive indefinitely.
            if remaining > IDLE_SECONDS + 60:
                return
            time.sleep(min(POLL_SECONDS, remaining))
        if not plugin_enabled():
            with store.edit(session) as state:
                if state.get("generation") == generation:
                    state.update(phase="cancelled", dirty=False, result="plugin-disabled")
            return
        rpc = Rpc()
        result = compact_if_idle(store, session, generation, rpc)
        with store.edit(session) as state:
            if state.get("generation") == generation:
                state.update(phase="finished", dirty=False, result=result)
    except Exception as exc:
        with store.edit(session) as state:
            if state.get("generation") == generation:
                state.update(phase="error", dirty=False, result=str(exc)[:500])
    finally:
        if rpc:
            rpc.close()
        store.close()


def launch_worker(directory: Path, session: str, generation: str):
    args = [sys.executable, str(Path(__file__).resolve()), "worker", "--data", str(directory),
            "--session", session, "--generation", generation]
    options = {"creationflags": subprocess.CREATE_NO_WINDOW | subprocess.CREATE_NEW_PROCESS_GROUP} \
        if os.name == "nt" else {"start_new_session": True}
    subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, close_fds=True, **options)


def hook(event: dict, directory: Path):
    if not plugin_enabled():
        return {}
    session = event.get("session_id")
    if not isinstance(session, str) or not session:
        return {}
    store = State(directory)
    try:
        with store.edit(session) as state:
            output, generation = event_update(state, event, time.time())
        if generation:
            launch_worker(directory, session, generation)
        return output
    finally:
        store.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("hook", "worker", "check", "status"))
    parser.add_argument("--data", type=Path)
    parser.add_argument("--session")
    parser.add_argument("--generation")
    args = parser.parse_args()
    directory = args.data or data_dir()
    if args.mode == "hook":
        try:
            output = hook(json.load(sys.stdin), directory)
        except Exception as exc:
            output = {"systemMessage": f"Idle Compact: {type(exc).__name__}: {exc}"}
        print(json.dumps(output))
    elif args.mode == "worker":
        if not args.session or not args.generation:
            parser.error("worker requires --session and --generation")
        worker(directory, args.session, args.generation)
    elif args.mode == "check":
        rpc = Rpc()
        try:
            result = rpc.call("thread/loaded/list", {})
            print(f"Connected to existing Codex daemon; {len(result.get('data', []))} loaded threads.")
            print("Idle timer: 25 minutes. No compaction was requested.")
        finally:
            rpc.close()
    else:
        if not args.session:
            parser.error("status requires --session")
        store = State(directory)
        try:
            print(json.dumps(store.read(args.session), indent=2))
        finally:
            store.close()


if __name__ == "__main__":
    main()
