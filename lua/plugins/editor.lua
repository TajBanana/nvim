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
            { "<leader>ut", vim.cmd.UndotreeToggle },
        },
    },
    {
        "vim-test/vim-test",
        keys = {
            { "<leader>tt", "<cmd>TestNearest -strategy=neovim<cr>", silent = true },
            { "<leader>tf", "<cmd>TestFile -strategy=neovim<cr>", silent = true },
            { "<leader>ta", "<cmd>TestSuite<cr>", silent = true },
        },
    },
}
