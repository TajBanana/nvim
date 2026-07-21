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
                { "<leader>h", group = "Harpoon" },
                { "<leader>t", group = "Test / Toggle" },
                { "<leader>v", group = "LSP view" },
                { "<leader>x", group = "Diagnostics" },
                { "<leader>r", group = "Refactor / Rename" },
                { "<leader>c", group = "Code" },
                { "<leader>d", group = "Diff" },
                { "<leader>u", group = "Undo" },
                { "<leader>l", group = "LazyGit" },
            },
        },
    },
    {
        "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        event = "BufReadPre",
        opts = {},
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
            })

            vim.api.nvim_create_autocmd("VimEnter", {
                callback = function()
                    require("nvim-tree.api").tree.open()
                end,
            })
        end,
    },
}
