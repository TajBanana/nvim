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
--   <leader>gl  (n)  permalink to the current file + cursor line: open + copy
--   <leader>gl  (x)  permalink to the visually-selected line range
--
-- <leader>gl links by commit SHA, not branch name: a branch URL points at
-- whatever the branch is LATER, so a link shared in a review drifted to other
-- code as soon as more commits landed (GitHub's `y` / GitLab's "Copy permalink"
-- exist for the same reason). It refuses when HEAD is not on the remote yet or
-- the file is not in HEAD -- either link would 404 -- and warns when the file
-- has uncommitted edits, since the line numbers then come from the working
-- tree, not the linked commit. A detached HEAD works (it links by SHA anyway).
--
-- Assumption: the buffer's file is inside a git repo whose chosen remote points
-- at a supported forge.

local M = {}

-- Run a git command in `dir` with `args` as a list; returns trimmed stdout
-- (check vim.v.shell_error at the call site). List form needs no shell quoting.
local function git_in_dir(dir, args)
    local cmd = { "git", "-C", dir }
    vim.list_extend(cmd, args)
    return vim.trim(vim.fn.system(cmd))
end

-- SSH endpoints whose web UI lives on a different host (SSH-over-443).
local SSH_WEB_HOST = { ["ssh.github.com"] = "github.com", ["altssh.gitlab.com"] = "gitlab.com" }

-- Public forge web hosts: an ssh host whose ~/.ssh/config `HostName` is one of
-- these (or an SSH_WEB_HOST) IS that forge, whatever the host looks like.
local PUBLIC_WEB_HOST = { ["github.com"] = true, ["gitlab.com"] = true }

-- An ssh host that may be an ALIAS, to be replaced by its ~/.ssh/config
-- HostName: no dot at all (`work-gitlab` -- or a short intranet name, which has
-- no HostName entry and is then kept), a last label that cannot be a domain
-- ending (`github.com-work`), or a sub-domain of github.com / gitlab.com
-- (`work.github.com`: the public forges serve git ssh on no sub-domain except
-- their SSH-over-443 hosts, which are mapped first). An IP address, or a
-- punycode TLD (`xn--p1ai`), is a real host -- "a TLD is letters only" made them
-- aliases, and round 8's refusal then broke IP remotes.
local function is_ip(host)
    return host:match("^%d+%.%d+%.%d+%.%d+$") ~= nil or host:find(":", 1, true) ~= nil
end
local function is_ssh_alias(host)
    if is_ip(host) then
        return false
    end
    local lower = host:lower()
    if vim.endswith(lower, ".github.com") or vim.endswith(lower, ".gitlab.com") then
        return true
    end
    local tld = lower:match("%.([^.]+)$")
    return not tld or not (tld:match("^%a+$") or tld:match("^xn%-%-[%w%-]+$"))
end

-- An alias that could NOT be resolved must be refused: only a DOTTED one. A
-- no-dot name with no HostName is simply the host ssh connects to (`gitserver`
-- on an intranet), so it is kept as written -- refusing it broke such remotes.
local function unresolvable(host)
    return is_ssh_alias(host) and host:find(".", 1, true) ~= nil
end

-- The ssh config file git's ssh would read: a `-F <file>` in GIT_SSH_COMMAND or
-- core.sshCommand (`ssh -G` without it answered from ~/.ssh/config, which that
-- ssh never reads). M._ssh_config (tests) overrides.
local function ssh_config_file(dir)
    if M._ssh_config then
        return M._ssh_config
    end
    local cmd = vim.env.GIT_SSH_COMMAND
    if (not cmd or cmd == "") and dir then
        cmd = git_in_dir(dir, { "config", "--get", "core.sshCommand" })
        if vim.v.shell_error ~= 0 then
            cmd = nil
        end
    end
    local file = cmd and cmd:match("%-F%s*[\"']?([^\"'%s]+)")
    return file and vim.fn.expand(file) or nil
end

