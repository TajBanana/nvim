-- IntelliJ-style "whole-branch" gutter. gitsigns diffs each file against the
-- index by default, so a line loses its gutter mark the moment it is committed.
-- Here the *default* base is instead the point where the branch forked from
-- main (merge-base HEAD main), so every line changed anywhere on the branch --
-- committed or not -- stays marked, exactly like IntelliJ's per-branch view.
-- <leader>gB toggles the current buffer back to the plain working-tree (index)
-- view and back again.
--
-- Note: gitsigns has a single base per buffer, so committed-on-branch lines and
-- still-uncommitted lines render with the SAME add/change/delete sign -- the
-- gutter cannot colour "committed" vs "uncommitted" apart. The sign colour only
-- encodes the change TYPE (add=green, change=blue, delete=red; see colorscheme).
-- git toplevel -> { key = <HEAD sha + base-ref shas>, sha = <merge-base or false> }.
-- Keyed by HEAD because the fork point is a property of the current branch
-- (caching by repo alone made every later branch reuse the first one's base),
-- and by the main/master refs because "merge-base HEAD main" also moves when
-- main does (e.g. after part of the branch is merged) -- keyed by HEAD alone, a
-- re-open or <leader>gB toggle could never pick that up for the whole session.
local branch_base_cache = {}
local watch_repo -- defined below
local whole_branch = {} -- bufnr -> true while the whole-branch base is active
-- bufnr -> true while the whole-branch view is WANTED (default on; <leader>gB off
-- sets false, and that opt-out survives a re-attach such as :edit). Distinct
-- from whole_branch: a wanted buffer whose file is new on the branch sits on the
-- index base, but must be re-checked after a branch switch.
local want_branch = {}
-- bufnr -> the HEAD whose result is IN PLACE: its fork-point base applied, or
-- the index base when that HEAD has none (no main, file new on the branch). A
-- mismatch means HEAD moved (checkout, commit, rebase, reset) and the fork
-- point must be rechecked. Recorded only when a pass finishes -- it used to be
-- set before the last git call, so a pass that then turned out stale left a
-- claim for a base it never applied, and a later refresh for that HEAD (an
-- A->B->A switch) skipped the buffer for good. Cleared when the buffer is put
-- back on the index by other means (re-attach, <leader>gB off).
local applied_head = {}
-- bufnr -> the merge-base sha currently applied as its base. Two branches often
-- share a fork point, so a HEAD move frequently yields the SAME base -- then
-- change_base (a full re-diff of the buffer) is skipped.
local applied_base = {}

-- Candidate base refs, most preferred first: local main/master, then their
-- origin/ counterparts -- a single-branch clone or a `git worktree` checkout
-- often has no local main, only the remote-tracking ref.
local BASE_REFS = { "main", "master", "origin/main", "origin/master" }
local BASE_REFS_FULL = { "refs/heads/main", "refs/heads/master", "refs/remotes/origin/main", "refs/remotes/origin/master" }

-- Every git call below is ASYNC (vim.system + a scheduled callback): a HEAD
-- move with 40 open files used to run ~80 synchronous git spawns on the main
-- loop and freeze the editor for 2-3 s. `cb(code, stdout)` runs on the main loop.
local function git_async(args, cb)
    local ok = pcall(vim.system, vim.list_extend({ "git" }, args), { text = true }, vim.schedule_wrap(function(out)
        cb(out.code, out.stdout or "")
    end))
    if not ok then -- git missing / not executable
        vim.schedule(function()
            cb(-1, "")
        end)
    end
end

-- Which repo a buffer belongs to, and its path inside it. The authority is the
-- repo gitsigns itself diffs the buffer against (b:gitsigns_status_dict.root),
-- so the base we hand it always comes from that same repo -- resolving it
-- separately went wrong for a file opened through a symlink (gitsigns follows
-- the link) and for a sub-directory turned into its own repo mid-session
-- (gitsigns stays on the outer one). Both sides are fs_realpath'd.
local function buf_repo(bufnr)
    local name = vim.api.nvim_buf_get_name(bufnr)
    local file = name ~= "" and vim.uv.fs_realpath(name)
    local status = vim.b[bufnr].gitsigns_status_dict
    local root = status and status.root and vim.uv.fs_realpath(status.root)
    if not (file and root) then
        return nil
    end
    local rel = vim.fs.relpath(root, file)
    return rel and { root = root, rel = rel } or nil
end

-- `root`'s git dir and HEAD sha in ONE call. On an unborn HEAD (no commit yet)
-- rev-parse fails but still prints the git dir first, so the repo is watched
-- from the start and picked up after its first commit.
local function state_cmd(root)
    return { "-C", root, "rev-parse", "--absolute-git-dir", "HEAD" }
end
local function parse_state(code, stdout)
    local gitdir, head = stdout:match("^([^\n]+)\n([^\n]*)")
    if not gitdir then
        return nil
    end
    head = code == 0 and head:match("^%x+$") or nil
    return { gitdir = gitdir, head = head }
end

-- Read `root`'s state, newest-wins: every read is numbered, a read that lands
-- after a NEWER one gets that newer read's state instead of its own, and
-- latest_head[root] is the HEAD of the newest read. Two HEAD moves in quick
-- succession used to race: a slow pass for the older HEAD could finish last and
-- apply that branch's fork point; results for a HEAD that is no longer the
-- latest are now discarded. (A late read was first dropped outright; when the
-- newer read's pass had skipped the buffer -- e.g. a FocusGained refresh racing
-- a <leader>gB -- nothing applied the base at all.)
local state_seq, state_done, latest_head, latest_state = {}, {}, {}, {}
local function read_state(root, cb)
    state_seq[root] = (state_seq[root] or 0) + 1
    local my = state_seq[root]
    git_async(state_cmd(root), function(code, out)
        if (state_done[root] or 0) > my then
            return cb(latest_state[root])
        end
        state_done[root] = my
        local st = parse_state(code, out)
        latest_state[root] = st
        if st then
            latest_head[root] = st.head
        end
        cb(st)
    end)
end
local function is_stale(root, st)
    return latest_head[root] ~= nil and latest_head[root] ~= st.head
end

-- Refresh scheduling. refresh_branch_views is defined further down; this
-- forward declaration lets the git-dir watcher below reach it.
local refresh_branch_views
local refresh_timer
local function schedule_refresh()
    refresh_timer = refresh_timer or vim.uv.new_timer()
    refresh_timer:stop()
    refresh_timer:start(300, 0, vim.schedule_wrap(function()
        refresh_branch_views()
    end))
end

-- Watch each repo's git dir and its logs/ (logs/HEAD, the reflog, is appended
-- on EVERY HEAD move: commit, rebase, reset, checkout). gitsigns' own events
-- cannot be used for this: its per-buffer GitSignsUpdate only fires when that
-- buffer's hunks change -- and against a fixed fork-point base a rebase or a
-- commit elsewhere changes nothing -- while its data-less HEAD event only fires
-- when the branch NAME changes. Events are debounced into one async pass.
-- Tracked per path: logs/ only appears with the first commit, so a later call
-- adds it; a watcher that errors (repo deleted) is dropped and re-added later.
-- A repo's watchers are closed when the last buffer using it is wiped (they
-- used to live until an error, i.e. usually for the whole session).
local watched = {} -- path -> fs_event handle
local buf_gitdir = {} -- bufnr -> gitdir its watchers were registered for
local function unwatch_if_unused(gitdir)
    for _, g in pairs(buf_gitdir) do
        if g == gitdir then
            return
        end
    end
    for _, path in ipairs({ gitdir, gitdir .. "/logs" }) do
        local handle = watched[path]
        if handle then
            watched[path] = nil
            if not handle:is_closing() then
                handle:stop()
                handle:close()
            end
        end
    end
