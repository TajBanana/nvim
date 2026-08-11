-- Forge shortcuts: open the current branch's change request, or the current
-- file/line in the browser.
--
-- This module used to exist twice -- `gitlab.lua` on the work machine and
-- `github.lua` on the personal one -- which is what forced a per-machine branch
-- of the whole repo. The forge is a property of the *remote*, not of the
-- machine: the same laptop can have GitHub and GitLab checkouts side by side, so
-- branching per machine was always the wrong axis. It is now detected per buffer
-- from the remote host, and the URL shapes live in one table.
--
-- Keymaps registered by M.setup():
--   <leader>gm  (n)  open (or create) the current branch's PR / MR
--   <leader>gl  (n)  open the current file + cursor line in the browser
--   <leader>gl  (x)  open the visually-selected line range
--
-- Assumptions: the buffer's file is inside a git repo whose chosen remote points
-- at a supported forge, and (for <leader>gl) the current branch has been pushed
-- -- an unpushed branch's blob URL will 404.

local M = {}

-- Run a git command in `dir` with `args` as a list; returns trimmed stdout
-- (check vim.v.shell_error at the call site). List form needs no shell quoting.
local function git_in_dir(dir, args)
    local cmd = { "git", "-C", dir }
    vim.list_extend(cmd, args)
    return vim.trim(vim.fn.system(cmd))
end

