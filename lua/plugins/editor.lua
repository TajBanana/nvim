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
        "mbbill/undotree",
        keys = {
            { "<leader>ut", vim.cmd.UndotreeToggle, desc = "Toggle undotree" },
        },
    },
    {
        "folke/trouble.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        cmd = "Trouble",
        keys = {
            { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (Trouble)" },
            { "<leader>xb", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer diagnostics (Trouble)" },
        },
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
