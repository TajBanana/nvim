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
        -- Plugin defaults only: (), [], {}, quotes and backticks.
        --
        -- `<` is deliberately NOT paired. autoclose.nvim ships no `<` entry, and
        -- adding one pairs it by *filetype*, never by context — so it cannot tell
        -- an HTML tag from `a <= b` or `List<String>` and inserts a stray `>` in
        -- every comparison and generic. Angle brackets are closed by hand. Do not
        -- re-add a `keys = { ["<"] = ... }` block here.
        --
        -- The default `[">"]` entry stays: it only escapes over an existing `>`,
        -- it never opens a pair.
        opts = {},
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
            { "<leader>ta", "<cmd>TestSuite -strategy=neovim<cr>", silent = true, desc = "Test suite" },
        },
    },
}
