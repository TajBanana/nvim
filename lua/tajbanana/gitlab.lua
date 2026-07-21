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

-- Session cache of resolved MR URLs, keyed by "<remote>\0<branch>". Resolving a
-- branch's MR costs a ~2s round-trip to the GitLab server (glab API or
-- ls-remote); the answer is stable once the MR exists, so we cache positive hits
-- only (never the "no MR yet" case, so a freshly-created MR is picked up) and
-- reuse them to open instantly. Cleared on nvim restart.
local mr_url_cache = {}

-- Run a git command in `dir`, returning trimmed stdout (check vim.v.shell_error).
local function git_in_dir(dir, args)
    return vim.trim(vim.fn.system("git -C " .. vim.fn.shellescape(dir) .. " " .. args))
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

-- Resolve { dir, branch, remote_name, base } for the current buffer, or return
-- nil after notifying why (not a branch / no remote).
local function repo_context()
    local dir = vim.fn.expand("%:p:h")
    if dir == "" then
        dir = vim.fn.getcwd()
    end
    local branch = git_in_dir(dir, "branch --show-current")
    if vim.v.shell_error ~= 0 or branch == "" then
        vim.notify("Not on a git branch", vim.log.levels.WARN)
        return nil
    end
    -- Prefer the branch's configured upstream remote; fall back to origin.
    local remote_name = git_in_dir(dir, "config --get branch." .. vim.fn.shellescape(branch) .. ".remote")
    if vim.v.shell_error ~= 0 or remote_name == "" then
        remote_name = "origin"
    end
    local remote = git_in_dir(dir, "remote get-url " .. vim.fn.shellescape(remote_name))
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
    -- Reuse a URL resolved earlier this session — instant, no network round-trip.
    local key = ctx.remote_name .. "\0" .. ctx.branch
    if mr_url_cache[key] then
        vim.ui.open(mr_url_cache[key])
        return
    end
    local create_url = ctx.base .. "/-/merge_requests/new?merge_request%5Bsource_branch%5D=" .. ctx.branch

    if vim.fn.executable("glab") == 1 then
        vim.notify("Looking up merge request…", vim.log.levels.INFO)
        -- Ask glab for the MR's web_url; it exits non-zero (empty) when the
        -- branch has no open MR, in which case we open the create page.
        vim.system(
            { "glab", "mr", "view", "--output", "json", "--jq", ".web_url" },
            { cwd = ctx.dir, text = true },
            vim.schedule_wrap(function(out)
                local url = vim.trim(out.stdout or "")
                if out.code == 0 and url ~= "" then
                    mr_url_cache[key] = url
                    vim.ui.open(url)
                else
                    vim.ui.open(create_url) -- no MR yet; don't cache the miss
                end
            end)
        )
    else
        M._open_mr_via_lsremote(ctx, key, create_url)
    end
end

-- Token-free fallback for when glab is not installed. GitLab publishes MR heads
-- as refs/merge-requests/<iid>/head, so match the branch SHA against them via
-- ls-remote — no glab or API token needed.
function M._open_mr_via_lsremote(ctx, key, create_url)
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
                local url = ctx.base .. "/-/merge_requests/" .. best
                mr_url_cache[key] = url -- cache the positive hit for instant reuse
                vim.ui.open(url)
            else
                vim.ui.open(create_url) -- no MR yet; don't cache the miss
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
    local root = git_in_dir(ctx.dir, "rev-parse --show-toplevel")
    if vim.v.shell_error ~= 0 or root == "" then
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
    vim.ui.open(ctx.base .. "/-/blob/" .. ctx.branch .. "/" .. relpath .. frag)
end

function M.setup()
    vim.keymap.set("n", "<leader>gm", M.open_mr, { desc = "GitLab: open/create MR" })
    vim.keymap.set("n", "<leader>gl", function()
        M.open_line()
    end, { desc = "GitLab: open file line in browser" })
    vim.keymap.set("x", "<leader>gl", function()
        -- '< and '> are set when the visual-mode mapping fires and leaves visual mode
        local s = vim.fn.getpos("'<")[2]
        local e = vim.fn.getpos("'>")[2]
        if s > e then
            s, e = e, s
        end
        M.open_line({ s, e })
    end, { desc = "GitLab: open selected lines in browser" })
end

return M
