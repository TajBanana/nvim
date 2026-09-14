-- Platform detection for macOS, Windows/WSL, and native Debian/Fedora Linux.
--
-- There is deliberately no distro handling. Neovim reports `linux` for Ubuntu,
-- Debian, Fedora, Arch and everything else alike -- there is no per-distro feature flag
-- to group in the first place. If something ever genuinely differs per distro
-- it belongs in machine setup (see docs/deviations-from-main.md), not in here.
--
-- The one subtlety: **WSL is Linux**. `has("wsl")` and `has("linux")` are both
-- 1 there. That is usually what you want -- a Linux code path should run on WSL
-- too -- so the booleans below overlap on purpose, and `M.name` is provided for
-- the cases that need exactly one answer.
--
--   M.mac / M.linux / M.wsl / M.windows   overlapping booleans
--   M.name                                 exactly one of mac|wsl|linux|windows
--
-- Prefer the booleans:
--   if platform.wsl then ... end            -- WSL only
--   if platform.linux then ... end          -- Linux *including* WSL
--   if platform.mac then ... end
-- and reach for `M.name` only when you need a mutually exclusive switch.

local M = {}

-- `has("win32")` is 1 for 64-bit Windows too; there is no separate 32-bit case
-- worth distinguishing. Note this is native Windows nvim, NOT nvim inside WSL --
-- that reports linux+wsl, which is how this config actually runs on that box.
M.windows = vim.fn.has("win32") == 1
M.mac = vim.fn.has("mac") == 1
M.wsl = vim.fn.has("wsl") == 1

-- True on WSL as well. Guard Linux-only behaviour with this; guard behaviour
-- that must NOT run under WSL with `M.linux and not M.wsl`.
M.linux = vim.fn.has("linux") == 1

-- Mutually exclusive label. WSL is tested before Linux precisely because it is
-- also Linux -- the more specific answer has to win.
M.name = (M.mac and "mac") or (M.wsl and "wsl") or (M.linux and "linux") or (M.windows and "windows") or "unknown"

---Pick a value by platform, falling back to `default`.
---Keeps per-platform constants readable at the call site:
---  local font_size = platform.pick({ mac = 16, windows = 12 }, 14)
---
---Deliberately NOT an example: choosing a file opener. Use system_open.lua so
---the launcher, path format, and Toolbx host boundary stay coupled.
---@param map table<string, any> keyed by "mac" | "wsl" | "linux" | "windows"
---@param default any
---@return any
function M.pick(map, default)
    local v = map[M.name]
    if v ~= nil then
        return v
    end
    -- A wsl entry is more specific than linux; fall back to linux for WSL so
    -- callers only special-case WSL when it actually differs.
    if M.wsl and map.linux ~= nil then
        return map.linux
    end
    return default
end

return M
