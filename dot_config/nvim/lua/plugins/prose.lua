-- markdown 和纯文本文件：关闭 lint 与自动补全（"" 为无 filetype 的文件）
local prose_ft = { markdown = true, ["markdown.mdx"] = true, text = true, [""] = true }

return {
  -- 关闭 markdownlint 检查
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters_by_ft = {
        markdown = {},
        ["markdown.mdx"] = {},
      },
    },
  },
  -- markdown / 纯文本中关闭自动补全
  {
    "saghen/blink.cmp",
    optional = true,
    opts = {
      enabled = function()
        return not prose_ft[vim.bo.filetype]
      end,
    },
  },
}
