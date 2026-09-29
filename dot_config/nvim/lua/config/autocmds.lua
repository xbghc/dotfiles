-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- JS/TS: <leader>cv builds console.log(`expr: ${expr}`); and copies it to the clipboard
-- Normal mode: treesitter member expression under the cursor (up to the segment under the cursor); visual mode: the selection
local function cursor_expression()
  local ok, node = pcall(vim.treesitter.get_node)
  if not ok or not node then
    return vim.fn.expand("<cword>")
  end
  local member = { member_expression = true, subscript_expression = true }
  -- Expand upward only while the cursor is on the right side (property/index) of a member expression:
  -- in user.profile.name, cursor on user → user, on profile → user.profile, on name → user.profile.name
  while node:parent() and member[node:parent():type()] and node:parent():field("object")[1] ~= node do
    node = node:parent()
  end
  local text = vim.treesitter.get_node_text(node, 0)
  -- Only accept single-line, expression-like nodes; otherwise fall back to the word under the cursor
  if text:find("\n") or not text:match("^[%w_$][%w_$%.%[%]'\"?]*$") then
    return vim.fn.expand("<cword>")
  end
  return text
end

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("console_log_expr", { clear = true }),
  pattern = { "javascript", "typescript", "javascriptreact", "typescriptreact", "vue", "svelte" },
  callback = function(ev)
    vim.keymap.set({ "n", "x" }, "<leader>cv", function()
      local expr
      if vim.fn.mode():match("[vV\22]") then
        local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
        expr = vim.trim(table.concat(lines, " "))
        vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
      else
        expr = cursor_expression()
      end
      if expr == "" then
        return
      end
      local text = ("console.log(`%s: ${%s}`);"):format(expr, expr)
      vim.fn.setreg("+", text)
      vim.notify(text, vim.log.levels.INFO, { title = "Copied" })
    end, { buffer = ev.buf, desc = "Copy console.log(expr)" })
  end,
})
