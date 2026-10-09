-- Color conversion: run :CccConvert on a color to convert between rgb() and hex
--   rgb(12, 34, 56)         <-> #0c2238
--   rgba(12, 34, 56, 0.5)   <-> #0c223880   (alpha is preserved when present)
return {
  {
    "uga-rosa/ccc.nvim",
    vscode = true,
    cmd = { "CccConvert", "CccPick", "CccHighlighterToggle" },
    keys = {
      { "<leader>ch", "<cmd>CccConvert<cr>", desc = "Convert Color (rgb ↔ hex)" },
    },
    opts = function()
      local ccc = require("ccc")
      local convert = require("ccc.utils.convert")

      -- ccc's built-in css_rgb output is `rgb(12 34 56 / 50%)`; use the comma syntax instead
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
