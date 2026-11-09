return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      flavour = "latte",
      highlight_overrides = {
        latte = function(colors)
          return {
            NeoTreeNormal = { link = "Normal" },
            NeoTreeNormalNC = { link = "NormalNC" },
            NeoTreeCursorLine = { link = "CursorLine" },
            NeoTreeWinSeparator = { link = "WinSeparator" },
            NeoTreeVertSplit = { link = "WinSeparator" },
            NeoTreeEndOfBuffer = { fg = colors.base, bg = colors.base },
            NeoTreeDotfile = { fg = colors.subtext0 },
            NeoTreeIgnored = { fg = colors.overlay0 },
          }
        end,
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "catppuccin-latte" },
  },
}
