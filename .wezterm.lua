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

config.window_frame = {
    -- Tab-bar font (the main font is appended for fallback glyphs).
    font = wezterm.font { family = 'Roboto', weight = 'Bold' },
    font_size = 14.0,
    active_titlebar_bg = '#333333',   -- focused window
    inactive_titlebar_bg = '#333333', -- unfocused window
}

-- WezTerm ships with the kitty graphics protocol OFF by default; snacks.nvim
-- renders inline images through it, so without this flag image buffers stay
-- blank while `wezterm imgcat` (iTerm2 protocol) still works.
config.enable_kitty_graphics = true

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

-- Shells mean the tab is about a *place* → show the directory. A running TUI
-- (k9s, claude, nvim, lazygit, ...) means the tab is about a *task* → show the
-- app with the directory as context: "[claude] nvim-config".
local shells = { zsh = true, bash = true, sh = true, fish = true }

wezterm.on("format-tab-title", function(tab)
    local pane = tab.active_pane
    local dir = pane_dir_basename(pane)
    local proc = (pane.foreground_process_name or ""):match("([^/]+)$")

    local prefix = string.format(" %d: ", tab.tab_index + 1)
    if proc and not shells[proc] then
        -- bold [app], regular directory
        return {
            { Text = prefix },
            { Attribute = { Intensity = "Bold" } },
            { Text = "[" .. proc .. "]" },
            { Attribute = { Intensity = "Normal" } },
            { Text = dir and (" " .. dir .. " ") or " " },
        }
    end
    -- shell (or unknown process): the directory is the identity
    return prefix .. (dir or proc or "shell") .. " "
end)

-- and finally, return the configuration to wezterm
return config
