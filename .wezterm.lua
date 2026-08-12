-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

local action = wezterm.action

-- One config for both machines. This file used to be macOS-only, and the
-- Windows box kept a hand-edited fork of it; the two drifted in both directions
-- until each had features the other was missing (Windows lost inline images,
-- macOS lost the WSL boot). Branch on the platform here instead so there is a
-- single source of truth. See docs/deviations-from-main.md.
local is_windows = wezterm.target_triple:find("windows") ~= nil

-- ── Fonts ────────────────────────────────────────────────────────────────────
config.font = wezterm.font_with_fallback({
    "JetBrainsMono Nerd Font",
    "Symbols Nerd Font Mono",
})
-- The Windows display runs at a different scale; 16pt there is oversized.
config.font_size = is_windows and 12.0 or 15.0
config.line_height = 1.2
config.initial_rows = 48
config.initial_cols = 160

-- ── WSL (Windows only) ───────────────────────────────────────────────────────
-- Declare a WSL *domain* rather than setting `default_prog = {'wsl.exe', ...}`.
-- default_prog spawns wsl.exe as an opaque process, so wezterm can't track the
-- pane's working directory — which is precisely what format-tab-title below
-- reads. A domain reports cwd properly, so tab titles keep working.
--
-- default_cwd matters too: without it panes open in the Windows cwd
-- (/mnt/c/Users/...), i.e. the Windows filesystem over the 9p bridge, which is
-- markedly slower for git and file operations than the distro's own ext4.
if is_windows then
    config.wsl_domains = {
        {
            name = 'WSL:Debian',
            distribution = 'Debian',
            username = 'TajBanana',
            default_cwd = '/home/TajBanana',
        },
    }
    config.default_domain = 'WSL:Debian'
end

-- ── Appearance ───────────────────────────────────────────────────────────────
config.audible_bell = 'Disabled'
config.default_cursor_style = 'BlinkingBlock'
config.cursor_blink_ease_in = 'Constant'
config.cursor_blink_ease_out = 'Constant'
config.cursor_blink_rate = 500

config.colors = {
    cursor_bg = '#00ff00',   -- The fill color of the cursor
    cursor_border = '#00ff00', -- The color of the cursor's border
}

config.window_frame = {
    -- Tab-bar font (the main font is appended for fallback glyphs). Roboto is
    -- bundled with wezterm, so this needs no system install.
    font = wezterm.font { family = 'Roboto', weight = 'Bold' },
    font_size = is_windows and 12.0 or 14.0,
    active_titlebar_bg = '#333333',   -- focused window
    inactive_titlebar_bg = '#333333', -- unfocused window
}

config.window_padding = {
    left = 2,
    right = 2,
    top = 0,
    bottom = 0,
}

-- WezTerm ships with the kitty graphics protocol OFF by default; snacks.nvim
-- renders inline images through it, so without this flag image buffers stay
-- blank while `wezterm imgcat` (iTerm2 protocol) still works. This applies to
-- BOTH platforms — it was missing from the Windows fork, which is why images
-- silently didn't render there.
config.enable_kitty_graphics = true

-- ── Keys ─────────────────────────────────────────────────────────────────────
-- Same intent on both platforms, different physical modifiers: macOS sends
-- CMD/OPT where Windows sends CTRL/ALT. The *emitted* keys are identical, since
-- they target readline/nvim on the WSL or macOS side either way.
if is_windows then
    config.keys = {
        -- let Alt+Enter reach nvim (code actions) instead of toggling fullscreen
        { mods = "ALT", key = "Enter", action = action.DisableDefaultAssignment },
        -- word-wise motion
        { mods = "ALT", key = "LeftArrow",  action = action.SendKey({ mods = "ALT", key = "b" }) },
        { mods = "ALT", key = "RightArrow", action = action.SendKey({ mods = "ALT", key = "f" }) },
        -- line start/end and kill-to-start
        { mods = "CTRL", key = "LeftArrow",  action = action.SendKey({ mods = "CTRL", key = "a" }) },
        { mods = "CTRL", key = "RightArrow", action = action.SendKey({ mods = "CTRL", key = "e" }) },
        { mods = "CTRL", key = "Backspace",  action = action.SendKey({ mods = "CTRL", key = "u" }) },
    }
