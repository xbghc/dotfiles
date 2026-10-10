-- VSCode (vscode-neovim) only; see config/vscode.lua for the keymaps.
-- LazyVim's vscode extra (imported automatically) disables every plugin that is not on its allow-list,
-- unless the spec sets `vscode = true` (see abolish.lua, ccc.lua).
if not vim.g.vscode then
  return {}
end

return {
  {
    "folke/snacks.nvim",
    -- Every snacks key opens a floating UI (picker, explorer, scratch, notification history, ...)
    -- that VSCode can't render; drop them all in favor of the VSCode commands mapped in config/vscode.lua
    keys = function()
      return {}
    end,
  },
  {
    -- vscode-neovim forces signcolumn=no; this pushes the marks to the xbghc.nvim-marks VSCode extension
    -- (installed from .chezmoidata/vscode.toml), which draws them in the gutter. Marks themselves stay native.
    "xbghc/vscode-nvim-marks",
    vscode = true,
    opts = {},
  },
}