-- Normalize any remote URL form (scp-like, ssh://, https://) to its https web
-- base, dropping the .git suffix, embedded credentials, and any ssh port.
local function to_web_url(url)
    url = url:gsub("%.git$", "")
    local host, path = url:match("^[%w._-]+@([^:/]+):(.+)$") -- scp-like: git@host:owner/repo
    if host then
        return "https://" .. host .. "/" .. path, host
    end
    local rest = url:match("^%a[%w+.-]*://(.+)$") -- scheme://[user[:pass]@]host[:port]/path
    if rest then
        rest = rest:gsub("^[^@/]+@", "") -- strip userinfo
        local h, p = rest:match("^([^/]+)(/.*)$")
        if h then
            h = h:gsub(":%d+$", "") -- drop port
            return "https://" .. h .. p, h
        end
    end
    return url, nil
end

-- Percent-encode the URL-significant characters a branch name or file path may
-- carry (#, ?, %, &, =, +, whitespace) while keeping "/" raw -- both forges
-- accept slashed branch names and paths verbatim in blob and compare URLs.
local function encode_component(s)
    return (s:gsub("[%%#?&=+%s]", function(c)
        return string.format("%%%02X", c:byte())
    end))
end

-- The complete set of differences between the two forges. Everything else in
-- this module is shared. Adding Bitbucket etc. means adding one entry here, not
-- another module.
--
-- The line-range anchor is the trap: GitHub repeats the "L" (#L10-L20) where
-- GitLab does not (#L10-20). Get it wrong and the URL still loads, it just
-- highlights the wrong thing -- it fails soft, so casual testing misses it.
local FORGES = {
    github = {
        label = "GitHub",
        request_name = "pull request",
        request_path = "/pull/",
        create_url = function(base, branch)
            -- expand=1 opens the PR form directly rather than a bare comparison
            return base .. "/compare/" .. encode_component(branch) .. "?expand=1"
        end,
        blob_path = "/blob/",
        range_anchor = function(s, e)
            return string.format("#L%d-L%d", s, e)
        end,
        -- Change-request heads are published as fetchable refs by both forges,
        -- which is what makes the token-free lookup below possible at all.
        head_glob = "refs/pull/*/head",
        head_pattern = "^refs/pull/(%d+)/head$",
        cli = { "gh", "pr", "view", "--json", "url", "--jq", ".url" },
        cli_bin = "gh",
    },
    gitlab = {
        label = "GitLab",
        request_name = "merge request",
        request_path = "/-/merge_requests/",
        create_url = function(base, branch)
            return base
                .. "/-/merge_requests/new?merge_request%5Bsource_branch%5D="
                .. encode_component(branch)
        end,
        blob_path = "/-/blob/",
        range_anchor = function(s, e)
            return string.format("#L%d-%d", s, e)
        end,
        head_glob = "refs/merge-requests/*/head",
        head_pattern = "^refs/merge%-requests/(%d+)/head$",
        cli = { "glab", "mr", "view", "--output", "json" },
        cli_bin = "glab",
        cli_jq = ".web_url",
    },
}

-- Identify the forge from the remote host. Matched as a substring so
-- self-hosted instances (gitlab.example.com, github.acme.internal) resolve too.
local function forge_for(host)
    if not host then
        return nil
    end
    host = host:lower()
    if host:find("gitlab", 1, true) then
        return FORGES.gitlab
    end
    if host:find("github", 1, true) then
        return FORGES.github
    end
    return nil
end

-- Resolve { dir, branch, remote_name, base, forge } for the current buffer, or
-- return nil after notifying why (not a branch / no remote / unknown forge).
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
    local base, host = to_web_url(remote)
    local forge = forge_for(host)
    if not forge then
        vim.notify("Unsupported forge for host: " .. tostring(host), vim.log.levels.WARN)
        return nil
    end
    return { dir = dir, branch = branch, remote_name = remote_name, base = base, forge = forge }
end

-- Open the current branch's change request (existing one if found, else the
-- create page). Prefers the forge CLI when installed, since it looks up by head
-- branch and is robust to the local SHA drifting from the pushed head;
-- otherwise uses the token-free ls-remote fallback below.
function M.open_request()
    local ctx = repo_context()
    if not ctx then
        return
    end
    local forge = ctx.forge
    local create_url = forge.create_url(ctx.base, ctx.branch)

    if vim.fn.executable(forge.cli_bin) == 1 then
        vim.notify("Looking up " .. forge.request_name .. "…", vim.log.levels.INFO)
        vim.system(
            forge.cli,
            { cwd = ctx.dir, text = true },
            vim.schedule_wrap(function(out)
                local url = vim.trim(out.stdout or "")
                -- glab returns a JSON object rather than a bare string.
                if forge.cli_jq and url ~= "" then
                    local ok, decoded = pcall(vim.json.decode, url)
                    url = (ok and type(decoded) == "table" and decoded.web_url) or ""
                end
                if out.code == 0 and url ~= "" then
                    vim.ui.open(url)
                else
                    -- A non-zero exit is ambiguous ("none yet" vs an auth or
                    -- network error), so defer to the token-free check rather
                    -- than assuming none exists -- that would silently open the
                    -- create page for a branch that already has one.
                    M._open_request_via_lsremote(ctx, create_url)
                end
            end)
        )
    else
        M._open_request_via_lsremote(ctx, create_url)
    end
end

-- Token-free fallback for when the forge CLI is absent. Both forges publish
-- change-request heads as fetchable refs, so match the branch SHA against them
-- via ls-remote -- no CLI and no API token needed.
function M._open_request_via_lsremote(ctx, create_url)
    local forge = ctx.forge
    vim.system(
        { "git", "ls-remote", ctx.remote_name, "refs/heads/" .. ctx.branch, forge.head_glob },
        { cwd = ctx.dir, text = true },
        vim.schedule_wrap(function(out)
            if out.code ~= 0 then
                vim.notify("git ls-remote failed: " .. vim.trim(out.stderr or ""), vim.log.levels.ERROR)
                return
            end
            local branch_sha, best
            local requests = {}
            for line in (out.stdout or ""):gmatch("[^\n]+") do
                local sha, ref = line:match("^(%x+)%s+(%S+)$")
                if ref == "refs/heads/" .. ctx.branch then
                    branch_sha = sha
                elseif ref then
                    local num = ref:match(forge.head_pattern)
                    if num then
                        requests[#requests + 1] = { num = tonumber(num), sha = sha }
                    end
                end
            end
            for _, p in ipairs(requests) do
                if p.sha == branch_sha and (not best or p.num > best) then
                    best = p.num
                end
            end
            if best then
                vim.ui.open(ctx.base .. forge.request_path .. best)
            else
                vim.ui.open(create_url) -- none yet
            end
        end)
    )
end

-- Open the current file in the browser, anchored to a line (normal) or a line
-- range (visual). `range` is nil for the cursor line, or { start_line, end_line }.
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
    -- rev-parse --show-toplevel resolves symlinks but expand("%:p") does not, so
    -- resolve before slicing or a symlinked checkout yields a truncated path.
    file = vim.fn.resolve(file)
    root = vim.fn.resolve(root)
    if not vim.startswith(file, root .. "/") then
        vim.notify("File is outside the repository root", vim.log.levels.WARN)
        return
    end
    local relpath = file:sub(#root + 2)
    local frag
    if range and range[2] and range[1] ~= range[2] then
        frag = ctx.forge.range_anchor(range[1], range[2])
    else
        frag = string.format("#L%d", (range and range[1]) or vim.fn.line("."))
    end
    vim.ui.open(
        ctx.base .. ctx.forge.blob_path .. encode_component(ctx.branch) .. "/" .. encode_component(relpath) .. frag
    )
end

function M.setup()
    vim.keymap.set("n", "<leader>gm", M.open_request, { desc = "Forge: open/create PR or MR" })
    vim.keymap.set("n", "<leader>gl", function()
        M.open_line()
    end, { desc = "Forge: open file line in browser" })
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
    end, { desc = "Forge: open selected lines in browser" })
end

return M
