-- snacks explorer：y 复制相对路径（相对 nvim cwd），Y 复制绝对路径；支持多选与可视模式
-- 默认的 y 复制绝对路径并可配合 p 粘贴（复制文件）；改为相对路径后 p 依然可用（按 cwd 解析），
-- 若 cwd 已切换，用 Y 再 p 即可。
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

-- 文件树是浮在 layout 底座（普通 split）上的浮动窗口，从浮窗执行 wincmd 总会跳到编辑区，
-- vim-tmux-navigator 因此永远判断为“已在 nvim 内切换”，不会切到 tmux pane；
-- 而把焦点切到底座又会被 snacks 立刻转走。
-- 这里用 nvim_win_call（不触发 WinEnter）在底座窗口上查询相邻窗口：
-- 没有相邻窗口 => 已在 nvim 边缘，交给 tmux 切 pane；否则跳到相邻窗口。
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
          },
          win = {
            list = {
              keys = {
                ["y"] = { "yank_relative", mode = { "n", "x" } },
                ["Y"] = { "yank_absolute", mode = { "n", "x" } },
                ["<c-h>"] = "navigate_left",
                ["<c-l>"] = "navigate_right",
              },
            },
          },
        },
      },
    },
  },
}
