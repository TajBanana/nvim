return {
    "stevearc/conform.nvim",
    keys = {
        { "<leader>gf", function()
            require("conform").format({ async = true, lsp_format = "fallback" })
        end, desc = "Format buffer" },
    },
    opts = {
        formatters_by_ft = {
            lua = { "stylua" },
            javascript = { "prettier" },
            javascriptreact = { "prettier" },
            typescript = { "prettier" },
            typescriptreact = { "prettier" },
            json = { "prettier" },
            -- nvim gives tsconfig.json / jsconfig.json / .eslintrc.json /
            -- devcontainer.json the `jsonc` filetype, not `json`. Without this
            -- entry those files fell through to the LSP fallback while their
            -- sibling package.json went through prettier, so <leader>gf produced
            -- two different styles inside one project.
            jsonc = { "prettier" },
            yaml = { "prettier" },
            css = { "prettier" },
            html = { "prettier" },
            kotlin = { "ktlint" },
        },
        formatters = {
            ktlint = {
                -- ktlint exits 1 when a file contains a violation it cannot
                -- auto-correct (`standard:no-wildcard-imports` is the common one --
                -- 62% of files in a real Kotlin repo), even though it has already
                -- written correctly formatted code to stdout. conform treats a
                -- non-zero exit as failure and throws the output away, so
                -- <leader>gf was a silent no-op on most Kotlin files. Accept 1.
                exit_codes = { 0, 1 },
            },
        },
    },
}
