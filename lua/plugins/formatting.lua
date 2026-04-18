return {
    "stevearc/conform.nvim",
    keys = {
        { "<leader>gf", function()
            require("conform").format({ async = true, lsp_fallback = true })
        end },
    },
    opts = {
        formatters_by_ft = {
            lua = { "stylua" },
        },
    },
}
