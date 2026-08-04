-- GitHub-only shortcuts.
--
-- IMPORTANT: these keymaps are GitHub-specific. They build GitHub web URLs
-- (`/compare/<branch>`, `/pull/<n>`, `/blob/<ref>/<path>#L<n>`) and will produce
-- wrong links on other forges — GitLab, Bitbucket, etc. use different URL
-- shapes. They are isolated in this module (rather than in set.lua) so the
-- GitHub assumption stays in one place and is easy to disable or swap per forge.
--
-- <leader>gm prefers gh (the official GitHub CLI) when it is installed, for a
-- robust API-based PR lookup by head branch; it otherwise falls back to a
-- token-free `git ls-remote` method that needs no gh and no API token.
-- <leader>gl is always token-free.
--
-- Keymaps registered by M.setup():
--   <leader>gm  (n)  open (or create) the current branch's pull request
--   <leader>gl  (n)  open the current file + cursor line on GitHub
--   <leader>gl  (x)  open the visually-selected line range on GitHub
--
-- Assumptions: the buffer's file is inside a git repo whose chosen remote
-- points at a GitHub instance, and (for <leader>gl) the current branch has
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
    local host, path = url:match("^[%w._-]+@([^:/]+):(.+)$") -- scp-like: git@host:owner/repo
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
-- carry (#, ?, %, &, =, +, whitespace) while keeping "/" raw — GitHub accepts
-- slashed branch names and paths verbatim in blob and compare URLs.
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

-- Open the current branch's pull request (existing one if found, else the
-- compare/create page). Prefers gh when installed (API lookup by head branch,
-- robust to the local SHA drifting from the pushed PR head); otherwise uses the
-- token-free ls-remote fallback below.
function M.open_pr()
    local ctx = repo_context()
    if not ctx then
        return
    end
    -- GitHub's create-PR page is /compare/<branch>; expand=1 opens the form
    -- directly rather than the bare comparison view.
    local create_url = ctx.base .. "/compare/" .. encode_component(ctx.branch) .. "?expand=1"

    if vim.fn.executable("gh") == 1 then
        vim.notify("Looking up pull request…", vim.log.levels.INFO)
        -- Ask gh for the PR's url. A non-zero exit is ambiguous ("no PR yet"
        -- vs an auth/network error), so on failure we defer to the token-free
        -- ls-remote check rather than assuming "no PR" — see below.
        vim.system(
            { "gh", "pr", "view", "--json", "url", "--jq", ".url" },
            { cwd = ctx.dir, text = true },
            vim.schedule_wrap(function(out)
                local url = vim.trim(out.stdout or "")
                if out.code == 0 and url ~= "" then
                    vim.ui.open(url)
                else
                    -- Don't treat a gh failure as "no PR" — that would silently
                    -- open the create page for a branch that already has one. The
                    -- ls-remote fallback distinguishes a real failure (reported)
                    -- from a genuine no-PR (create page).
                    M._open_pr_via_lsremote(ctx, create_url)
                end
            end)
        )
    else
        M._open_pr_via_lsremote(ctx, create_url)
    end
end

-- Token-free fallback for when gh is not installed. GitHub publishes PR heads
-- as refs/pull/<n>/head, so match the branch SHA against them via ls-remote —
-- no gh or API token needed.
function M._open_pr_via_lsremote(ctx, create_url)
    vim.system(
        { "git", "ls-remote", ctx.remote_name, "refs/heads/" .. ctx.branch, "refs/pull/*/head" },
        { cwd = ctx.dir, text = true },
        vim.schedule_wrap(function(out)
            if out.code ~= 0 then
                vim.notify("git ls-remote failed: " .. vim.trim(out.stderr or ""), vim.log.levels.ERROR)
                return
            end
            local branch_sha, best
            local prs = {}
            for line in (out.stdout or ""):gmatch("[^\n]+") do
                local sha, ref = line:match("^(%x+)%s+(%S+)$")
                if ref == "refs/heads/" .. ctx.branch then
                    branch_sha = sha
                elseif ref then
                    local num = ref:match("^refs/pull/(%d+)/head$")
                    if num then
                        prs[#prs + 1] = { num = tonumber(num), sha = sha }
                    end
                end
            end
            for _, p in ipairs(prs) do
                if p.sha == branch_sha and (not best or p.num > best) then
                    best = p.num
                end
            end
            if best then
                vim.ui.open(ctx.base .. "/pull/" .. best)
            else
                vim.ui.open(create_url) -- no PR yet
            end
        end)
    )
end

-- Open the current file on GitHub, anchored to a line (normal) or a line range
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
    -- `rev-parse --show-toplevel` resolves symlinks but expand("%:p") does not,
    -- so in a symlinked directory the two share no prefix and blind substring
    -- arithmetic silently produced a truncated, wrong blob URL. Resolve both and
    -- assert containment before slicing.
    file = vim.fn.resolve(file)
    root = vim.fn.resolve(root)
    if file ~= root and not vim.startswith(file, root .. "/") then
        vim.notify("File is outside the git repository", vim.log.levels.WARN)
        return
    end
    local relpath = file:sub(#root + 2) -- path relative to repo root (strip "root/")
    local frag
    -- GitHub repeats the "L" in a range anchor (#L10-L20), unlike GitLab (#L10-20).
    if range and range[2] and range[1] ~= range[2] then
        frag = string.format("#L%d-L%d", range[1], range[2])
    else
        frag = string.format("#L%d", (range and range[1]) or vim.fn.line("."))
    end
    vim.ui.open(ctx.base .. "/blob/" .. encode_component(ctx.branch) .. "/" .. encode_component(relpath) .. frag)
end

function M.setup()
    vim.keymap.set("n", "<leader>gm", M.open_pr, { desc = "GitHub: open/create PR" })
    vim.keymap.set("n", "<leader>gl", function()
        M.open_line()
    end, { desc = "GitHub: open file line in browser" })
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
    end, { desc = "GitHub: open selected lines in browser" })
end

return M