end
function watch_repo(gitdir)
    for _, path in ipairs({ gitdir, gitdir .. "/logs" }) do
        if not watched[path] and vim.uv.fs_stat(path) then
            local handle = vim.uv.new_fs_event()
            if handle then
                watched[path] = handle
                handle:start(path, {}, function(err)
                    if err then
                        handle:close()
                        watched[path] = nil
                    else
                        schedule_refresh()
                    end
                end)
            end
        end
    end
end

-- The fork point of `root` at `head`: `cb(sha_or_nil)`. Cached per repo, keyed
-- by HEAD and the base-ref SHAs (one for-each-ref per lookup); callers for the
-- same repo+HEAD share one in-flight lookup. merge-base runs against the HEAD
-- SHA that was read, not "HEAD", so the result always matches its cache key.
local fork_waiters = {} -- root .. "\0" .. head -> { cb, ... }
local function fork_point(root, head, cb)
    local id = root .. "\0" .. head
    if fork_waiters[id] then
        table.insert(fork_waiters[id], cb)
        return
    end
    fork_waiters[id] = { cb }
    local function finish(sha)
        local waiters = fork_waiters[id]
        fork_waiters[id] = nil
        for _, w in ipairs(waiters) do
            w(sha)
        end
    end
    git_async(vim.list_extend({ "-C", root, "for-each-ref", "--format=%(refname) %(objectname)" },
        vim.deepcopy(BASE_REFS_FULL)), function(_, refs)
        local key = head .. "\n" .. refs
        local cached = branch_base_cache[root]
        if cached and cached.key == key then
            return finish(cached.sha or nil)
        end
        -- merge-base <head> <ref> is the fork point; it is stable as main merely
        -- advances (only a rebase or a merge of branch commits into main moves it).
        local i = 0
        local function try_next()
            i = i + 1
            local ref = BASE_REFS[i]
            if not ref then
                branch_base_cache[root] = { key = key, sha = false }
                return finish(nil)
            end
            git_async({ "-C", root, "merge-base", head, ref }, function(code, out)
                local sha = vim.trim(out)
                if code == 0 and sha ~= "" then
                    branch_base_cache[root] = { key = key, sha = sha }
                    finish(sha)
                else
                    try_next()
                end
            end)
        end
        try_next()
    end)
