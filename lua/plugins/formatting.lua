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
            yaml = { "prettier" },
            css = { "prettier" },
            html = { "prettier" },
        },
    },
}
