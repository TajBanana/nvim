-- Shared git helpers. Repo-root resolution used to be reimplemented in
-- forge.lua, repo_diagnostics.lua and plugins/git.lua with subtly different
-- fallbacks; this is the single source of truth. Callers decide how to handle
-- a nil result (notify-and-abort, fall back to the file's dir, or stay silent),
-- so the distinct call-site behaviour is preserved without duplicating the git
-- invocation itself.
local M = {}

---Absolute path of the git work-tree root containing `dir`, or nil if `dir`
---is not inside a git repository -- or if git is unavailable.
---
---This function is TOTAL: it returns, it never raises. That matters because
---every caller treats nil as "not a repo" and has a graceful path for it, while
---an exception propagates out of whatever autocmd or keymap invoked it.
---`vim.fn.system` does NOT merely fail when the binary is missing -- it raises
---`E475: Invalid value for argument cmd: ... is not executable`, so the
---shell_error guard below is never reached. With git off nvim's PATH (a GUI nvim
---with a trimmed environment, a minimal container, native Windows where git may
---live only inside WSL) that turned telescope's <C-p> guard -- written precisely
---so the key would not fail with a raw error -- back into a raw error, and made
---git.lua's merge_base throw on every GitSignsUpdate for every buffer.
---@param dir string
---@return string|nil
function M.toplevel(dir)
    if vim.fn.executable("git") ~= 1 then
        return nil
    end
    -- Belt and braces: executable() can still race a PATH change, and pcall keeps
    -- the documented contract even if the call raises for some other reason.
    local ok, res = pcall(vim.fn.system, { "git", "-C", dir, "rev-parse", "--show-toplevel" })
    if not ok then
        return nil
    end
    local out = vim.trim(res)
    if vim.v.shell_error ~= 0 or out == "" then
        return nil
    end
    return out
end

return M
