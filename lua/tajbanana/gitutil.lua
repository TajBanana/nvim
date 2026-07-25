-- Shared git helpers. Repo-root resolution used to be reimplemented in
-- gitlab.lua, repo_diagnostics.lua and plugins/git.lua with subtly different
-- fallbacks; this is the single source of truth. Callers decide how to handle
-- a nil result (notify-and-abort, fall back to the file's dir, or stay silent),
-- so the distinct call-site behaviour is preserved without duplicating the git
-- invocation itself.
local M = {}

---Absolute path of the git work-tree root containing `dir`, or nil if `dir`
---is not inside a git repository.
---@param dir string
---@return string|nil
function M.toplevel(dir)
    local out = vim.trim(vim.fn.system({ "git", "-C", dir, "rev-parse", "--show-toplevel" }))
    if vim.v.shell_error ~= 0 or out == "" then
        return nil
    end
    return out
end

return M
