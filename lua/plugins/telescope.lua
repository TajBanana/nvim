return {
    "nvim-telescope/telescope.nvim",
    branch = "master",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
        { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
        "nvim-telescope/telescope-ui-select.nvim",
        "debugloop/telescope-undo.nvim",
    },
    keys = {
        { "<C-p>", function() require("telescope.builtin").git_files() end, desc = "Find git files" },
        { "<leader>ff", function() require("telescope.builtin").find_files() end, desc = "Find files" },
        { "<leader>fw", function() require("telescope.builtin").live_grep() end, desc = "Live grep" },
        {
            "<leader>fb",
            function()
                require("telescope.builtin").buffers({
                    sort_mru = true,
                    initial_mode = "normal",
                    attach_mappings = function(_, map)
                        local delete = require("telescope.actions").delete_buffer
                        -- dd (normal mode, the default here) deletes the
                        -- highlighted buffer, vim-style; Alt-d does the same
                        -- while typing a filter in insert mode. Ctrl-d/Ctrl-u
                        -- keep their default preview-scroll behaviour.
                        map("n", "dd", delete)
                        map("i", "<M-d>", delete)
                        return true
                    end,
                })
            end,
            desc = "Open buffers",
        },
        { "<leader>xx", function() require("telescope.builtin").diagnostics() end, desc = "Diagnostics (workspace)" },
        { "<leader>xb", function() require("telescope.builtin").diagnostics({ bufnr = 0 }) end, desc = "Diagnostics (buffer)" },
        { "<leader>xr", function() require("tajbanana.repo_diagnostics").run() end, desc = "Diagnostics (repo lint)" },
        { "<leader>uu", function() require("telescope").extensions.undo.undo() end, desc = "Undo history (Telescope)" },
    },
    config = function()
        require("telescope").setup({
            defaults = {
                path_display = { "filename_first" },
                -- Escaped Lua patterns: a bare "." is a wildcard, so ".git/"
                -- would also hide dirs like "digit/" or "myidea/". "%." matches a
                -- literal dot, and "$" is unnecessary — these anchor on the path
                -- segment as intended.
                file_ignore_patterns = {
                    "%.git/",
                    "%.idea/",
                    "%.vscode/",
                    "%.gitlab/",
                },
            },
            pickers = {
                find_files = {
                    hidden = true,
                },
            },
            extensions = {
                undo = {
                    -- narrow the results column so the diff preview gets more room
                    layout_config = { preview_width = 0.7 },
                },
            },
        })
        require("telescope").load_extension("fzf")
        require("telescope").load_extension("ui-select")
        require("telescope").load_extension("undo")
    end,
}
