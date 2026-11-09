-- y copies paths relative to nvim's cwd; Y copies absolute paths.
-- Named visual commands also handle Neo-tree's multi-selection.
local function yank_path(state, nodes)
  nodes = nodes or { (state.tree:get_node()) }
  local paths = {}
  for _, node in ipairs(nodes) do
    if node.path then
      local path = state.config.absolute and node.path or vim.fn.fnamemodify(node.path, ":.")
      paths[#paths + 1] = (path:gsub("\\", "/"))
    end
  end
  if #paths == 0 then
    return
  end
  vim.fn.setreg(vim.v.register or "+", table.concat(paths, "\n"), "l")

  -- Keep y/Y followed by p working through Neo-tree's file clipboard.
  local commands = require("neo-tree.sources.common.commands")
  commands.clear_clipboard(state)
  commands.copy_to_clipboard_visual(state, nodes)
  commands.clear_selection(state)
  vim.notify(#paths == 1 and ("Yanked " .. paths[1]) or ("Yanked " .. #paths .. " paths"))
end

return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    commands = {
      yank_path = yank_path,
      yank_path_visual = yank_path,
    },
    window = {
      mappings = {
        ["y"] = { "yank_path", config = { absolute = false }, desc = "Copy Relative Path" },
        ["Y"] = { "yank_path", config = { absolute = true }, desc = "Copy Absolute Path" },
      },
    },
  },
}
