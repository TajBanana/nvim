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
        opts = {},
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
            { "<A-1>", "<cmd>NvimTreeFindFileToggle<cr>" },
        },
        config = function()
            vim.g.loaded_netrw = 1
            vim.g.loaded_netrwPlugin = 1

            require("nvim-tree").setup({
                view = {
                    -- grow to fit names but never past 45 columns
                    width = { min = 25, max = 45 },
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
