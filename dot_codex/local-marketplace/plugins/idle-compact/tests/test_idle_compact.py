import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("idle_compact", Path(__file__).parents[1] / "scripts/idle_compact.py")
plugin = importlib.util.module_from_spec(spec)
spec.loader.exec_module(plugin)


def event(kind, turn="turn-1", **extra):
    return dict(hook_event_name=kind, session_id="session-1", turn_id=turn,
                model="gpt-6-astra", transcript_path=str(Path("session.jsonl").resolve()), **extra)


class FakeRpc:
    def __init__(self, status="idle", terminals=None, after_read=None):
        self.calls = []
        self.status = status
        self.terminals = terminals or []
        self.after_read = after_read
        self.updated = 101

    def call(self, method, params):
        self.calls.append((method, params))
        if method == "thread/read":
            if self.after_read:
                self.after_read()
            return {"thread": {"id": "session-1", "path": str(Path("session.jsonl").resolve()),
                               "status": {"type": self.status}, "updatedAt": self.updated}}
        if method == "thread/backgroundTerminals/list":
            return {"data": self.terminals, "nextCursor": None}
        if method == "thread/compact/start":
            return {}
        raise AssertionError(method)

    def compactions(self):
        return sum(m == "thread/compact/start" for m, _ in self.calls)


class IdleCompactTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.store = plugin.State(Path(self.temp.name))
        self.addCleanup(self.temp.cleanup)
        self.addCleanup(self.store.close)

    def update(self, kind, turn="turn-1", now=100):
        with self.store.edit("session-1") as state:
            return plugin.event_update(state, event(kind, turn), now)

    def arm(self):
        self.update("UserPromptSubmit")
        return self.update("Stop", now=101)[1]

    def test_arms_at_25_minutes_and_compacts_once(self):
        generation = self.arm()
        rpc = FakeRpc()
        self.assertEqual(plugin.compact_if_idle(self.store, "session-1", generation, rpc, now=1600), "not-due")
        self.assertEqual(rpc.calls, [])
        self.assertEqual(plugin.compact_if_idle(self.store, "session-1", generation, rpc, now=1601), "compaction-requested")
        self.assertEqual(plugin.compact_if_idle(self.store, "session-1", generation, rpc, now=1700), "cancelled")
        self.assertEqual(rpc.compactions(), 1)

    def test_new_input_cancels_old_timer_and_stale_stop(self):
        generation = self.arm()
        self.update("UserPromptSubmit", turn="turn-2", now=200)
        self.assertIsNone(self.update("Stop", turn="turn-1", now=201)[1])
        rpc = FakeRpc()
        self.assertEqual(plugin.compact_if_idle(self.store, "session-1", generation, rpc, now=1700), "cancelled")
        self.assertEqual(rpc.calls, [])

    def test_duplicate_stop_does_not_spawn_another_timer(self):
        self.arm()
        self.assertIsNone(self.update("Stop", now=102)[1])

    def test_disabling_plugin_cancels_pending_compaction(self):
        generation = self.arm()
        with patch.object(plugin, "plugin_enabled", return_value=False), patch.object(plugin, "Rpc") as rpc:
            plugin.worker(Path(self.temp.name), "session-1", generation)
        rpc.assert_not_called()
        self.assertEqual(self.store.read("session-1")["result"], "plugin-disabled")

    def test_disabled_plugin_does_not_create_a_timer(self):
        with patch.object(plugin, "plugin_enabled", return_value=False), patch.object(plugin, "launch_worker") as launch:
            self.assertEqual(plugin.hook(event("UserPromptSubmit"), Path(self.temp.name)), {})
            self.assertEqual(plugin.hook(event("Stop"), Path(self.temp.name)), {})
        launch.assert_not_called()
        self.assertEqual(self.store.read("session-1"), {})

    def test_compaction_does_not_create_an_infinite_loop(self):
        self.arm()
        self.update("PreCompact", turn="compact-turn", now=1601)
        self.update("PostCompact", turn="compact-turn", now=1602)
        self.update("SessionStart", turn="compact-turn", now=1603)
        self.assertIsNone(self.update("Stop", turn="compact-turn", now=1604)[1])

    def test_busy_or_unloaded_thread_is_not_compacted(self):
        generation = self.arm()
        for status in ("active", "notLoaded", "systemError"):
            rpc = FakeRpc(status=status)
            self.assertEqual(plugin.compact_if_idle(self.store, "session-1", generation, rpc, now=1601), "not-idle")
            self.assertEqual(rpc.compactions(), 0)

    def test_background_terminal_blocks_compaction(self):
        generation = self.arm()
        rpc = FakeRpc(terminals=[{"processId": "42"}])
        self.assertEqual(plugin.compact_if_idle(self.store, "session-1", generation, rpc, now=1601), "background-terminal")
        self.assertEqual(rpc.compactions(), 0)

    def test_remote_activity_blocks_compaction(self):
        generation = self.arm()
        rpc = FakeRpc()
        rpc.updated = 800
        self.assertEqual(plugin.compact_if_idle(self.store, "session-1", generation, rpc, now=1601), "new-activity")
        self.assertEqual(rpc.compactions(), 0)

    def test_new_input_during_status_read_blocks_compaction(self):
        generation = self.arm()
        rpc = FakeRpc(after_read=lambda: self.update("UserPromptSubmit", turn="turn-2", now=1601))
        self.assertEqual(plugin.compact_if_idle(self.store, "session-1", generation, rpc, now=1601), "cancelled")
        self.assertEqual(rpc.compactions(), 0)

    def test_precompact_cancels_request_if_input_arrives_after_claim(self):
        generation = self.arm()
        plugin.compact_if_idle(self.store, "session-1", generation, FakeRpc(), now=1601)
        self.update("UserPromptSubmit", turn="turn-2", now=1602)
        output, _ = self.update("PreCompact", turn="compact-turn", now=1603)
        self.assertFalse(output["continue"])

    def test_fork_or_missing_transcript_cannot_target_another_thread(self):
        generation = self.arm()
        with self.store.edit("session-1") as state:
            state["transcript"] = str(Path("another-session.jsonl").resolve())
        rpc = FakeRpc()
        self.assertEqual(plugin.compact_if_idle(self.store, "session-1", generation, rpc, now=1601), "thread-mismatch")
        self.assertEqual(rpc.compactions(), 0)

    def test_interrupt_end_and_resume_cancel_timers(self):
        for kind in ("Interrupt", "SessionEnd", "SessionStart"):
            generation = self.arm()
            self.update(kind, now=200)
            self.assertEqual(plugin.compact_if_idle(self.store, "session-1", generation, FakeRpc(), now=1601), "cancelled")

    def test_unknown_and_older_models_are_not_assigned_a_guessed_ttl(self):
        for model in ("gpt-5.5", "gpt-5.3-codex", "custom", ""):
            state = {}
            first = event("UserPromptSubmit")
            first["model"] = model
            plugin.event_update(state, first, 100)
            last = event("Stop")
            last["model"] = model
            self.assertIsNone(plugin.event_update(state, last, 101)[1])
        for model in ("gpt-6-astra", "gpt-6.1-sol", "gpt-5.6-sol"):
            self.assertTrue(plugin.supports_cache_policy(model))


if __name__ == "__main__":
    unittest.main()