-- The web host for an ssh remote host, and whether it is an alias that could
-- NOT be resolved (the caller refuses: any link would name a host that serves
-- no web UI). `ssh -G` only prints the effective configuration, it never
-- connects. Its HostName is used when the host is an alias, or when HostName
-- is a public forge host (`Host github.personal` / `HostName github.com`, a
-- dotted alias the rule above cannot see). A real host name is otherwise kept
-- as written: its HostName is often a different machine for the same forge (a
-- dedicated ssh host, an IP, a bastion), and using it broke links that worked
-- before (`gitlab.example.com` -> `gitlab-ssh.example.com` became "Unsupported
-- forge"). GitHub's/GitLab's SSH-over-443 hosts map to their web hosts BEFORE
-- any lookup: `ssh.github.com` with an IP HostName became "Unsupported forge".
local function ssh_web_host(host, dir)
    local lower = host:lower()
    if SSH_WEB_HOST[lower] then
        return SSH_WEB_HOST[lower], false
    end
    local resolved
    if vim.fn.executable("ssh") == 1 then
        local cmd = { "ssh" }
        local cfg = ssh_config_file(dir)
        if cfg then
            vim.list_extend(cmd, { "-F", cfg })
        end
        vim.list_extend(cmd, { "-G", host })
        local ok, out = pcall(vim.fn.systemlist, cmd)
        if ok and vim.v.shell_error == 0 then
            for _, line in ipairs(out) do
                resolved = line:match("^hostname%s+(%S+)") or resolved
            end
        end
    end
    resolved = resolved and resolved:lower()
    local real = lower
    if resolved and resolved ~= lower
        and (is_ssh_alias(host) or PUBLIC_WEB_HOST[resolved] or SSH_WEB_HOST[resolved]) then
        real = resolved
    end
    return SSH_WEB_HOST[real] or real, unresolvable(host) and real == lower
end

-- Normalize any remote URL form (scp-like, ssh://, https://) to its web base,
-- dropping the .git suffix and embedded credentials. SSH remotes become https
-- on the real host (aliases resolved, ssh port dropped); http(s) remotes keep
-- their scheme and port -- a self-hosted forge on :8443 serves its web UI there.
local function to_web_url(url, dir)
    -- Trailing slashes first: `…/r.git/` (valid for git) kept its .git and
    -- built `…/r.git//blob/…`, a 404.
    url = url:gsub("/+$", ""):gsub("%.git$", "")
    -- scp-like: [user@]host:owner/repo. The user part is OPTIONAL in git's syntax,
    -- so `gitlab.example.com:owner/repo.git` must parse too. Anchored on a host
    -- that contains no "/" before the ":", which is what distinguishes this form
    -- from a local path like `../repo:name`.
    -- Two explicit alternatives rather than an optional `@?`: Lua's `*` is greedy
    -- with no backtracking preference, so `[%w._-]*@?([%w._-]+)` on a userless
    -- URL let the first class eat the host and captured only its last character
    -- (`gitlab.example.com:o/r` -> host `m`). The scheme guard stops the second
    -- pattern matching `https` as a host in `https://...`.
    if not url:match("^%a[%w+.-]*://") then
        local host, path = url:match("^[%w._-]+@([%w._-]+):(.+)$")
        if not host then
            host, path = url:match("^([%w._-]+):(.+)$")
        end
        if host then
            local unresolved
            host, unresolved = ssh_web_host(host, dir)
            return "https://" .. host .. "/" .. path, host, unresolved
        end
    end
    local scheme, rest = url:match("^(%a[%w+.-]*)://(.+)$") -- scheme://[user[:pass]@]host[:port]/path
    if rest then
        rest = rest:gsub("^[^@/]+@", "") -- strip userinfo
        local h, p = rest:match("^([^/]+)(/.*)$")
        if h then
            scheme = scheme:lower()
            if scheme == "http" or scheme == "https" then
                return scheme .. "://" .. h .. p, (h:gsub(":%d+$", ""))
            end
            local unresolved
            h, unresolved = ssh_web_host((h:gsub(":%d+$", "")), dir) -- ssh://, git+ssh://, git://
            return "https://" .. h .. p, h, unresolved
        end
    end
    return url, nil
end

-- Percent-encode what a branch name or file path may carry that a URL cannot
-- hold raw: the URL-significant # ? % & = +, whitespace, the characters RFC 3986
-- never allows unencoded (" < > [ ] { } ^ | \ and the backtick -- a raw
-- backslash became "/" in the browser), and all non-ASCII bytes (macOS `open`
-- treats a URL containing raw UTF-8 as not-yet-encoded and re-encodes all of it,
-- turning %20 into %2520). "/" stays raw: both forges accept slashed branch
-- names and paths verbatim in blob and compare URLs.
local function encode_component(s)
    return (s:gsub('[%c%%#?&=+%s"<>%[%]{}^|\\`\128-\255]', function(c)
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
        cli_url_field = "web_url", -- glab prints JSON; the URL is this field
    },
}

-- Identify the forge for a remote host, in three escalating steps.
--
-- A plain substring test over the whole host was wrong in both directions: it
-- REFUSED self-hosted instances whose name does not carry the vendor
-- (`git.thalesdigital.io` is GitLab), which is the case this module was
-- generalised to serve, and it ACCEPTED hosts that merely contain the string
-- (`notgitlab.com`, or an ssh alias like `work-gitlab`), emitting a confidently
-- wrong URL -- the exact failure the header claims to prevent.
--
-- 1. An explicit per-repo override always wins:
--        git config --local nvim.forge gitlab
--    This is the answer for a self-hosted host that cannot be inferred. It lives
--    in the repo's own git config, so it travels with the checkout and needs no
--    machine-specific nvim configuration.
-- 2. Otherwise match on dot-separated LABELS, not raw substrings, so
--    `gitlab.example.com` and `github.acme.internal` resolve while
--    `notgitlab.com` does not.
-- 3. Otherwise refuse, and say how to fix it.
---@param host string|nil
---@param dir string|nil repo dir, for reading the per-repo override
---@return table|nil forge, string|nil hint
local function forge_for(host, dir)
    if dir then
        -- --local: the override is per repo, as documented; a global value
        -- would silently re-label every other repo's links.
        local override = git_in_dir(dir, { "config", "--local", "--get", "nvim.forge" })
        if vim.v.shell_error == 0 and override ~= "" then
            local f = FORGES[override:lower()]
            if f then
                return f
            end
            return nil, ("nvim.forge is set to '%s'; expected one of: %s"):format(
                override,
                table.concat(vim.tbl_keys(FORGES), ", ")
            )
        end
    end
    if not host then
        return nil
    end
    for label in host:lower():gmatch("[^.]+") do
        if FORGES[label] then
            return FORGES[label]
        end
    end
    return nil,
        ("Unsupported forge for host: %s\nIf this host is a self-hosted forge, run:  git config --local nvim.forge <%s>"):format(
            host,
            table.concat(vim.tbl_keys(FORGES), "|")
        )
end

-- Resolve { dir, branch, remote_name, base, forge } for the current buffer, or
-- return nil after notifying why (not a branch / no remote / unknown forge).
-- `allow_detached`: a detached HEAD (bisect, a checked-out tag or commit) is
-- fine for a permalink, which links by SHA; `branch` is then nil and the
-- remote falls back to origin.
-- The buffer's file with symlinks resolved and, on case-insensitive macOS
-- filesystems, its on-disk case (fs_realpath canonicalises both; git's
-- --show-toplevel does too, so the two compare cleanly). A symlink such as
-- ~/.ideavimrc -> <repo>/.ideavimrc belongs to the repo it points into.
local function real_file()
    local file = vim.fn.expand("%:p")
    if file == "" then
        return nil
    end
    return vim.uv.fs_realpath(file) or vim.fn.resolve(file)
end

local function repo_context(allow_detached)
    local file = real_file()
    local dir = file and vim.fn.fnamemodify(file, ":h") or vim.fn.getcwd()
    local branch = git_in_dir(dir, { "branch", "--show-current" })
    if vim.v.shell_error ~= 0 then
        vim.notify("Not in a git repository", vim.log.levels.WARN)
        return nil
    end
    if branch == "" then
        if not allow_detached then
            vim.notify("Not on a git branch", vim.log.levels.WARN)
            return nil
        end
        branch = nil
    end
    -- Prefer the branch's configured upstream remote; fall back to origin.
    -- "." means the branch tracks another LOCAL branch -- not a forge.
    local remote_name = branch and git_in_dir(dir, { "config", "--get", "branch." .. branch .. ".remote" }) or ""
    if not branch or vim.v.shell_error ~= 0 or remote_name == "" or remote_name == "." then
        remote_name = "origin"
    end
    local remote = git_in_dir(dir, { "remote", "get-url", remote_name })
    if vim.v.shell_error ~= 0 or remote == "" then
        vim.notify("No git remote '" .. remote_name .. "'", vim.log.levels.WARN)
        return nil
    end
    local base, host, unresolved = to_web_url(remote, dir)
    if unresolved then
        -- Even with an nvim.forge override: the link would name the alias
        -- itself (https://work-gitlab/...), which serves nothing.
        vim.notify(("'%s' is an ssh alias with no HostName in your ssh config, so its web host is unknown"
            .. " -- add `HostName <real host>` for it, or use the real host in the remote URL"):format(host),
            vim.log.levels.WARN)
        return nil
    end
    local forge, hint = forge_for(host, dir)
    if not forge then
        vim.notify(hint or ("Unsupported forge for host: " .. tostring(host)), vim.log.levels.WARN)
        return nil
    end
    -- A second candidate for the branch's name ON the remote: its upstream
    -- (branch.<b>.merge), for a local branch published under another name
    -- (`mine` tracking origin/feat-remote). Only when that upstream is on THIS
    -- remote and is not the remote's default branch: a branch created with
    -- `git switch -c feat origin/main` has upstream main, and Space gm then
    -- offered a PR from main. The fallback prefers the local name whenever the
    -- remote has it (see _open_request_via_lsremote).
    local remote_branch
    if branch then
        local merge = git_in_dir(dir, { "config", "--get", "branch." .. branch .. ".merge" })
        local merge_remote = git_in_dir(dir, { "config", "--get", "branch." .. branch .. ".remote" })
        local name = merge:match("^refs/heads/(.+)$")
        if name and name ~= branch and merge_remote == remote_name then
            local head = git_in_dir(dir, { "symbolic-ref", "--quiet", "--short", "refs/remotes/" .. remote_name .. "/HEAD" })
            local default = vim.v.shell_error == 0 and head:gsub("^" .. vim.pesc(remote_name) .. "/", "") or nil
            if name ~= default and name ~= "main" and name ~= "master" then
                remote_branch = name
            end
        end
    end
    return {
        dir = dir, branch = branch, remote_branch = remote_branch, remote_name = remote_name, base = base, forge = forge,
    }
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
                if forge.cli_url_field and url ~= "" then
                    local ok, decoded = pcall(vim.json.decode, url)
                    url = (ok and type(decoded) == "table" and decoded[forge.cli_url_field]) or ""
                end
                if out.code == 0 and url ~= "" then
                    require("tajbanana.system_open").open(url)
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

-- Remote calls (ls-remote) run non-interactively and bounded:
--   * ssh in BatchMode with a connect timeout -- a passphrase or host-key
--     prompt used to be written onto the terminal and block. Those are OpenSSH
--     options, so they are added only when git's ssh program is OpenSSH (git
--     picks GIT_SSH_COMMAND, then core.sshCommand, then GIT_SSH, then ssh); a
--     GIT_SSH wrapper is left alone -- setting GIT_SSH_COMMAND overrode it;
--   * in its own process group (detach), killed as a whole after 5 s -- killing
--     only git left its ssh / git-remote-http child running and holding the
--     pipe, and vim.system's wait() then returned nil (a Lua error here).
local REMOTE_CHECK_MS = 5000
local function remote_env(dir)
    local env = { GIT_TERMINAL_PROMPT = "0" }
    local ssh = vim.env.GIT_SSH_COMMAND
    if not ssh or ssh == "" then
        ssh = vim.trim(vim.fn.system({ "git", "-C", dir, "config", "--get", "core.sshCommand" }))
        if vim.v.shell_error ~= 0 or ssh == "" then
            if vim.env.GIT_SSH and vim.env.GIT_SSH ~= "" then
                return env
            end
            ssh = "ssh"
        end
    end
    local prog = vim.fs.basename(ssh:match("^%s*(%S+)") or "")
    if prog == "ssh" or prog == "ssh.exe" then
        env.GIT_SSH_COMMAND = ssh .. " -o BatchMode=yes -o ConnectTimeout=5"
    end
    return env
end

-- SIGKILL process group `pgid` until it is empty (at most ~1 s). One killpg
-- was not enough: git first runs an `<ssh> -G` probe, and when the probe died
-- first, git could still fork the real ssh before its own SIGKILL landed; that
-- child kept the group id and was left running (about 1 run in 4 on macOS).
local function kill_group(pgid)
    local sweeps = 0
    local timer = assert(vim.uv.new_timer())
    local function sweep()
        sweeps = sweeps + 1
        if not vim.uv.kill(-pgid, "sigkill") or sweeps >= 20 then
            timer:close()
        end
    end
    timer:start(0, 50, sweep)
end

-- `git ls-remote <args>` in `dir`; cb(result) on exit, or cb(nil) when it
-- could not start or was killed at the time limit. cb runs in a fast event.
local function ls_remote(dir, args, cb)
    local done = false
    local timer = assert(vim.uv.new_timer())
    local ok, obj = pcall(vim.system, vim.list_extend({ "git", "-C", dir, "ls-remote" }, args), {
        text = true,
        detach = true,
        env = remote_env(dir),
    }, function(r)
        if not done then
            done = true
            timer:close()
            cb(r)
        end
    end)
    if not ok then
        done = true
        timer:close()
        cb(nil)
        return
    end
    timer:start(REMOTE_CHECK_MS, 0, function()
        if not done then
            done = true
            timer:close()
            kill_group(obj.pid)
            cb(nil)
        end
    end)
end

-- Whether `remote` has `sha`: any of its refs is at `sha` or (when that ref's
-- commit is available locally) descends from it. Asked only when no local
-- tracking ref proves it. The network call is bounded by REMOTE_CHECK_MS (the
-- wait allows 1 s more for the kill to land); the ancestry test after it is ONE
-- local `git rev-list` over every distinct tip -- one merge-base per ref froze
-- the editor for about a minute on a remote with thousands of refs (GitLab's
-- refs/merge-requests/*, tags). Returns pushed, and on false a reason when the
-- remote could not be asked at all ("timed out" / "failed") -- that used to be
-- reported as "not pushed, push first".
local function remote_has_commit(dir, remote, sha)
    local result, finished
    ls_remote(dir, { remote }, function(r)
        result, finished = r, true
    end)
    vim.wait(REMOTE_CHECK_MS + 1000, function()
        return finished
    end, 20)
    if not result then
        return false, "timed out"
    end
    if result.code ~= 0 then
        return false, "failed"
    end
    local tips, seen = {}, {}
    for line in (result.stdout or ""):gmatch("[^\n]+") do
        local tip = line:match("^(%x+)")
        if tip == sha then
            return true
        end
        if tip and not seen[tip] then
            seen[tip] = true
            tips[#tips + 1] = "^" .. tip
        end
    end
    if #tips == 0 then
        return false
    end
    -- Lists `sha` unless some tip reaches it; tips not present locally are
    -- skipped (--ignore-missing).
    local rl = vim.system({ "git", "-C", dir, "rev-list", "--ignore-missing", "-n", "1", "--stdin", sha }, {
        stdin = table.concat(tips, "\n") .. "\n",
        text = true,
    }):wait()
    return rl.code == 0 and vim.trim(rl.stdout or "") == ""
end

-- Token-free fallback for when the forge CLI is absent. Both forges publish
-- change-request heads as fetchable refs, so match the branch SHA against them
-- via ls-remote -- no CLI and no API token needed.
function M._open_request_via_lsremote(ctx, create_url)
    local forge = ctx.forge
    local names = { ctx.branch }
    if ctx.remote_branch and ctx.remote_branch ~= ctx.branch then
        names[2] = ctx.remote_branch
    end
    local args = { ctx.remote_name }
    for _, name in ipairs(names) do
        args[#args + 1] = "refs/heads/" .. name
    end
    args[#args + 1] = forge.head_glob
    ls_remote(
        ctx.dir,
        args,
        vim.schedule_wrap(function(out)
            if not out then
                vim.notify(("git ls-remote %s timed out or could not start"):format(ctx.remote_name), vim.log.levels.ERROR)
                return
            end
            if out.code ~= 0 then
                vim.notify("git ls-remote failed: " .. vim.trim(out.stderr or ""), vim.log.levels.ERROR)
                return
            end
            local best
            local requests, heads = {}, {}
            for line in (out.stdout or ""):gmatch("[^\n]+") do
                local sha, ref = line:match("^(%x+)%s+(%S+)$")
                local head = ref and ref:match("^refs/heads/(.+)$")
                if head then
                    heads[head] = sha
                elseif ref then
                    local num = ref:match(forge.head_pattern)
                    if num then
                        requests[#requests + 1] = { num = tonumber(num), sha = sha }
                    end
                end
            end
            -- The local name when the remote has it, else the upstream name
            -- when the remote has that, else the local name (not pushed yet).
            local name = names[1]
            if not heads[name] and names[2] and heads[names[2]] then
                name = names[2]
            end
            local branch_sha = heads[name]
            if name ~= ctx.branch or not create_url then
                create_url = forge.create_url(ctx.base, name)
            end
            for _, p in ipairs(requests) do
                if branch_sha and p.sha == branch_sha and (not best or p.num > best) then
                    best = p.num
                end
            end
            if best then
                require("tajbanana.system_open").open(ctx.base .. forge.request_path .. best)
            else
                require("tajbanana.system_open").open(create_url) -- none yet
            end
        end)
    )
end

local watch_copy_failure -- defined below

-- Copy `text` to the "+" clipboard; returns the message prefix saying whether
-- it really got there, and whether it did. setreg() cannot tell: providers copy
-- asynchronously and a failing copy command still returns success (only a
-- "clipboard: error" message appears). So the clipboard is read back -- except
-- over OSC 52, where a read asks the terminal and can block or be refused.
--
-- The read-back has to wait for the copy job: xclip, xsel, wl-copy and
-- win32yank (WSL) run with Neovim's selection cache on, and while the copy job
-- is alive getreg() returns that cache -- so an immediate read "confirmed" a
-- copy whose command then failed. A failed job exits at once, dropping the
-- cache, and the read then reaches the real clipboard. pbcopy has no cache.
local COPY_SETTLE_MS = 250

-- A copy command can also fail AFTER the read-back (a slow clipboard tool):
-- Neovim then only prints "clipboard: error …". Rather than make every link
-- wait longer, watch the message history for a few seconds and correct the
-- earlier "copied" with a warning if that error shows up.
local COPY_WATCH_MS = 3000
local function clipboard_errors()
    local ok, msgs = pcall(vim.fn.execute, "messages")
    local n = 0
    for _ in (ok and msgs or ""):gmatch("clipboard: error") do
        n = n + 1
    end
    return n
end
function watch_copy_failure(provider)
    local before = clipboard_errors()
    local timer = vim.uv.new_timer()
    local elapsed = 0
    local function finish()
        if not timer:is_closing() then
            timer:stop()
            timer:close()
        end
    end
    timer:start(200, 200, vim.schedule_wrap(function()
        -- A tick already queued when the timer was stopped still runs.
        if timer:is_closing() then
            return
        end
        elapsed = elapsed + 200
        if clipboard_errors() > before then
            finish()
            vim.notify("Permalink was NOT copied after all: the clipboard tool (" .. provider .. ") failed",
                vim.log.levels.WARN)
        elseif elapsed >= COPY_WATCH_MS then
            finish()
        end
    end))
end
local function copy_to_clipboard(text)
    if vim.fn.has("clipboard") ~= 1 or not pcall(vim.fn.setreg, "+", text) then
        return "Permalink (no clipboard, not copied): ", false
    end
    local ok, provider = pcall(vim.fn["provider#clipboard#Executable"])
    provider = ok and type(provider) == "string" and provider or ""
    if provider:find("OSC 52", 1, true) then
        return "Permalink sent to the terminal clipboard (OSC 52): ", true
    end
    if provider ~= "pbcopy" then
        vim.wait(COPY_SETTLE_MS, function() return false end)
    end
    local got_ok, got = pcall(vim.fn.getreg, "+")
    if got_ok and vim.trim(got) == text then
        if provider ~= "pbcopy" then
            watch_copy_failure(provider)
        end
        return "Permalink copied: ", true
    end
    return "Permalink (clipboard copy failed): ", false
end

-- Open the current file in the browser, anchored to a line (normal) or a line
-- range (visual). `range` is nil for the cursor line, or { start_line, end_line }.
function M.open_line(range)
    local ctx = repo_context(true)
    if not ctx then
        return
    end
    local file = real_file()
    if not file then
        vim.notify("No file to open", vim.log.levels.WARN)
        return
    end
    local root = require("tajbanana.gitutil").toplevel(ctx.dir)
    if not root then
        vim.notify("Not in a git repository", vim.log.levels.WARN)
        return
    end
    -- vim.fs.relpath does containment, separator normalisation and ./.. collapsing
    -- in one call, and returns nil when `file` is not under `root`. The previous
    -- `startswith(file, root .. "/")` plus `sub(#root + 2)` baked in a POSIX
    -- separator, so on native Windows -- where expand("%:p") yields backslashes
    -- but `git rev-parse --show-toplevel` always yields forward slashes -- it
    -- rejected every file in the repo.
    --
    -- Both sides canonical (see real_file): --show-toplevel resolves symlinks,
    -- and a path typed in the wrong case on macOS would otherwise not match.
    local relpath = vim.fs.relpath(vim.uv.fs_realpath(root) or root, file)
    if not relpath then
        vim.notify("File is outside the repository root", vim.log.levels.WARN)
        return
    end
    local sha = git_in_dir(ctx.dir, { "rev-parse", "HEAD" })
    if vim.v.shell_error ~= 0 or sha == "" then
        vim.notify("No commit to link to yet", vim.log.levels.WARN)
        return
    end
    -- The path as COMMITTED in HEAD, which is what the URL must name. Empty for
    -- an untracked or newly added file (the URL would 404 even with HEAD
    -- pushed). It can differ from the on-disk name: on macOS a file name may
    -- be decomposed Unicode (NFD) on disk while git stores it composed (NFC).
    -- --literal-pathspecs: `a[1].txt` is a file name, not a glob.
    -- Read byte for byte through vim.system: git_in_dir trims (a name starting
    -- with a space lost it) and vim.fn.system turns the -z NUL into \1 (a name
    -- containing \1 was cut there).
    local ls = vim.system({
        "git", "-C", root, "--literal-pathspecs", "ls-tree", "--full-name", "--name-only", "-z", "HEAD", "--", relpath,
    }):wait()
    local committed = ls.code == 0 and (ls.stdout or ""):match("^([^%z]*)%z") or ""
    if committed == "" then
        vim.notify("'" .. relpath .. "' is not committed yet -- commit and push first", vim.log.levels.WARN)
        return
    end
    relpath = committed
    -- Pushed = some remote-tracking ref of this remote already contains HEAD (as
    -- of the last fetch/push; no network call). A single-branch or shallow
    -- clone has no tracking ref for a branch pushed from it (its fetch refspec
    -- covers only the cloned branch), so a pushed HEAD was refused: then ask
    -- the remote once, bounded by a timeout, whether any of its refs (branches,
    -- tags, merge-request heads) is at HEAD or descends from it.
    local containing = git_in_dir(ctx.dir, {
        "for-each-ref", "--contains", sha, "--format=%(refname)", "refs/remotes/" .. ctx.remote_name,
    })
    local pushed, unreachable = vim.v.shell_error == 0 and containing ~= "", nil
    if not pushed then
        pushed, unreachable = remote_has_commit(ctx.dir, ctx.remote_name, sha)
    end
    if not pushed and unreachable then
        vim.notify(
            ("Could not check that HEAD %s is on '%s' (ls-remote %s) -- no link made. Fetch, or retry when the remote is reachable.")
                :format(sha:sub(1, 8), ctx.remote_name, unreachable),
            vim.log.levels.WARN
        )
        return
    end
    if not pushed then
        vim.notify(
            ("HEAD %s is not on '%s' yet -- push first (a permalink to it would 404)"):format(sha:sub(1, 8), ctx.remote_name),
            vim.log.levels.WARN
        )
        return
    end
    local frag
    if range and range[2] and range[1] ~= range[2] then
        frag = ctx.forge.range_anchor(range[1], range[2])
    else
        frag = string.format("#L%d", (range and range[1]) or vim.fn.line("."))
    end
    local url = ctx.base .. ctx.forge.blob_path .. sha .. "/" .. encode_component(relpath) .. frag
    -- Uncommitted edits (saved or not) mean the cursor's line numbers may not
    -- match the linked commit's file.
    git_in_dir(root, { "--literal-pathspecs", "diff", "--quiet", "HEAD", "--", relpath })
    local dirty = vim.v.shell_error ~= 0 or vim.bo.modified
    local prefix, copied = copy_to_clipboard(url)
    vim.notify(
        prefix .. url .. (dirty and "\n(file has uncommitted changes -- line numbers may be off)" or ""),
        (dirty or not copied) and vim.log.levels.WARN or vim.log.levels.INFO
    )
    require("tajbanana.system_open").open(url)
end

function M.setup()
    vim.keymap.set("n", "<leader>gm", M.open_request, { desc = "Forge: open/create PR or MR" })
    vim.keymap.set("n", "<leader>gl", function()
        M.open_line()
    end, { desc = "Forge: permalink to line (open + copy)" })
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
    end, { desc = "Forge: permalink to selected lines (open + copy)" })
end

return M
