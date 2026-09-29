-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- JS/TS：<leader>cv 生成 console.log(`expr: ${expr}`); 并复制到剪贴板
-- 普通模式用 treesitter 取光标所在的成员表达式（扩展到光标那一段为止），可视模式取选中文本
local function cursor_expression()
  local ok, node = pcall(vim.treesitter.get_node)
  if not ok or not node then
    return vim.fn.expand("<cword>")
  end
  local member = { member_expression = true, subscript_expression = true }
  -- 光标在成员表达式右侧（属性/下标）时向上扩展，扩展到光标所在那一段为止：
  -- user.profile.name 中光标在 user → user，在 profile → user.profile，在 name → user.profile.name
  while node:parent() and member[node:parent():type()] and node:parent():field("object")[1] ~= node do
    node = node:parent()
  end
  local text = vim.treesitter.get_node_text(node, 0)
  -- 只接受单行、看起来像表达式的节点，否则退回光标下的单词
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