end

-- Point bufnr's gitsigns base at the branch fork point, asynchronously;
-- `done(status)` gets "applied" | "not-at-fork" | "no-main" | "no-repo".
--
-- "not-at-fork": the file did not exist at the merge-base (it was created on
-- this branch). Diffing it against the fork point would make gitsigns render the
-- whole file as untracked (dashed ┆), so we leave it on the default index base
-- instead -- keeping branch-new committed files clean, and letting genuinely
-- untracked files show their own ┆ via attach_to_untracked. A buffer that WAS on
-- a fork-point base is reset to the index base in that case (and for "no-main").
-- `state` may be passed in by a caller that already read it.
local inflight = {} -- bufnr -> head being applied (skip duplicate passes)
local function apply_whole_branch(bufnr, done, state)
    done = done or function() end
    local repo = buf_repo(bufnr)
    if not repo then
        return done("no-repo")
    end
    local function with_state(st)
        if not st then
            return done("no-repo")
        end
        -- The buffer may have been wiped while the git call ran: registering
        -- watchers for it then leaked them (nothing would ever close them).
        if not vim.api.nvim_buf_is_valid(bufnr) then
            return done("skipped")
        end
        watch_repo(st.gitdir)
        -- Moved to another repo (:saveas): release the old repo's watchers.
        local prev = buf_gitdir[bufnr]
        buf_gitdir[bufnr] = st.gitdir
        if prev and prev ~= st.gitdir then
            unwatch_if_unused(prev)
        end
        -- Every exit of a pass goes through finish: `inflight` is released only
        -- when the pass is really over (it used to be released before the
        -- cat-file call), and `applied_head` is recorded only for a result
        -- that is actually in place.
        local function finish(status, in_place)
            if inflight[bufnr] == st.head then
                inflight[bufnr] = nil
            end
            if in_place then
                applied_head[bufnr] = st.head
            end
            done(status)
        end
        local function drop_base(status)
            if whole_branch[bufnr] then
                vim.api.nvim_buf_call(bufnr, function()
                    require("gitsigns").reset_base(false)
                end)
                whole_branch[bufnr] = nil
                applied_base[bufnr] = nil
            end
            finish(status, true)
        end
        if not st.head then -- no commit yet
            applied_head[bufnr] = nil
            return drop_base("no-main")
        end
        if inflight[bufnr] == st.head then
            return done("pending")
        end
        inflight[bufnr] = st.head
        fork_point(repo.root, st.head, function(sha)
            if not vim.api.nvim_buf_is_valid(bufnr) or want_branch[bufnr] == false then
                return finish("skipped")
            end
            if is_stale(repo.root, st) then
                return finish("stale") -- HEAD moved again meanwhile; the newer pass applies
            end
            if not sha then
                return drop_base("no-main")
            end
            if whole_branch[bufnr] and applied_base[bufnr] == sha then
                return finish("applied", true)
            end
            -- "Was this file present in the fork-point tree?" (path from the
            -- repo root, so symlinks and sub-directories resolve like gitsigns).
            git_async({ "-C", repo.root, "cat-file", "-e", sha .. ":" .. repo.rel }, function(code)
                if not vim.api.nvim_buf_is_valid(bufnr) or want_branch[bufnr] == false then
                    return finish("skipped")
                end
                if is_stale(repo.root, st) then
                    return finish("stale")
                end
                if code ~= 0 then
                    return drop_base("not-at-fork")
                end
                vim.api.nvim_buf_call(bufnr, function()
                    require("gitsigns").change_base(sha, false)
                end)
                whole_branch[bufnr] = true
                applied_base[bufnr] = sha
                finish("applied", true)
            end)
        end)
    end
    if state then
        return with_state(state)
    end
    read_state(repo.root, with_state)
