return {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = "BufReadPost",
    config = function()
        require("nvim-treesitter.configs").setup({
            ensure_installed = {
                "javascript",
                "typescript",
                "java",
                "kotlin",
                "lua",
                "vim",
                "vimdoc",
                "query",
                "sql",
                "dockerfile",
                "css",
                "html",
                "yaml",
                "graphql",
                "json",
            },
            sync_install = false,
            auto_install = true,
            highlight = {
                enable = true,
                additional_vim_regex_highlighting = false,
            },
        })
    end,
}
