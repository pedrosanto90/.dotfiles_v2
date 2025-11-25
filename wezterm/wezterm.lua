-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices

-- For example, changing the color scheme:
-- config.color_scheme = 'AdventureTime'
config.automatically_reload_config = true
config.font = wezterm.font("JetBrainsMono Nerd Font Mono")
config.font_size = 16.0
-- You can specify some parameters to influence the font selection;
-- for example, this selects a Bold, Italic font variant.
-- config.font = wezterm.font 'Fira Code'
config.colors = {
	background = "#1a1b26",
	cursor_bg = "#ffffff",
	cursor_border = "#ffffff",
}
config.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }
config.window_background_opacity = 1
config.default_cursor_style = "BlinkingBlock"
config.cursor_blink_rate = 700
config.hide_tab_bar_if_only_one_tab = true
-- and finally, return the configuration to wezterm
config.hide_mouse_cursor_when_typing = false
return config
