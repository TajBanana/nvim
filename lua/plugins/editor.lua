return {
    -- BufNewFile as well as BufReadPre: `:e brand_new.kt` fires only BufNewFile,
    -- so a BufReadPre-only plugin never loaded in a new file (no ys/ds/cs). The
    -- lsp.lua warning against BufNewFile is specific to nvim-lspconfig, which
    -- must catch the buffer's own FileType; this only registers keymaps.
    {
        "kylechui/nvim-surround",
        version = "*",
        event = { "BufReadPre", "BufNewFile" },
        opts = {},
    },
    -- Commenting uses Neovim's built-in gc/gcc/gc{motion} (0.10+), which is
    -- treesitter-aware for embedded languages. Comment.nvim was dropped: its only
    -- extras were block comments (gb/gbc) and gco/gcO/gcA, which weren't used.
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
