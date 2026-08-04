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

-- side-by-side only fits when the preview pane is genuinely wide. Below this
-- many columns delta's split becomes two unreadable slivers, so fall back to the
-- unified view rather than honouring the preference blindly.
local SIDE_BY_SIDE_MIN_COLS = 120

local function delta_args()
    local wide = vim.o.columns >= SIDE_BY_SIDE_MIN_COLS
    return {
        "-c",
        "core.pager=delta",
        "-c",
        "delta.side-by-side=" .. tostring(wide),
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

local function delta_previewer(for_file)
    local previewers = require("telescope.previewers")
    return previewers.new_termopen_previewer({
        get_command = function(entry)
            if not entry or not entry.value then
                return { "echo", "" }
            end
            local cmd = { "git" }
            vim.list_extend(cmd, delta_args())
            -- `<sha>^!` means "this commit against its parent", which is the
            -- diff the commit introduced. It also works for a root commit,
            -- where `<sha>^` alone would fail.
            vim.list_extend(cmd, { "diff", entry.value .. "^!" })
            -- git_bcommits entries carry the file the picker was opened on;
            -- scope the diff to it so the preview matches the list.
            if for_file and entry.current_file then
                vim.list_extend(cmd, { "--", entry.current_file })
            end
            return cmd
        end,
    })
end

local function in_repo()
    if require("tajbanana.gitutil").toplevel(vim.fn.getcwd()) then
        return true
    end
    vim.notify("Not inside a git repository", vim.log.levels.WARN)
    return false
end

function M.commits()
    if not in_repo() then
        return
    end
    require("telescope.builtin").git_commits({ previewer = delta_previewer(false) })
end

function M.file_commits()
    if not in_repo() then
        return
    end
    if vim.fn.expand("%") == "" then
        vim.notify("No file in this buffer", vim.log.levels.WARN)
        return
    end
    require("telescope.builtin").git_bcommits({ previewer = delta_previewer(true) })
end

return M
