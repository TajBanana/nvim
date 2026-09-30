-- Root detection for the tailwindcss language server (lsp.lua's root_dir).
--
-- Upstream's root_dir ends its marker list with a bare `.git` fallback (for
-- Tailwind v4, which needs no config file) and its filetypes include markdown
-- and html, so opening a README in ANY git repo spawned a ~97MB node server
-- offering meaningless class completion. Here the root is, nearest first:
--   * a tailwind.config.{js,cjs,mjs,ts} (also Django's theme/static_src/);
--   * a postcss.config.* that mentions tailwind (v4's @tailwindcss/postcss);
--   * a package.json / deno.json(c) that mentions tailwindcss (v4, no config);
--   * a mix.lock (Phoenix) or Gemfile.lock (Rails) that mentions tailwind.
-- With none of those M.find returns nil and the server does not start.
--
-- One upward walk, every marker checked at every level, nearest directory
-- wins. lspconfig's helpers each stop at the FIRST file of a kind they find, so
-- combining them silently lost projects: a tailwind-free postcss config hid the
-- Rails Gemfile.lock beside it, a sub-package's package.json hid the monorepo
-- root that actually depends on tailwind, and Django's
-- theme/static_src/postcss.config.js was searched for by its bare name.
--
-- The walk stops at the repository root (the directory holding `.git`) --
-- upstream's bare `.git` marker used to be that stop, so dropping it made the
-- search unbounded: a ~/package.json mentioning tailwindcss would root the
-- server at $HOME for every buffer in every repo. Outside git, a file under
-- $HOME is never walked up to $HOME or above; a file outside both $HOME and git
-- is walked up to `/`, as upstream does.
-- Regression checks: scripts/tests/tailwind_root.lua.
local M = {}

local function mentions(path, needle)
    local fd = io.open(path, "r")
    if not fd then
        return false
    end
    local text = fd:read("*a") or ""
    fd:close()
    return text:find(needle, 1, true) ~= nil
end

local config_exts = { "js", "cjs", "mjs", "ts" }

---@param fname string absolute path of the buffer's file
---@return string|nil root
function M.find(fname)
    -- Both sides resolved: with a symlinked home the plain string compare never
    -- matched, and the walk went past $HOME.
    local home = vim.uv.os_homedir()
    home = home and (vim.uv.fs_realpath(home) or home)
    -- A new file in a directory that does not exist yet: start at its nearest
    -- existing ancestor (the missing ones hold no markers), resolved like home.
    -- Resolving only an existing start left such a path unresolved, so under a
    -- symlinked home it never equalled `home` and the walk went past it.
    local dir = vim.fs.dirname(fname)
    while not vim.uv.fs_stat(dir) and vim.fs.dirname(dir) ~= dir do
        dir = vim.fs.dirname(dir)
    end
    dir = vim.uv.fs_realpath(dir) or dir
    while dir do
        local is_repo_root = vim.uv.fs_stat(dir .. "/.git") ~= nil
        if dir == home and not is_repo_root then
            return nil
        end
        for _, base in ipairs({ dir, dir .. "/theme/static_src" }) do
            for _, ext in ipairs(config_exts) do
                if vim.uv.fs_stat(base .. "/tailwind.config." .. ext)
                    or mentions(base .. "/postcss.config." .. ext, "tailwind") then
                    return base
                end
            end
        end
        for _, f in ipairs({ "package.json", "deno.json", "deno.jsonc" }) do
            if mentions(dir .. "/" .. f, "tailwindcss") then
                return dir
            end
        end
        for _, f in ipairs({ "mix.lock", "Gemfile.lock" }) do
            if mentions(dir .. "/" .. f, "tailwind") then
                return dir
            end
        end
        if is_repo_root then
            return nil
        end
        local parent = vim.fs.dirname(dir)
        dir = parent ~= dir and parent or nil
    end
end

return M
