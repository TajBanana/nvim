-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

local action = wezterm.action

-- This is where you actually apply your config choices
config.font_size = 17.0
config.initial_rows = 48
config.initial_cols = 160

config.audible_bell = 'Disabled'
config.default_cursor_style = 'BlinkingBlock'
config.cursor_blink_ease_in = 'Constant'
config.cursor_blink_ease_out = 'Constant'
config.cursor_blink_rate = 500

config.colors = {
  cursor_bg = '#00ff00',    -- The fill color of the cursor
  cursor_border = '#00ff00', -- The color of the cursor's border
}

-- config.keys = {
--   {
--     key = 'LeftArrow',
--     mods = 'CTRL|ALT',
--     action = action.ActivatePaneDirection 'Left',
--   },
--   {
--     key = 'RightArrow',
--     mods = 'CTRL|ALT',
--     action = action.ActivatePaneDirection 'Right',
--   },
--   {
--     key = 'UpArrow',
--     mods = 'CTRL|ALT',
--     action = action.ActivatePaneDirection 'Up',
--   },
--   {
--     key = 'DownArrow',
--     mods = 'CTRL|ALT',
--     action = action.ActivatePaneDirection 'Down',
--   },
-- }
--
config.keys = {
	{ mods = "OPT", key = "LeftArrow", action = action.SendKey({ mods = "ALT", key = "b" }) },
	{ mods = "OPT", key = "RightArrow", action = action.SendKey({ mods = "ALT", key = "f" }) },
	{ mods = "CMD", key = "LeftArrow", action = action.SendKey({ mods = "CTRL", key = "a" }) },
	{ mods = "CMD", key = "RightArrow", action = action.SendKey({ mods = "CTRL", key = "e" }) },
	{ mods = "CMD", key = "Backspace", action = action.SendKey({ mods = "CTRL", key = "u" }) },
}

-- For example, changing the color scheme:
-- config.color_scheme = 'AdventureTime'
config.window_frame = {
  -- The font used in the tab bar.
  -- Roboto Bold is the default; this font is bundled
  -- with wezterm.
  -- Whatever font is selected here, it will have the
  -- main font setting appended to it to pick up any
  -- fallback fonts you may have used there.
  font = wezterm.font { family = 'Roboto', weight = 'Bold' },

  -- The size of the font in the tab bar.
  -- Default to 10.0 on Windows but 12.0 on other systems
  font_size = 15.0,

  -- The overall background color of the tab bar when
  -- the window is focused
  active_titlebar_bg = '#333333',

  -- The overall background color of the tab bar when
  -- the window is not focused
  inactive_titlebar_bg = '#333333',
}

config.colors = {
  tab_bar = {
    -- The color of the inactive tab bar edge/divider
    inactive_tab_edge = '#575757',
  },
}

config.window_padding = {
    left = 2,
    right = 2,
    top = 0,
    bottom = 0,
}

-- and finally, return the configuration to wezterm
return config
