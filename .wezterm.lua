-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

local action = wezterm.action

-- This is where you actually apply your config choices
config.font = wezterm.font_with_fallback({
    "JetBrainsMono Nerd Font",
    "Symbols Nerd Font Mono",
})
config.font_size = 16.0
config.initial_rows = 48
config.initial_cols = 160

config.audible_bell = 'Disabled'
config.default_cursor_style = 'BlinkingBlock'
config.cursor_blink_ease_in = 'Constant'
config.cursor_blink_ease_out = 'Constant'
config.cursor_blink_rate = 500
config.line_height = 1.2

config.colors = {
    cursor_bg = '#00ff00',   -- The fill color of the cursor
    cursor_border = '#00ff00', -- The color of the cursor's border
}

config.keys = {
    -- let Opt+Enter reach nvim (code actions) instead of toggling fullscreen
    { mods = "OPT", key = "Enter", action = action.DisableDefaultAssignment },
    { mods = "OPT", key = "LeftArrow",  action = action.SendKey({ mods = "ALT", key = "b" }) },
    { mods = "OPT", key = "RightArrow", action = action.SendKey({ mods = "ALT", key = "f" }) },
    { mods = "CMD", key = "LeftArrow",  action = action.SendKey({ mods = "CTRL", key = "a" }) },
    { mods = "CMD", key = "RightArrow", action = action.SendKey({ mods = "CTRL", key = "e" }) },
    { mods = "CMD", key = "Backspace",  action = action.SendKey({ mods = "CTRL", key = "u" }) },
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
    font_size = 14.0,

    -- The overall background color of the tab bar when
    -- the window is focused
    active_titlebar_bg = '#333333',

    -- The overall background color of the tab bar when
    -- the window is not focused
    inactive_titlebar_bg = '#333333',
}

config.window_padding = {
    left = 2,
    right = 2,
    top = 0,
    bottom = 0,
}

-- Title each tab by its working-directory basename (the project/repo folder)
-- instead of the generic foreground-process name ("nvim"). Works for shell and
-- nvim tabs alike, since it reads the pane's cwd rather than the running program.
local function pane_dir_basename(pane)
    local uri = pane.current_working_dir
    if not uri then
        return nil
    end
    -- newer wezterm exposes a Url object with .file_path; older gives a string
    local path = type(uri) == "userdata" and uri.file_path
        or tostring(uri):gsub("^file://[^/]*", "")
    if not path or path == "" then
        return nil
    end
    path = path:gsub("/+$", "") -- drop trailing slash
    if path == "" or path == os.getenv("HOME") then
        return "~"
    end
    return path:match("([^/]+)$") -- basename
end

wezterm.on("format-tab-title", function(tab)
    local pane = tab.active_pane
    local title = pane_dir_basename(pane)
    if not title then
        -- fall back to the process name if cwd is unknown (e.g. remote pane)
        local proc = pane.foreground_process_name or ""
        title = proc:match("([^/]+)$") or "shell"
    end
    return string.format(" %d: %s ", tab.tab_index + 1, title)
end)

-- and finally, return the configuration to wezterm
return config