else
    config.keys = {
        -- let Opt+Enter reach nvim (code actions) instead of toggling fullscreen
        { mods = "OPT", key = "Enter", action = action.DisableDefaultAssignment },
        { mods = "OPT", key = "LeftArrow",  action = action.SendKey({ mods = "ALT", key = "b" }) },
        { mods = "OPT", key = "RightArrow", action = action.SendKey({ mods = "ALT", key = "f" }) },
        { mods = "CMD", key = "LeftArrow",  action = action.SendKey({ mods = "CTRL", key = "a" }) },
        { mods = "CMD", key = "RightArrow", action = action.SendKey({ mods = "CTRL", key = "e" }) },
        { mods = "CMD", key = "Backspace",  action = action.SendKey({ mods = "CTRL", key = "u" }) },
    }
end

-- ── Tab titles ───────────────────────────────────────────────────────────────
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
    -- On Windows, HOME is the *Windows* profile dir, so it never equals the WSL
    -- home the pane actually reports — match /home/<user> directly as well.
    if path == "" or path == os.getenv("HOME") or path:match("^/home/[^/]+$") then
        return "~"
    end
    return path:match("([^/]+)$") -- basename
end

-- Shells mean the tab is about a *place* → show the directory. A running TUI
-- (k9s, claude, nvim, lazygit, ...) means the tab is about a *task* → show the
-- app with the directory as context: "[claude] nvim-config".
local shells = { zsh = true, bash = true, sh = true, fish = true }

-- Windows-side host processes for a WSL pane. These are launchers, never the
-- thing the user is running, so they must not be shown as the "app".
local wsl_hosts = { ["wslhost.exe"] = true, ["wsl.exe"] = true }

-- Which program is in the foreground, or nil for "just a shell prompt".
--
-- On Windows this CANNOT come from foreground_process_name: wezterm runs on the
-- Windows side, so a WSL pane reports `wslhost.exe` — wezterm can't see into the
-- distro's process tree. The shell inside WSL publishes the real command line as
-- the WEZTERM_PROG user var (see the WezTerm block in .zshrc), so prefer that
-- and fall back to the process name on macOS, where it is accurate.
local function pane_prog(pane)
    local prog = pane.user_vars and pane.user_vars.WEZTERM_PROG
    if prog and prog ~= "" then
        -- first word of the command line, stripped of any path
        local word = prog:match("^%s*(%S+)")
        if word then
            return word:match("([^/\\]+)$")
        end
    end
    -- Windows reports paths with backslashes for non-WSL panes; accept both.
    local proc = (pane.foreground_process_name or ""):match("([^/\\]+)$")
    if proc and wsl_hosts[proc] then
        return nil -- a WSL pane sitting at its prompt: the directory is the identity
    end
    return proc
end

wezterm.on("format-tab-title", function(tab)
    local pane = tab.active_pane
    local dir = pane_dir_basename(pane)
    local proc = pane_prog(pane)

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

-- The OS window title — what Windows shows in the taskbar and Alt-Tab, and what
-- macOS shows in the window list. Distinct from the tab bar above: wezterm
-- derives this from the active pane's title by default, which for a WSL pane is
-- uninformative. Same data as the tab title, minus the per-tab index, plus a
-- tab count so several windows are distinguishable when switching.
wezterm.on("format-window-title", function(tab, pane, tabs)
    local dir = pane_dir_basename(pane)
    local proc = pane_prog(pane)
    local title
    -- Same `shells` filter format-tab-title applies: a plain zsh/bash pane is
    -- not a running "app", so the directory is the identity. Without this the
    -- window title read "[zsh] nvim" while the tab for that pane read "nvim".
    if proc and not shells[proc] then
        title = "[" .. proc .. "]" .. (dir and (" " .. dir) or "")
    else
        title = dir or "WezTerm"
    end
    if tabs and #tabs > 1 then
        title = title .. string.format("  (%d tabs)", #tabs)
    end
    return title
end)

-- and finally, return the configuration to wezterm
return config
