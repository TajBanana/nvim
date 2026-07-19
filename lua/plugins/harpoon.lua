return {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope.nvim" },
    keys = {
        { "<leader>ha", function() require("harpoon"):list():add() end, desc = "Harpoon add file" },
        { "<leader>he", function() require("harpoon").ui:toggle_quick_menu(require("harpoon"):list()) end, desc = "Harpoon edit list" },
        { "<leader>h1", function() require("harpoon"):list():select(1) end, desc = "Harpoon file 1" },
        { "<leader>h2", function() require("harpoon"):list():select(2) end, desc = "Harpoon file 2" },
        { "<leader>h3", function() require("harpoon"):list():select(3) end, desc = "Harpoon file 3" },
        { "<leader>h4", function() require("harpoon"):list():select(4) end, desc = "Harpoon file 4" },
        { "<leader>[", function() require("harpoon"):list():prev() end, desc = "Harpoon previous" },
        { "<leader>]", function() require("harpoon"):list():next() end, desc = "Harpoon next" },
        { "<leader>hw", function()
            local harpoon = require("harpoon")
            local conf = require("telescope.config").values
            local file_paths = {}
            for _, item in ipairs(harpoon:list().items) do
                table.insert(file_paths, item.value)
            end
            require("telescope.pickers").new({}, {
                prompt_title = "Harpoon",
                finder = require("telescope.finders").new_table({ results = file_paths }),
                previewer = conf.file_previewer({}),
                sorter = conf.generic_sorter({}),
            }):find()
        end, desc = "Open harpoon window" },
    },
    config = function()
        require("harpoon"):setup()
    end,
}
