-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.autoformat = false -- 关闭保存时自动格式化（<leader>uf 可切换）
vim.g.lazyvim_ts_lsp = "tsc" -- TypeScript LSP 使用 tsc（TS7 原生版，原 tsgo）
