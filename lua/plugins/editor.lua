return {
    {
        "kylechui/nvim-surround",
        version = "*",
        event = "BufReadPre",
        opts = {},
    },
    {
        "numToStr/Comment.nvim",
        event = "BufReadPre",
        opts = {},
    },
    {
        "m4xshen/autoclose.nvim",
        event = "InsertEnter",
        opts = {
            keys = {
                ["<"] = { escape = true, close = true, pair = "<>", disabled_filetypes = {} },
            },
        },
    },
    {
        -- Diagnostics are shown via Telescope (<leader>xx / <leader>xb); Trouble
        -- stays available as the :Trouble command (and as a kotlin.nvim dep).
        "folke/trouble.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        cmd = "Trouble",
        opts = {},
    },
    {
        "vim-test/vim-test",
        keys = {
            { "<leader>tt", "<cmd>TestNearest -strategy=neovim<cr>", silent = true, desc = "Test nearest" },
            { "<leader>tf", "<cmd>TestFile -strategy=neovim<cr>", silent = true, desc = "Test file" },
            { "<leader>ta", "<cmd>TestSuite<cr>", silent = true, desc = "Test suite" },
        },
    },
}