end

-- Re-apply the whole-branch base to every buffer that wants it after HEAD moves.
-- The default latch below applies the base once per buffer, so without this a
-- `git checkout other-branch` (or a rebase onto a newer main) left open buffers
-- diffing against the OLD fork point until they were reopened. A pass is one
-- async rev-parse per repo, one for-each-ref (+ merge-base on a cache miss) per
-- repo whose HEAD moved, and one cat-file per buffer whose fork point changed --
-- all off the main loop. Buffers whose HEAD is unchanged are skipped, and
-- change_base runs only when the fork point itself moved.
function refresh_branch_views()
    local by_root = {}
    for bufnr, want in pairs(want_branch) do
        if want and vim.api.nvim_buf_is_loaded(bufnr) then
            local repo = buf_repo(bufnr)
            if repo then
                by_root[repo.root] = by_root[repo.root] or {}
                table.insert(by_root[repo.root], bufnr)
            end
        end
    end
    for root, bufs in pairs(by_root) do
        read_state(root, function(st)
            if not st then
                return
            end
            local live = vim.tbl_filter(function(b) return vim.api.nvim_buf_is_valid(b) end, bufs)
            if #live == 0 then
                return -- all wiped meanwhile: do not (re-)watch a repo nobody uses
            end
            watch_repo(st.gitdir)
            for _, bufnr in ipairs(live) do
                if want_branch[bufnr] and vim.api.nvim_buf_is_loaded(bufnr) and st.head ~= applied_head[bufnr] then
                    apply_whole_branch(bufnr, nil, st)
                end
            end
        end)
    end
end

-- When to refresh (besides the git-dir watcher in watch_repo): the data-less
-- GitSignsUpdate gitsigns emits when the branch name changes, and FocusGained.
-- Registered once.
local refresh_registered = false
local function register_branch_refresh()
    if refresh_registered then
        return
    end
    refresh_registered = true
    local group = vim.api.nvim_create_augroup("WholeBranchRefresh", { clear = true })
    vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "GitSignsUpdate",
        callback = function(ev)
            if not (ev.data and ev.data.buffer) then
                refresh_branch_views()
            end
        end,
    })
    vim.api.nvim_create_autocmd("FocusGained", { group = group, callback = refresh_branch_views })
