return {
    "nvim-telescope/telescope.nvim",
    branch = "master",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
        { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
        "nvim-telescope/telescope-ui-select.nvim",
    },
    keys = {
        { "<C-p>", function() require("telescope.builtin").git_files() end, desc = "Find git files" },
        { "<leader>ff", function() require("telescope.builtin").find_files() end, desc = "Find files" },
        { "<leader>fw", function() require("telescope.builtin").live_grep() end, desc = "Live grep" },
        { "<leader>gb", "<cmd>Telescope git_branches<cr>", desc = "Git branches" },
    },
    config = function()
        require("telescope").setup({
            defaults = {
                path_display = { "filename_first" },
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
        require("telescope").load_extension("fzf")
        require("telescope").load_extension("ui-select")
    end,
}
