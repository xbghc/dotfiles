-- 颜色格式转换：光标放在颜色上执行 :CccConvert，在 rgb() 与 hex 之间互转
--   rgb(12, 34, 56)         <-> #0c2238
--   rgba(12, 34, 56, 0.5)   <-> #0c223880   （有透明通道则保留）
return {
  {
    "uga-rosa/ccc.nvim",
    cmd = { "CccConvert", "CccPick", "CccHighlighterToggle" },
    keys = {
      { "<leader>ch", "<cmd>CccConvert<cr>", desc = "Convert Color (rgb ↔ hex)" },
    },
    opts = function()
      local ccc = require("ccc")
      local convert = require("ccc.utils.convert")

      -- ccc 内置的 css_rgb 输出为 `rgb(12 34 56 / 50%)`，这里改为逗号写法
      local rgb_comma = {
        name = "RGB (comma)",
        str = function(RGB, A)
          local R, G, B = convert.rgb_format(RGB)
          if A then
            local alpha = ("%.2f"):format(A):gsub("0+$", ""):gsub("%.$", "")
            return ("rgba(%d, %d, %d, %s)"):format(R, G, B, alpha)
          end
          return ("rgb(%d, %d, %d)"):format(R, G, B)
        end,
      }

      return {
        convert = {
          { ccc.picker.css_rgb, ccc.output.hex },
          { ccc.picker.hex, rgb_comma },
        },
      }
    end,
  },
}
