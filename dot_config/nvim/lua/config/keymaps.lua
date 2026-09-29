-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- 复制当前文件路径（统一使用 / 分隔符）
-- 普通模式：<leader>fl 复制 path:行号；可视模式：复制 path:起始行-结束行
local function copy_path(absolute, with_line)
  return function()
    local path = vim.fn.expand(absolute and "%:p" or "%:.")
    if path == "" then
      return vim.notify("当前 buffer 没有文件路径", vim.log.levels.WARN)
    end
    path = path:gsub("\\", "/")
    if with_line then
      local s, e = vim.fn.line("v"), vim.fn.line(".")
      if s > e then
        s, e = e, s
      end
      path = path .. ":" .. s .. (s ~= e and ("-" .. e) or "")
      if vim.fn.mode():match("[vV\22]") then
        vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
      end
    end
    vim.fn.setreg("+", path)
    vim.notify(path, vim.log.levels.INFO, { title = "Copied" })
  end
end

vim.keymap.set("n", "<leader>fy", copy_path(false, false), { desc = "Copy Relative Path" })
vim.keymap.set("n", "<leader>fY", copy_path(true, false), { desc = "Copy Absolute Path" })
vim.keymap.set({ "n", "x" }, "<leader>fl", copy_path(false, true), { desc = "Copy Relative Path:Line" })
vim.keymap.set({ "n", "x" }, "<leader>fL", copy_path(true, true), { desc = "Copy Absolute Path:Line" })
