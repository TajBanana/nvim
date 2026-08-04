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
-- git toplevel -> { head = <branch-or-sha>, sha = <merge-base sha or false> }.
-- Keyed by repo AND the HEAD it was computed from: the fork point is a property
-- of the current branch, so caching by repo alone made every branch after the
-- first reuse the first branch's base for the rest of the session.
local branch_base_cache = {}
local whole_branch = {} -- bufnr -> true while the whole-branch base is active

local function merge_base(bufnr)
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name == "" or vim.fn.filereadable(name) == 0 then
        return nil
    end
    local dir = vim.fn.fnamemodify(name, ":p:h")
    local top = require("tajbanana.gitutil").toplevel(dir)
    if not top then
        return nil
    end
    -- Identify the current HEAD so the cache entry is invalidated by a branch
    -- switch. Falls back to the detached-HEAD sha when there is no branch name.
    local head = vim.trim(vim.fn.system({ "git", "-C", dir, "rev-parse", "--abbrev-ref", "HEAD" }))
    if vim.v.shell_error ~= 0 or head == "" then
        return nil
    end
    local cached = branch_base_cache[top]
    if cached and cached.head == head then
        return cached.sha or nil
    end
    -- Prefer local main, then master, then their origin/ counterparts -- a
    -- single-branch clone or a `git worktree` checkout often has no local main,
    -- only the remote-tracking ref. merge-base HEAD <ref> is the fork point and
    -- is stable as main advances (only a rebase/merge-in would move it).
    for _, ref in ipairs({ "main", "master", "origin/main", "origin/master" }) do
        local sha = vim.trim(vim.fn.system({ "git", "-C", dir, "merge-base", "HEAD", ref }))
        if vim.v.shell_error == 0 and sha ~= "" then
            branch_base_cache[top] = { head = head, sha = sha }
            return sha
        end
    end
    branch_base_cache[top] = { head = head, sha = false }
    return nil
end

-- Point the given buffer's gitsigns base at the branch fork point. change_base(_,
-- false) acts on the current buffer, so we make bufnr current for the call.
-- Returns a status string: "applied" | "not-at-fork" | "no-main".
--
-- "not-at-fork": the file did not exist at the merge-base (it was created on
-- this branch). Diffing it against the fork point would make gitsigns render the
-- whole file as untracked (dashed ┆), so we leave it on the default index base
-- instead -- keeping branch-new committed files clean, and letting genuinely
-- untracked files show their own ┆ via attach_to_untracked.
local function enable_whole_branch(bufnr)
    local sha = merge_base(bufnr)
    if not sha then
        return "no-main"
    end
    local name = vim.api.nvim_buf_get_name(bufnr)
    local dir = vim.fn.fnamemodify(name, ":p:h")
    local base = vim.fn.fnamemodify(name, ":t")
    -- `<rev>:./<path>` resolves relative to cwd (dir), so this asks "was this
    -- file present in the fork-point tree?" Exit non-zero => it wasn't.
    vim.fn.system({ "git", "-C", dir, "cat-file", "-e", sha .. ":./" .. base })
    if vim.v.shell_error ~= 0 then
        return "not-at-fork"
    end
    vim.api.nvim_buf_call(bufnr, function()
        require("gitsigns").change_base(sha, false)
    end)
    whole_branch[bufnr] = true
    return "applied"
end

return {
    -- fugitive was removed: lazygit (<leader>lg) covers status/staging/commits,
    -- and gitsigns.diffthis covers the side-by-side diff it provided.
    {
        "lewis6991/gitsigns.nvim",
        event = "BufReadPre",
        opts = {
            -- Show signs on genuinely untracked files (off by default) so new
            -- files aren't invisible. Safe alongside the whole-branch base
            -- because enable_whole_branch leaves fork-absent files on the index
            -- base, so only real untracked files -- not branch-new committed
            -- ones -- get the dashed ┆ (GitSignsUntracked) sign.
            attach_to_untracked = true,
            on_attach = function(bufnr)
                local gitsigns = require("gitsigns")

                local function map(mode, l, r, opts)
                    opts = opts or {}
                    opts.buffer = bufnr
                    vim.keymap.set(mode, l, r, opts)
                end

                -- Default this buffer to the whole-branch view (IntelliJ-style).
                -- We latch on the FIRST GitSignsUpdate for this buffer rather
                -- than acting in on_attach directly: gitsigns' initial index-
                -- based diff is still in flight during attach and would land
                -- after (and overwrite) an early change_base. Once that first
                -- update settles our change_base is the last writer and sticks.
                -- Applied once only, so a later manual toggle to the index view
                -- is not clobbered. Silent no-op outside git / with no main.
                local default_applied = false
                local au_id
                au_id = vim.api.nvim_create_autocmd("User", {
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
                        enable_whole_branch(bufnr)
                        -- One-shot: drop the autocmd once this buffer's base is
                        -- set, so it doesn't linger for the session firing on
                        -- every future GitSignsUpdate of every buffer.
                        if au_id then
                            pcall(vim.api.nvim_del_autocmd, au_id)
                            au_id = nil
                        end
                    end,
                })

                -- Clean up per-buffer state on wipeout: the latch autocmd (in case
                -- its first GitSignsUpdate never fired) and the whole_branch flag,
                -- so a recycled buffer number can't inherit a stale view. Mirrors
                -- the BufWipeout guard cleanup in lsp.lua.
                vim.api.nvim_create_autocmd("BufWipeout", {
                    buffer = bufnr,
                    once = true,
                    callback = function()
                        whole_branch[bufnr] = nil
                        if au_id then
                            pcall(vim.api.nvim_del_autocmd, au_id)
                            au_id = nil
                        end
                    end,
                })

                map("n", "<leader>gB", function()
                    local gs = require("gitsigns")
                    if whole_branch[bufnr] then
                        gs.reset_base(false)
                        whole_branch[bufnr] = false
                        vim.notify("git signs: working-tree view (vs index)", vim.log.levels.INFO)
                        return
                    end
                    local status = enable_whole_branch(bufnr)
                    if status == "applied" then
                        vim.notify("git signs: whole-branch view (vs merge-base main)", vim.log.levels.INFO)
                    elseif status == "not-at-fork" then
                        vim.notify("git signs: file is new on this branch; working-tree view", vim.log.levels.INFO)
                    else
                        vim.notify("git signs: no main/master to diff against", vim.log.levels.WARN)
                    end
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
                map("n", "<leader>dv", gitsigns.diffthis, { desc = "Diff file vs index" })
                map("n", "<leader>td", gitsigns.toggle_deleted, { desc = "Toggle deleted lines" })
                map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "Select git hunk" })
            end,
        },
    },
    {
        "f-person/git-blame.nvim",
        event = "BufReadPre",
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
                        elseif vim.wo[w].scrollbind and not vim.wo[w].diff then
                            -- Skip diff windows: gitsigns.diffthis also sets
                            -- 'scrollbind', so with a diff split open alongside
                            -- the blame pane the pane would sync to the DIFF's
                            -- topline instead of the source window's -- exactly
                            -- the row drift this handler exists to correct.
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
        end,
        keys = {
            { "<leader>lg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
        },
    },
}