end

return {
    -- fugitive was removed: lazygit (<leader>lg) covers status/staging/commits,
    -- and gitsigns.diffthis covers the side-by-side diff it provided.
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            -- Show signs on genuinely untracked files (off by default) so new
            -- files aren't invisible. Safe alongside the whole-branch base
            -- because apply_whole_branch leaves fork-absent files on the index
            -- base, so only real untracked files -- not branch-new committed
            -- ones -- get the dashed ┆ (GitSignsUntracked) sign.
            attach_to_untracked = true,
            on_attach = function(bufnr)
                local gitsigns = require("gitsigns")
                register_branch_refresh()
                -- A (re-)attach starts on gitsigns' default index base, so any
                -- base we recorded for this buffer number no longer holds.
                whole_branch[bufnr] = nil
                applied_base[bufnr] = nil
                applied_head[bufnr] = nil

                local function map(mode, l, r, opts)
                    opts = opts or {}
                    opts.buffer = bufnr
                    vim.keymap.set(mode, l, r, opts)
                end

                -- Default this buffer to the whole-branch view (IntelliJ-style).
                -- We latch on the FIRST GitSignsUpdate for this buffer rather
                -- than acting in on_attach directly: gitsigns' initial index-
                -- based diff is still in flight during attach and would land
                -- after (and overwrite) an early change_base, and it is that
                -- update that publishes b:gitsigns_status_dict (the repo root).
                -- Applied once only, so a later manual toggle to the index view
                -- is not clobbered. Silent no-op outside git / with no main.
                --
                -- Per-buffer augroup, cleared on every (re-)attach: :edit re-runs
                -- on_attach, and plain autocmds stacked one more BufWipeout
                -- handler (and latch) per :edit.
                local group = vim.api.nvim_create_augroup("WholeBranchBuf" .. bufnr, { clear = true })
                local default_applied = false
                vim.api.nvim_create_autocmd("User", {
                    group = group,
                    pattern = "GitSignsUpdate",
                    callback = function(ev)
                        -- gitsigns emits GitSignsUpdate from three places and only
                        -- the per-buffer one (status.lua) carries data.buffer; the
                        -- HEAD-watcher and setup emits pass no data at all. Guard
                        -- before indexing, or every data-less emit (notably every
                        -- branch switch) throws once per still-latched buffer.
                        local updated = ev.data and ev.data.buffer
                        if default_applied or updated ~= bufnr then
                            return
                        end
                        default_applied = true
                        -- A <leader>gB opt-out outlives a re-attach (:edit
                        -- re-runs on_attach); only a fresh buffer defaults on.
                        if want_branch[bufnr] ~= false then
                            want_branch[bufnr] = true
                            apply_whole_branch(bufnr)
                        end
                        -- One-shot: returning true deletes this autocmd, so it
                        -- does not fire on every later GitSignsUpdate.
                        return true
                    end,
                })

                -- Renamed (:saveas, :file): if the new name is outside the repo
                -- this buffer's watchers are for, release them now. A move
                -- into another repo is handled by the next pass; a move out
                -- of git gets no pass (gitsigns detaches), so the old repo
                -- stayed watched until the buffer was wiped.
                vim.api.nvim_create_autocmd("BufFilePost", {
                    group = group,
                    buffer = bufnr,
                    callback = function()
                        local prev = buf_gitdir[bufnr]
                        if not prev then
                            return
                        end
                        local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
                        git_async({ "-C", dir, "rev-parse", "--absolute-git-dir" }, function(code, out)
                            local gitdir = code == 0 and vim.trim(out) or nil
                            if buf_gitdir[bufnr] == prev and gitdir ~= prev then
                                buf_gitdir[bufnr] = nil
                                unwatch_if_unused(prev)
                            end
                        end)
                    end,
                })

                -- Clean up per-buffer state on wipeout, so a recycled buffer
                -- number can't inherit a stale view. Mirrors the BufWipeout
                -- guard cleanup in lsp.lua.
                vim.api.nvim_create_autocmd("BufWipeout", {
                    group = group,
                    buffer = bufnr,
                    once = true,
                    callback = function()
                        whole_branch[bufnr] = nil
                        want_branch[bufnr] = nil
                        applied_head[bufnr] = nil
                        applied_base[bufnr] = nil
                        inflight[bufnr] = nil
                        local gitdir = buf_gitdir[bufnr]
                        buf_gitdir[bufnr] = nil
                        if gitdir then
                            unwatch_if_unused(gitdir)
                        end
                        pcall(vim.api.nvim_del_augroup_by_id, group)
                    end,
                })

                map("n", "<leader>gB", function()
                    local gs = require("gitsigns")
                    if whole_branch[bufnr] then
                        gs.reset_base(false)
                        whole_branch[bufnr] = false
                        applied_head[bufnr] = nil
                        applied_base[bufnr] = nil
                        want_branch[bufnr] = false -- don't re-apply on branch switch
                        vim.notify("git signs: working-tree view (vs index)", vim.log.levels.INFO)
                        return
                    end
                    want_branch[bufnr] = true
                    apply_whole_branch(bufnr, function(status)
                        if status == "applied" then
                            vim.notify("git signs: whole-branch view (vs merge-base main)", vim.log.levels.INFO)
                        elseif status == "not-at-fork" then
                            vim.notify("git signs: file is new on this branch; working-tree view", vim.log.levels.INFO)
                        elseif status == "no-repo" then
                            vim.notify("git signs: not in a git repo gitsigns tracks", vim.log.levels.WARN)
                        elseif status == "no-main" then
                            vim.notify("git signs: no main/master to diff against", vim.log.levels.WARN)
                        end
                    end)
                end, { desc = "Toggle whole-branch git signs" })

                -- preview = true pops the hunk diff in a float after jumping.
                -- The float self-dismisses on cursor movement (gitsigns installs
                -- its own CursorMoved close) and on <Esc> (set.lua's float-closer,
                -- since it is a relative='cursor' float). In a diffthis view we
                -- fall back to plain ]c/[c navigation.
                map("n", "<leader>pp", function()
                    if vim.wo.diff then
                        vim.cmd.normal({ "]c", bang = true })
                    else
                        gitsigns.nav_hunk("next", { preview = true })
                    end
                end, { desc = "Next git hunk (preview)" })

                map("n", "<leader>oo", function()
                    if vim.wo.diff then
                        vim.cmd.normal({ "[c", bang = true })
                    else
                        gitsigns.nav_hunk("prev", { preview = true })
                    end
                end, { desc = "Previous git hunk (preview)" })

                map("n", "<leader>gp", gitsigns.preview_hunk, { desc = "Preview git hunk" })
                -- Diff against the buffer's CURRENT base: the branch fork point by
                -- default, the index after <leader>gB. The fork point is passed
                -- EXPLICITLY: diffthis() with no base treats the base as the
                -- index and makes that buffer writable, where `:w` stages it --
                -- so writing the fork-point text staged it, reverting the
                -- branch's committed changes in the index. With a revision the
                -- diff buffer is `nowrite`. (The index view keeps gitsigns'
                -- writable index buffer on purpose.) Passed as `<sha>^{commit}`
                -- -- the same commit, but not string-equal to the buffer's
                -- revision: for an equal one gitsigns reuses its cached compare
                -- text, which it drops on every invalidation, and then fails an
                -- assert (no diff opens).
                map("n", "<leader>dv", function()
                    local base = whole_branch[bufnr] and applied_base[bufnr]
                    gitsigns.diffthis(base and (base .. "^{commit}") or nil)
                end, { desc = "Diff file vs gutter base (fork point / index)" })
                -- Inline diff of the hunk under the cursor (deleted lines shown in place).
                -- Replaces the whole-buffer toggle_deleted, which gitsigns deprecated
                -- in favour of this.
                map("n", "<leader>td", gitsigns.preview_hunk_inline, { desc = "Preview hunk inline" })
                map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "Select git hunk" })
            end,
        },
    },
    {
        "f-person/git-blame.nvim",
        event = { "BufReadPre", "BufNewFile" },
    },
    {
        -- IntelliJ-style annotate: EVERY line shows its own commit/author/date
        -- (strict 1:1 rows — no commit grouping, no summary rows, no virtual
        -- lines), so row N in the pane always describes line N of the code.
        -- Replaces the gitsigns blame pane, whose grouped layout plus
        -- scrollbind drift kept misaligning rows against the code.
        "FabijanZulj/blame.nvim",
        cmd = "BlameToggle",
        keys = {
            { "<leader>gb", "<cmd>BlameToggle window<cr>", desc = "Toggle git blame (annotate pane)" },
        },
        config = function()
            require("blame").setup({
                date_format = "%Y-%m-%d",
                focus_blame = false, -- keep the cursor in the editor
                merge_consecutive = false, -- true per-line semantics
            })

            -- 'scrollbind' (which blame.nvim also relies on) keeps a relative
            -- offset that goes stale after jumps, drifting the pane rows away
            -- from the code (observed 10-line divergence). Re-align whenever
            -- either window scrolls and the views disagree.
            vim.api.nvim_create_autocmd("WinScrolled", {
                group = vim.api.nvim_create_augroup("BlameScrollSync", { clear = true }),
                callback = function()
                    local pane, editor
                    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                        local ft = vim.bo[vim.api.nvim_win_get_buf(w)].filetype
                        if ft == "blame" then
                            pane = w
                        elseif vim.wo[w].scrollbind and vim.bo[vim.api.nvim_win_get_buf(w)].buftype == "" then
                            -- gitsigns.diffthis also sets 'scrollbind', so the
                            -- diff counterpart must be excluded or the pane syncs
                            -- to ITS topline instead of the source window's.
                            -- Discriminate on buftype, NOT on 'diff': :diffthis
                            -- sets 'diff' on BOTH halves, so `not vim.wo[w].diff`
                            -- excluded the source window too and left `editor`
                            -- nil -- silently disabling this whole handler for as
                            -- long as a diff was open. Verified: the counterpart
                            -- is buftype=acwrite (name `.git//<sha>:<path>`)
                            -- while the source window is buftype="".
                            editor = w
                        end
                    end
                    if not (pane and editor) then
                        return
                    end
                    local src = (vim.api.nvim_get_current_win() == pane) and pane or editor
                    local dst = (src == pane) and editor or pane
                    local sv = vim.api.nvim_win_call(src, vim.fn.winsaveview)
                    local dv = vim.api.nvim_win_call(dst, vim.fn.winsaveview)
                    if dv.topline ~= sv.topline or dv.topfill ~= sv.topfill then
                        vim.api.nvim_win_call(dst, function()
                            vim.fn.winrestview({ topline = sv.topline, topfill = sv.topfill })
                        end)
                    end
                end,
            })
        end,
    },
    {
        "kdheepak/lazygit.nvim",
        cmd = "LazyGit",
        dependencies = { "nvim-lua/plenary.nvim" },
        init = function()
            -- Bigger floating window: fraction of the editor each dimension fills (default 0.9)
            vim.g.lazygit_floating_window_scaling_factor = 0.95
            vim.g.lazygit_floating_window_winblend = 0 -- no transparency, keeps colors true
            vim.g.lazygit_floating_window_border_chars = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
            -- Always use this repo's lazygit/config.yml (passed as -ucf). lazygit
            -- reads its own config from a per-OS dir (~/Library/Application
            -- Support/lazygit on macOS, ~/.config/lazygit on Linux), so the
            -- documented ~/.config symlink silently did nothing on macOS.
            vim.g.lazygit_use_custom_config_file_path = 1
            vim.g.lazygit_config_file_path = vim.fn.stdpath("config") .. "/lazygit/config.yml"
        end,
        keys = {
            { "<leader>lg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
        },
    },
}
