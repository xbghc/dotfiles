-- snacks explorer: y copies the relative path (to nvim's cwd), Y the absolute path; supports multi-select and visual mode
-- The default y copies absolute paths for use with p (copy files); p still works with relative paths (resolved against cwd);
-- if the cwd has changed, use Y then p.
local function yank(absolute)
  return function(picker)
    if vim.fn.mode():find("^[vV]") then
      picker.list:select()
    end
    local files = {} ---@type string[]
    for _, item in ipairs(picker:selected({ fallback = true })) do
      local path = Snacks.picker.util.path(item)
      if not absolute then
        path = vim.fn.fnamemodify(path, ":.")
      end
      files[#files + 1] = (path:gsub("\\", "/"))
    end
    picker.list:set_selected() -- clear selection
    vim.fn.setreg(vim.v.register or "+", table.concat(files, "\n"), "l")
    Snacks.notify.info(#files == 1 and ("Yanked " .. files[1]) or ("Yanked " .. #files .. " paths"))
  end
end

-- The file tree is a floating window over the layout's root (a regular split); wincmd from a float always jumps to the editor,
-- so vim-tmux-navigator always thinks it moved within nvim and never switches tmux panes;
-- and focusing the root window gets immediately redirected by snacks.
-- Instead, query the neighbor of the root window with nvim_win_call (no WinEnter):
-- no neighbor => at nvim's edge, let tmux switch panes; otherwise jump to the neighbor.
local function navigate(dir, tmux_flag)
  return function(picker)
    local root = picker.layout and picker.layout.root
    if not (root and root:win_valid()) then
      return vim.cmd("wincmd " .. dir)
    end
    local target = vim.api.nvim_win_call(root.win, function()
      return vim.fn.win_getid(vim.fn.winnr(dir))
    end)
    if target ~= root.win then
      vim.api.nvim_set_current_win(target)
    elseif vim.env.TMUX then
      vim.fn.system({ "tmux", "select-pane", "-t", vim.env.TMUX_PANE or "", tmux_flag })
    end
  end
end

return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = {
          actions = {
            yank_relative = yank(false),
            yank_absolute = yank(true),
            navigate_left = navigate("h", "-L"),
            navigate_right = navigate("l", "-R"),
            navigate_down = navigate("j", "-D"),
            navigate_up = navigate("k", "-U"),
          },
          win = {
            list = {
              keys = {
                ["y"] = { "yank_relative", mode = { "n", "x" } },
                ["Y"] = { "yank_absolute", mode = { "n", "x" } },
                ["<c-h>"] = "navigate_left",
                ["<c-l>"] = "navigate_right",
                ["<c-j>"] = "navigate_down", -- overrides default list_down (same as j)
                ["<c-k>"] = "navigate_up", -- overrides default list_up (same as k)
              },
            },
          },
        },
      },
    },
  },
}
