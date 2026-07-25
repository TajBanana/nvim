return {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    config = function()
        require("nvim-treesitter").setup()

        local parsers = {
            "javascript",
            "typescript",
            "tsx",
            "java",
            "kotlin",
            "scala",
            "groovy", -- also colours *.gradle (filetype groovy)
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
            "xml",        -- also *.iml, via the set.lua filetype rule
            "toml",
            "properties", -- registered onto the jproperties filetype below
            "python",
            "go",
            "bash",
            "rust",
            "markdown",
            "markdown_inline", -- render-markdown.nvim needs both markdown + inline
            "gotmpl",
            "helm",
        }

        -- nvim assigns *.properties the "jproperties" filetype, but the parser
        -- is named "properties" — map them so treesitter.start finds it.
        vim.treesitter.language.register("properties", "jproperties")

        -- The main branch no longer starts highlighting automatically;
        -- attach treesitter to every buffer that has a parser
        vim.api.nvim_create_autocmd("FileType", {
            callback = function(args)
                pcall(vim.treesitter.start, args.buf)
            end,
        })

        -- Auto-install missing parsers
        vim.api.nvim_create_autocmd("VimEnter", {
            callback = function()
                local installed = require("nvim-treesitter").get_installed()
                local to_install = {}
                for _, parser in ipairs(parsers) do
                    if not vim.tbl_contains(installed, parser) then
                        table.insert(to_install, parser)
                    end
                end
                if #to_install > 0 then
                    vim.cmd("TSInstall " .. table.concat(to_install, " "))
                end
            end,
        })
    end,
}
