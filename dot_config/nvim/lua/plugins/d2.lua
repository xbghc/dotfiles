return {
  {
    "d2lang/d2-vim",
    ft = "d2",
    init = function()
      -- Let LazyVim/Conform control formatting, including the <leader>uf toggle.
      vim.g.d2_fmt_autosave = 0
    end,
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        d2 = { "d2" },
      },
    },
  },
}
