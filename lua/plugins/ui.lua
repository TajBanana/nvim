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
                        path = 1,
                    },
                },
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
