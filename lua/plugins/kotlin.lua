return {
    "AlexandrosAlexiou/kotlin.nvim",
    ft = { "kotlin" },
    dependencies = {
        "mason-org/mason.nvim",
        "mason-org/mason-lspconfig.nvim",
        "folke/trouble.nvim",
    },
    config = function()
        require("kotlin").setup({
            -- kotlin-lsp (v261+; this machine runs 262) only emits inlay hints
            -- when told to via the workspace/configuration handshake kotlin.nvim
            -- serves from these opts. Without inlay_hints the settings block in
            -- kotlin.nvim is skipped and the server returns zero hints.
            inlay_hints = { enabled = true },
        })
    end,
}
