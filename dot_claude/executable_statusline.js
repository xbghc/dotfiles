#!/usr/bin/env node
/**
 * Claude Code status line script
 * Shows two things only: current context usage + subscription usage (5-hour / 7-day windows).
 *
 * Data source: JSON passed by Claude Code on stdin.
 *   - Context usage:      context_window.{used_percentage, total_input_tokens, context_window_size}
 *   - Subscription usage: rate_limits.{five_hour, seven_day}.used_percentage
 *     (only available on Pro/Max accounts, after at least one request in this session)
 *
 * Design: pure stdin parsing, no file IO, no child processes; fast startup for frequent refreshes.
 * Missing fields degrade gracefully to "–" instead of erroring.
 *
 * Debug: with CLAUDE_STATUSLINE_DEBUG=1 the raw JSON received is written
 *        to ~/.claude/statusline-last-input.json to inspect the real data shape.
 */

'use strict';

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => { raw += chunk; });
process.stdin.on('end', () => {
  let data = {};
  try { data = JSON.parse(raw) || {}; } catch { /* tolerate empty/invalid input */ }

  if (process.env.CLAUDE_STATUSLINE_DEBUG) {
    try {
      const fs = require('fs');
      const path = require('path');
      const os = require('os');
      fs.writeFileSync(path.join(os.homedir(), '.claude', 'statusline-last-input.json'), raw);
    } catch { /* a failed debug write must not break the status line */ }
  }

  process.stdout.write(render(data));
});

// ---- Colors: Catppuccin Latte (matches the Claude Code theme, terminal, nvim, tmux) ----
// 24-bit truecolor, independent of the terminal's ANSI palette
const rgb = (hex) => {
  const n = parseInt(hex.slice(1), 16);
  return `\x1b[38;2;${(n >> 16) & 255};${(n >> 8) & 255};${n & 255}m`;
};
const C = {
  reset: '\x1b[0m',
  dim: rgb('#9ca0b0'), // Overlay0: separators, reset times in parentheses, no data
  gray: rgb('#6c6f85'), // Subtext0: label icons (ctx / 5h / 7d)
  green: rgb('#40a02b'), // Green
  yellow: rgb('#df8e1d'), // Yellow
  red: rgb('#d20f39'), // Red
};
// Nerd Font glyphs used as labels (written as escapes so editors/fonts can't mangle them)
const ICON = {
  ctx: '\u{f09d1}', // nf-md-brain: context window
  h5: '\u{f0150}', // nf-md-clock_outline: 5-hour window
  d7: '\u{f00ed}', // nf-md-calendar: 7-day window
};
const NO_COLOR = !!process.env.NO_COLOR;
const paint = (s, color) => (NO_COLOR ? s : color + s + C.reset);
// Usage thresholds: <50% green, 50-79% yellow, >=80% red
const byPct = (p) => (p >= 80 ? C.red : p >= 50 ? C.yellow : C.green);

// Human-readable token counts: 16234 -> 16.2k, 1000000 -> 1M
function fmtTokens(n) {
  if (!Number.isFinite(n)) return '?';
  if (n >= 1e6) return (n / 1e6).toFixed(1).replace(/\.0$/, '') + 'M';
  if (n >= 1e3) return (n / 1e3).toFixed(1).replace(/\.0$/, '') + 'k';
  return String(n);
}

// Extract the reset timestamp from a rate_limit object, tolerating several field names and units (s/ms)
function pickResetAt(obj) {
  if (!obj) return undefined;
  let v = obj.resets_at ?? obj.reset_at ?? obj.resetsAt ?? obj.reset ?? obj.resets_at_unix;
  if (typeof v === 'string' && /^\d+$/.test(v)) v = Number(v);
  if (!Number.isFinite(v)) return undefined;
  return v > 1e12 ? Math.floor(v / 1000) : v; // ms -> s
}

// Format the reset timestamp as time remaining: 2h13m / 47m / 5d3h / <1m
function fmtResetIn(resetAtSec) {
  if (!Number.isFinite(resetAtSec)) return '';
  const s = resetAtSec - Math.floor(Date.now() / 1000);
  if (s <= 0) return 'now';
  const d = Math.floor(s / 86400);
  const h = Math.floor((s % 86400) / 3600);
  const m = Math.floor((s % 3600) / 60);
  if (d > 0) return d + 'd' + (h > 0 ? h + 'h' : '');
  if (h > 0) return h + 'h' + (m > 0 ? m + 'm' : '');
  if (m > 0) return m + 'm';
  return '<1m';
}

function render(d) {
  const seg = [];

  // ---- Context usage ----
  const cw = d.context_window;
  if (cw && (cw.used_percentage != null || cw.total_input_tokens != null)) {
    const pct = Math.round(cw.used_percentage ?? 0);
    const used = cw.total_input_tokens;     // includes cache reads/writes
    const size = cw.context_window_size;
    let tok = '';
    if (Number.isFinite(used)) {
      tok = fmtTokens(used) + (Number.isFinite(size) ? '/' + fmtTokens(size) : '') + ' ';
    }
    seg.push(paint(ICON.ctx, C.gray) + ' ' + tok + paint(pct + '%', byPct(pct)));
  } else {
    seg.push(paint(ICON.ctx, C.gray) + ' ' + paint('–', C.dim));
  }

  // ---- Subscription usage ----
  const rl = d.rate_limits;
  const subParts = [];
  const rlSeg = (label, obj) => {
    if (obj && obj.used_percentage != null) {
      const p = Math.round(obj.used_percentage);
      let out = paint(label, C.gray) + ' ' + paint(p + '%', byPct(p));
      const inStr = fmtResetIn(pickResetAt(obj));
      if (inStr) out += paint(' (' + inStr + ')', C.dim); // time until reset, in parentheses
      return out;
    }
    return null;
  };
  if (rl) {
    const a = rlSeg(ICON.h5, rl.five_hour);
    const b = rlSeg(ICON.d7, rl.seven_day);
    if (a) subParts.push(a);
    if (b) subParts.push(b);
  }
  if (subParts.length) {
    seg.push(subParts.join(paint(' · ', C.dim)));
  } else {
    // not Pro/Max, or no request sent yet in this session -> no subscription data
    seg.push(paint(ICON.h5 + ' –', C.dim));
  }

  return seg.join(paint('  │  ', C.dim));
}
