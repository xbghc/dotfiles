local wezterm = require("wezterm")
local config = wezterm.config_builder()

if wezterm.target_triple:find("windows") then
  config.default_prog = { "pwsh.exe", "-NoLogo" }
end

config.color_scheme = "Catppuccin Latte"
config.font_size = 10
config.initial_cols = 120
config.initial_rows = 28

return config
