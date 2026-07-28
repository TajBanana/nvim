return {
    {
        "nvim-tree/nvim-web-devicons",
        lazy = true,
    },
    {
        "nvim-lualine/lualine.nvim",
        event = "VeryLazy",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        opts = {
            options = {
                icons_enabled = true,
                theme = "onedark",
            },
            sections = {
                lualine_a = {
                    {
                        "filename",
                        path = 1, -- relative path
                        shorting_target = 0, -- disable width-relative shortening; use fmt below
                        -- Keep the last 2 segments (parent dir + filename) fully
                        -- readable and mark deeper truncation with "…/". Deep
                        -- package paths become meaningful instead of initials:
                        --   server/src/main/kotlin/.../controller/ExerciseController.kt
                        --     -> …/controller/ExerciseController.kt
                        -- Short paths pass through untouched:
                        --   lib/components/Card.tsx -> lib/components/Card.tsx
                        fmt = function(name)
                            if not name or name == "" then
                                return name
                            end
                            local keep = 2 -- trailing segments to keep in full
                            local parts = vim.split(name, "/", { plain = true })
                            if #parts <= keep then
                                return name
                            end
                            local tail = vim.list_slice(parts, #parts - keep + 1, #parts)
                            return "…/" .. table.concat(tail, "/")
                        end,
                    },
                },
                -- %S renders the pending-keystroke display here (cmdheight=0 +
                -- showcmdloc="statusline"), so the keys you press show in this row
                lualine_x = { "%S", "encoding", "fileformat", "filetype" },
            },
        },
    },
    {
        "j-hui/fidget.nvim",
        event = "LspAttach",
        opts = {},
    },
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {
            spec = {
                { "<leader>f", group = "Find" },
                { "<leader>g", group = "Git / Goto" },
                { "<leader>t", group = "Test / Toggle" },
                { "<leader>v", group = "LSP view" },
                { "<leader>x", group = "Diagnostics" },
                { "<leader>r", group = "Refactor / Rename" },
                { "<leader>c", group = "Code" },
                { "<leader>d", group = "Diff" },
                { "<leader>u", group = "Undo" },
                { "<leader>l", group = "LazyGit" },
                { "<leader>m", group = "Markdown" },
                { "<leader>o", group = "Hunk prev" },
                { "<leader>p", group = "Hunk next" },
            },
        },
    },
    {
        "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        event = "BufReadPre",
        -- Keep the highlighted current-scope guide, but drop the underline that
        -- ibl otherwise draws on the scope's first/last line. Point the guide at
        -- our own IblScope group (a darker muted rose, set in colorscheme.lua):
        -- ibl manages the @ibl.* namespace itself, so a custom group is the
        -- reliable way to recolour the scope.
        opts = {
            scope = { show_start = false, show_end = false, highlight = { "IblScope" } },
        },
    },
    {
        "nvim-tree/nvim-tree.lua",
        lazy = false,
        dependencies = { "nvim-tree/nvim-web-devicons" },
        keys = {
            { "<A-1>", "<cmd>NvimTreeFindFileToggle<cr>", desc = "Toggle file tree" },
        },
        config = function()
            vim.g.loaded_netrw = 1
            vim.g.loaded_netrwPlugin = 1

            require("nvim-tree").setup({
                view = {
                    -- fixed width: dynamic resizing leaves stale-cell redraw
                    -- artifacts at the tree's right edge
                    width = 40,
                },
                update_focused_file = {
                    enable = true,
                },
                renderer = {
                    -- Colour entry NAMES by git status (default only colours the
                    -- status icon). Used to tint git-ignored files/folders -- see
                    -- the NvimTreeGit*IgnoredHL overrides in colorscheme.lua, which
                    -- also pin every other status to normal so tracked files are
                    -- visually unchanged.
                    highlight_git = "name",
                },
                on_attach = function(bufnr)
                    local api = require("nvim-tree.api")
                    api.config.mappings.default_on_attach(bufnr)
                    -- E: toggle recursive expansion of the directory under the
                    -- cursor only (default E expands the entire tree; W still
                    -- collapses all). Expanded dir -> collapse; collapsed ->
                    -- expand everything beneath it.
                    vim.keymap.set("n", "E", function()
                        local node = api.tree.get_node_under_cursor()
                        if node and not node.nodes then
                            node = node.parent -- on a file: act on its directory
                        end
                        if not node then
                            return
                        end
                        if node.open then
                            api.node.collapse(node)
                        else
                            api.tree.expand_all(node)
                        end
                    end, { buffer = bufnr, desc = "Toggle expand directory under cursor" })
                end,
            })

            -- Auto-open the tree only when browsing: nvim started on a directory
            -- (`nvim .`) or with no file at all. Opening a single file (`nvim foo`)
            -- leaves just the file -- no tree rooted at the containing folder.
            vim.api.nvim_create_autocmd("VimEnter", {
                callback = function(data)
                    local opened_dir = vim.fn.isdirectory(data.file) == 1
                    local no_file = data.file == "" and vim.bo[data.buf].buftype == ""
                    if opened_dir or no_file then
                        require("nvim-tree.api").tree.open()
                    end
                end,
            })
        end,
    },
}
