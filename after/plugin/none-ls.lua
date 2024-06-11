local null_ls = require("null-ls")

null_ls.setup {
    sources = {
        null_ls.builtins.formatting.stylua,
        null_ls.builtins.completion.spell,
        require("none-ls.code_actions.eslint"),
        require("none-ls.diagnostics.eslint_d"),
    }
}

vim.keymap.set("n", "<leader>gf", vim.lsp.buf.format, {})

