-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Copy the current file path (always using / as separator)
-- Normal mode: <leader>fl copies path:line; visual mode: path:start-end
local function buf_path(absolute)
  if vim.g.vscode then
    -- Buffer names of non-local files are URIs (vscode-remote://...), so ask VSCode for the path
    return require("vscode").eval(
      [[
        const doc = vscode.window.activeTextEditor?.document;
        if (!doc || doc.isUntitled) return "";
        return args.absolute ? doc.uri.fsPath : vscode.workspace.asRelativePath(doc.uri, false);
      ]],
      { args = { absolute = absolute } }
    )
  end
  return vim.fn.expand(absolute and "%:p" or "%:.")
end

local function copy_path(absolute, with_line)
  return function()
    local path = buf_path(absolute)
    if path == "" then
      return vim.notify("Current buffer has no file path", vim.log.levels.WARN)
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

if vim.g.vscode then
  require("config.vscode")
end
