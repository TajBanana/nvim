-- GitLab-only shortcuts.
--
-- IMPORTANT: these keymaps are GitLab-specific. They build GitLab web URLs
-- (`/-/merge_requests`, `/-/blob/<ref>/<path>#L<n>`) and will produce wrong
-- links on other forges — GitHub, Bitbucket, etc. use different URL shapes.
-- They are isolated in this module (rather than in set.lua) so the GitLab
-- assumption stays in one place and is easy to disable or swap per forge.
--
-- <leader>gm prefers glab (the official GitLab CLI) when it is installed, for a
-- robust API-based MR lookup by source branch; it otherwise falls back to a
-- token-free `git ls-remote` method that needs no glab and no API token.
-- <leader>gl is always token-free.
--
-- Keymaps registered by M.setup():
--   <leader>gm  (n)  open (or create) the current branch's merge request
--   <leader>gl  (n)  open the current file + cursor line on GitLab
--   <leader>gl  (x)  open the visually-selected line range on GitLab
--
-- Assumptions: the buffer's file is inside a git repo whose chosen remote
-- points at a GitLab instance, and (for <leader>gl) the current branch has
-- been pushed — an unpushed branch's blob URL will 404.

local M = {}

-- Run a git command in `dir` with `args` as a list; returns trimmed stdout
-- (check vim.v.shell_error at the call site). List form needs no shell quoting
-- and matches the vim.system({...}) style used elsewhere in the config.
local function git_in_dir(dir, args)
    local cmd = { "git", "-C", dir }
    vim.list_extend(cmd, args)
    return vim.trim(vim.fn.system(cmd))
end

