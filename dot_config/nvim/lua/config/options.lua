-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.autoformat = false -- disable format on save (toggle with <leader>uf)
vim.g.lazyvim_ts_lsp = "tsc" -- TypeScript LSP: tsc (native TS7, formerly tsgo)
vim.opt.title = true -- set the terminal/tmux pane title from nvim
