-- markdown, plain text, git commit messages: disable linting and completion ("" = buffers without a filetype)
local prose_ft = { markdown = true, ["markdown.mdx"] = true, text = true, gitcommit = true, [""] = true }

return {
  -- disable markdownlint
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
  -- disable completion in markdown / plain text
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
