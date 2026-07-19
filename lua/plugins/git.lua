return {
    {
        "tpope/vim-fugitive",
        cmd = "Git",
        keys = {
            { "<leader>gs", function() vim.cmd("vert Git") end, desc = "Git status (fugitive)" },
            { "<leader>dv", function() vim.cmd("Gvdiff") end, desc = "Diff file vs index" },
        },
    },
    {
        "lewis6991/gitsigns.nvim",
        event = "BufReadPre",
        opts = {
            on_attach = function(bufnr)
                local gitsigns = require("gitsigns")

                local function map(mode, l, r, opts)
                    opts = opts or {}
                    opts.buffer = bufnr
                    vim.keymap.set(mode, l, r, opts)
                end

                map("n", "<leader>pp", function()
                    if vim.wo.diff then
                        vim.cmd.normal({ "]c", bang = true })
                    else
                        gitsigns.nav_hunk("next")
                    end
                end, { desc = "Next git hunk" })

                map("n", "<leader>oo", function()
                    if vim.wo.diff then
                        vim.cmd.normal({ "[c", bang = true })
                    else
                        gitsigns.nav_hunk("prev")
                    end
                end, { desc = "Previous git hunk" })

                map("n", "<leader>gp", gitsigns.preview_hunk, { desc = "Preview git hunk" })
                map("n", "<leader>td", gitsigns.toggle_deleted, { desc = "Toggle deleted lines" })
                map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "Select git hunk" })
            end,
        },
    },
    {
        "f-person/git-blame.nvim",
        event = "BufReadPre",
    },
    {
        "kdheepak/lazygit.nvim",
        cmd = "LazyGit",
        dependencies = { "nvim-lua/plenary.nvim" },
        keys = {
            { "<leader>lg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
        },
    },
}