-- Normalize any remote URL form (scp-like, ssh://, https://) to its https web
-- base, dropping the .git suffix, embedded credentials, and any ssh port.
local function to_web_url(url)
    url = url:gsub("%.git$", "")
    local host, path = url:match("^[%w._-]+@([^:/]+):(.+)$") -- scp-like: git@host:group/repo
    if host then
        return "https://" .. host .. "/" .. path
    end
    local rest = url:match("^%a[%w+.-]*://(.+)$") -- scheme://[user[:pass]@]host[:port]/path
    if rest then
        rest = rest:gsub("^[^@/]+@", "") -- strip userinfo
        local h, p = rest:match("^([^/]+)(/.*)$")
        if h then
            return "https://" .. h:gsub(":%d+$", "") .. p -- drop port
        end
    end
    return url
end

-- Percent-encode the URL-significant characters a branch name or file path may
-- carry (#, ?, %, &, =, +, whitespace) while keeping "/" raw — GitLab accepts
-- slashed branch names and paths verbatim in blob and MR URLs.
local function encode_component(s)
    return (s:gsub("[%%#?&=+%s]", function(c)
        return string.format("%%%02X", c:byte())
    end))
end

-- Resolve { dir, branch, remote_name, base } for the current buffer, or return
-- nil after notifying why (not a branch / no remote).
local function repo_context()
    local dir = vim.fn.expand("%:p:h")
    if dir == "" then
        dir = vim.fn.getcwd()
    end
    local branch = git_in_dir(dir, { "branch", "--show-current" })
    if vim.v.shell_error ~= 0 or branch == "" then
        vim.notify("Not on a git branch", vim.log.levels.WARN)
        return nil
    end
    -- Prefer the branch's configured upstream remote; fall back to origin.
    local remote_name = git_in_dir(dir, { "config", "--get", "branch." .. branch .. ".remote" })
    if vim.v.shell_error ~= 0 or remote_name == "" then
        remote_name = "origin"
    end
    local remote = git_in_dir(dir, { "remote", "get-url", remote_name })
    if vim.v.shell_error ~= 0 or remote == "" then
        vim.notify("No git remote '" .. remote_name .. "'", vim.log.levels.WARN)
        return nil
    end
    return { dir = dir, branch = branch, remote_name = remote_name, base = to_web_url(remote) }
end

-- Open the current branch's merge request (existing one if found, else the
-- create page). Prefers glab when installed (API lookup by source branch, robust
-- to the local SHA drifting from the pushed MR head); otherwise uses the
-- token-free ls-remote fallback below.
function M.open_mr()
    local ctx = repo_context()
    if not ctx then
        return
    end
    local create_url = ctx.base .. "/-/merge_requests/new?merge_request%5Bsource_branch%5D=" .. encode_component(ctx.branch)

    if vim.fn.executable("glab") == 1 then
        vim.notify("Looking up merge request…", vim.log.levels.INFO)
        -- Ask glab for the MR's web_url. A non-zero exit is ambiguous ("no MR
        -- yet" vs an auth/network error), so on failure we defer to the
        -- token-free ls-remote check rather than assuming "no MR" — see below.
        vim.system(
            { "glab", "mr", "view", "--output", "json", "--jq", ".web_url" },
            { cwd = ctx.dir, text = true },
            vim.schedule_wrap(function(out)
                local url = vim.trim(out.stdout or "")
                if out.code == 0 and url ~= "" then
                    vim.ui.open(url)
                else
                    -- Don't treat a glab failure as "no MR" — that would silently
                    -- open the create page for a branch that already has one. The
                    -- ls-remote fallback distinguishes a real failure (reported)
                    -- from a genuine no-MR (create page).
                    M._open_mr_via_lsremote(ctx, create_url)
                end
            end)
        )
    else
        M._open_mr_via_lsremote(ctx, create_url)
    end
end

-- Token-free fallback for when glab is not installed. GitLab publishes MR heads
-- as refs/merge-requests/<iid>/head, so match the branch SHA against them via
-- ls-remote — no glab or API token needed.
function M._open_mr_via_lsremote(ctx, create_url)
    vim.system(
        { "git", "ls-remote", ctx.remote_name, "refs/heads/" .. ctx.branch, "refs/merge-requests/*/head" },
        { cwd = ctx.dir, text = true },
        vim.schedule_wrap(function(out)
            if out.code ~= 0 then
                vim.notify("git ls-remote failed: " .. vim.trim(out.stderr or ""), vim.log.levels.ERROR)
                return
            end
            local branch_sha, best
            local mrs = {}
            for line in (out.stdout or ""):gmatch("[^\n]+") do
                local sha, ref = line:match("^(%x+)%s+(%S+)$")
                if ref == "refs/heads/" .. ctx.branch then
                    branch_sha = sha
                elseif ref then
                    local iid = ref:match("^refs/merge%-requests/(%d+)/head$")
                    if iid then
                        mrs[#mrs + 1] = { iid = tonumber(iid), sha = sha }
                    end
                end
            end
            for _, m in ipairs(mrs) do
                if m.sha == branch_sha and (not best or m.iid > best) then
                    best = m.iid
                end
            end
            if best then
                vim.ui.open(ctx.base .. "/-/merge_requests/" .. best)
            else
                vim.ui.open(create_url) -- no MR yet
            end
        end)
    )
end

-- Open the current file on GitLab, anchored to a line (normal) or a line range
-- (visual). `range` is nil for the cursor line, or { start_line, end_line }.
function M.open_line(range)
    local ctx = repo_context()
    if not ctx then
        return
    end
    local file = vim.fn.expand("%:p")
    if file == "" then
        vim.notify("No file to open", vim.log.levels.WARN)
        return
    end
    local root = require("tajbanana.gitutil").toplevel(ctx.dir)
    if not root then
        vim.notify("Not in a git repository", vim.log.levels.WARN)
        return
    end
    local relpath = file:sub(#root + 2) -- path relative to repo root (strip "root/")
    local frag
    if range and range[2] and range[1] ~= range[2] then
        frag = string.format("#L%d-%d", range[1], range[2])
    else
        frag = string.format("#L%d", (range and range[1]) or vim.fn.line("."))
    end
    vim.ui.open(ctx.base .. "/-/blob/" .. encode_component(ctx.branch) .. "/" .. encode_component(relpath) .. frag)
end

function M.setup()
    vim.keymap.set("n", "<leader>gm", M.open_mr, { desc = "GitLab: open/create MR" })
    vim.keymap.set("n", "<leader>gl", function()
        M.open_line()
    end, { desc = "GitLab: open file line in browser" })
    vim.keymap.set("x", "<leader>gl", function()
        -- The callback runs while STILL in visual mode, so '< / '> hold the
        -- PREVIOUS selection (or line 0 on first use). Read the live selection
        -- from the visual anchor (getpos("v")) and the cursor (getpos(".")).
        local s = vim.fn.getpos("v")[2]
        local e = vim.fn.getpos(".")[2]
        if s > e then
            s, e = e, s
        end
        M.open_line({ s, e })
    end, { desc = "GitLab: open selected lines in browser" })
end

return M
