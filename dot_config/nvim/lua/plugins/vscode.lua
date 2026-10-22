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
}
