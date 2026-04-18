return {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.5",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
        { "<C-p>", function() require("telescope.builtin").git_files() end },
        { "<leader>ff", function() require("telescope.builtin").find_files() end },
        { "<leader>fw", function()
            require("telescope.builtin").grep_string({ search = vim.fn.input("Grep > ") })
        end },
        { "<leader>gb", "<cmd>Telescope git_branches<cr>" },
    },
    config = function()
        require("telescope").setup({
            defaults = {
                file_ignore_patterns = {
                    ".git/",
                    ".idea/",
                    ".vscode/",
                    ".gitlab/",
                },
            },
            pickers = {
                find_files = {
                    hidden = true,
                },
            },
        })
    end,
}
