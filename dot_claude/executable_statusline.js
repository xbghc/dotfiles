#!/usr/bin/env node
/**
 * Claude Code 状态栏脚本
 * 只显示两项：当前上下文占用 + 订阅用量（5 小时窗口 / 7 天窗口）。
 *
 * 数据来源：Claude Code 通过 stdin 传入的 JSON。
 *   - 上下文占用：context_window.{used_percentage, total_input_tokens, context_window_size}
 *   - 订阅用量：  rate_limits.{five_hour, seven_day}.used_percentage
 *     （订阅用量仅 Pro/Max 账号、且本会话发出过至少一次请求后才有数据）
 *
 * 设计：纯 stdin 解析，无文件 IO、无子进程，启动快、适合频繁刷新的状态栏。
 * 字段缺失时优雅降级为 “–”，不会报错。
 *
 * 调试：设置环境变量 CLAUDE_STATUSLINE_DEBUG=1 时，会把收到的原始 JSON
 *       写到 ~/.claude/statusline-last-input.json，方便排查真实数据结构。
 */

'use strict';

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => { raw += chunk; });
process.stdin.on('end', () => {
  let data = {};
  try { data = JSON.parse(raw) || {}; } catch { /* 容忍空/坏输入 */ }

  if (process.env.CLAUDE_STATUSLINE_DEBUG) {
    try {
      const fs = require('fs');
      const path = require('path');
      const os = require('os');
      fs.writeFileSync(path.join(os.homedir(), '.claude', 'statusline-last-input.json'), raw);
    } catch { /* 调试写盘失败不影响状态栏 */ }
  }

  process.stdout.write(render(data));
});

// ---- ANSI 颜色 ----
const C = {
  reset: '\x1b[0m',
  dim: '\x1b[2m',
  gray: '\x1b[90m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
};
const NO_COLOR = !!process.env.NO_COLOR;
const paint = (s, color) => (NO_COLOR ? s : color + s + C.reset);
// 用量阈值配色：<50% 绿、50~79% 黄、>=80% 红
const byPct = (p) => (p >= 80 ? C.red : p >= 50 ? C.yellow : C.green);

// 把 token 数格式化成人类可读：16234 -> 16.2k，1000000 -> 1M
function fmtTokens(n) {
  if (!Number.isFinite(n)) return '?';
  if (n >= 1e6) return (n / 1e6).toFixed(1).replace(/\.0$/, '') + 'M';
  if (n >= 1e3) return (n / 1e3).toFixed(1).replace(/\.0$/, '') + 'k';
  return String(n);
}

// 从 rate_limit 对象里取出刷新时间戳，兼容多种可能的字段命名与单位（秒/毫秒）
function pickResetAt(obj) {
  if (!obj) return undefined;
  let v = obj.resets_at ?? obj.reset_at ?? obj.resetsAt ?? obj.reset ?? obj.resets_at_unix;
  if (typeof v === 'string' && /^\d+$/.test(v)) v = Number(v);
  if (!Number.isFinite(v)) return undefined;
  return v > 1e12 ? Math.floor(v / 1000) : v; // 毫秒 -> 秒
}

// 把刷新时间戳格式化成“距现在还剩多久”：2h13m / 47m / 5d3h / <1m
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

  // ---- 上下文占用 ----
  const cw = d.context_window;
  if (cw && (cw.used_percentage != null || cw.total_input_tokens != null)) {
    const pct = Math.round(cw.used_percentage ?? 0);
    const used = cw.total_input_tokens;     // 已含缓存读写
    const size = cw.context_window_size;
    let tok = '';
    if (Number.isFinite(used)) {
      tok = fmtTokens(used) + (Number.isFinite(size) ? '/' + fmtTokens(size) : '') + ' ';
    }
    seg.push(paint('ctx', C.gray) + ' ' + tok + paint(pct + '%', byPct(pct)));
  } else {
    seg.push(paint('ctx', C.gray) + ' ' + paint('–', C.dim));
  }

  // ---- 订阅用量 ----
  const rl = d.rate_limits;
  const subParts = [];
  const rlSeg = (label, obj) => {
    if (obj && obj.used_percentage != null) {
      const p = Math.round(obj.used_percentage);
      let out = paint(label, C.gray) + ' ' + paint(p + '%', byPct(p));
      const inStr = fmtResetIn(pickResetAt(obj));
      if (inStr) out += paint(' (' + inStr + ')', C.dim); // 括号内为距刷新剩余时间
      return out;
    }
    return null;
  };
  if (rl) {
    const a = rlSeg('5h', rl.five_hour);
    const b = rlSeg('7d', rl.seven_day);
    if (a) subParts.push(a);
    if (b) subParts.push(b);
  }
  if (subParts.length) {
    seg.push(subParts.join(paint(' · ', C.dim)));
  } else {
    // 非 Pro/Max，或本会话还没发出请求 -> 暂无订阅数据
    seg.push(paint('sub –', C.dim));
  }

  return seg.join(paint('  │  ', C.dim));
}
