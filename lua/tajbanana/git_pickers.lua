-- Telescope git-history pickers that preview through git-delta.
--
--   <leader>gc  repo commit log      -- preview: the whole commit, side by side
--   <leader>gh  this file's history  -- preview: that commit's change to this file
--
-- Why a custom previewer: Telescope's stock git_commits previewer shells out to
-- `git diff` and renders the raw unified output into a normal buffer, so there
-- is no pager and delta never runs. new_termopen_previewer instead runs the
-- command inside a terminal buffer -- which IS a tty -- so git honours
-- `core.pager` and delta takes over. The delta settings are passed with `-c`
-- rather than read from ~/.gitconfig so the preview looks the same even if the
-- user's global config is absent or set to a different pager.
--
-- Terminal git and lazygit are configured separately; see git/delta.gitconfig
-- and lazygit/config.yml.
local M = {}

-- side-by-side only fits when the preview PANE is genuinely wide. Below this
-- many columns delta's split becomes two unreadable slivers, so fall back to the
-- unified view rather than honouring the preference blindly. Measured on the
-- preview window itself: the whole screen (vim.o.columns, as this used to use)
-- is roughly twice the pane, so side-by-side was picked for panes too narrow
-- for it.
local SIDE_BY_SIDE_MIN_COLS = 100

-- The git -c options that page through delta. Without delta, --no-pager:
-- setting core.pager=delta without it left the preview blank, and leaving the
-- pager unset still did -- git then fell back to the user's own core.pager,
-- which is `delta` again when git/delta.gitconfig is included ("unable to
-- execute pager 'delta'"), or to `less`, which waited at a ':' prompt.
local function delta_args(width)
    if vim.fn.executable("delta") ~= 1 then
        return { "--no-pager" }
    end
    return {
        "-c",
        "core.pager=delta",
        "-c",
        "delta.side-by-side=" .. tostring(width >= SIDE_BY_SIDE_MIN_COLS),
        "-c",
        "delta.line-numbers=true",
        "-c",
        "delta.paging=never",
        "-c",
        "delta.syntax-theme=TwoDark",
        "-c",
        "delta.dark=true",
    }
end

-- The git command that shows what `sha` changed (optionally only `file`).
-- `git show --format= --diff-merges=first-parent`: a merge commit shows what it
-- brought in relative to its first parent, and a root commit shows its full
-- content. The previous `git diff <sha>^!` printed nothing for a merge and, for
-- a root commit, compared against the working tree (later commits and
-- uncommitted edits included). Exposed for testing.
function M._show_cmd(sha, file, width)
    local cmd = { "git" }
    vim.list_extend(cmd, delta_args(width))
    vim.list_extend(cmd, { "show", "--format=", "--diff-merges=first-parent", sha })
    if file then
        vim.list_extend(cmd, { "--", file })
    end
    return cmd
end

-- The preview terminal's environment. With delta, GIT_PAGER=delta: it beats
-- every other pager setting (a user's GIT_PAGER, pager.show, core.pager) --
-- `-c core.pager=delta` alone lost to those, and with `pager.show=less` the
-- preview hung at less's prompt. Without delta, --no-pager already covers it.
-- Exposed for testing.
function M._preview_env()
    if vim.fn.executable("delta") == 1 then
        return { GIT_PAGER = "delta" }
    end
end

-- The repo the pickers work on: the current FILE's repo (Space gh used to take
-- nvim's cwd, so a file from another repo got "Not inside a git repository" or
-- an empty list), else the cwd's. Exposed for testing.
function M._repo_root()
    local gitutil = require("tajbanana.gitutil")
    local name = vim.api.nvim_buf_get_name(0)
    local dir = name ~= "" and vim.fs.dirname(name) or nil
    return (dir and vim.uv.fs_stat(dir) and gitutil.toplevel(dir)) or gitutil.toplevel(vim.fn.getcwd())
end

local function delta_previewer(for_file, root)
    local previewers = require("telescope.previewers")
    return previewers.new_termopen_previewer({
        cwd = root,
        env = M._preview_env(),
        get_command = function(entry, status)
            if not entry or not entry.value then
                return { "echo", "" }
            end
            local win = status and status.layout and status.layout.preview and status.layout.preview.winid
            local width = (win and vim.api.nvim_win_is_valid(win)) and vim.api.nvim_win_get_width(win)
                or math.floor(vim.o.columns / 2)
            -- git_bcommits entries carry the file the picker was opened on;
            -- scope the diff to it so the preview matches the list.
            return M._show_cmd(entry.value, for_file and entry.current_file or nil, width)
        end,
    })
end

function M.commits()
    local root = M._repo_root()
    if not root then
        vim.notify("Not inside a git repository", vim.log.levels.WARN)
        return
    end
    require("telescope.builtin").git_commits({ cwd = root, previewer = delta_previewer(false, root) })
end

function M.file_commits()
    if vim.fn.expand("%") == "" then
        vim.notify("No file in this buffer", vim.log.levels.WARN)
        return
    end
    local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
    local root = vim.uv.fs_stat(dir) and require("tajbanana.gitutil").toplevel(dir)
    if not root then
        vim.notify("This file is not inside a git repository", vim.log.levels.WARN)
        return
    end
    require("telescope.builtin").git_bcommits({ cwd = root, previewer = delta_previewer(true, root) })
end

return M
