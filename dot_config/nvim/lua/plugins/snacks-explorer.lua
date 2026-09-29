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

return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = {
          actions = {
            yank_relative = yank(false),
            yank_absolute = yank(true),
          },
          win = {
            list = {
              keys = {
                ["y"] = { "yank_relative", mode = { "n", "x" } },
                ["Y"] = { "yank_absolute", mode = { "n", "x" } },
              },
            },
          },
        },
      },
    },
  },
}
