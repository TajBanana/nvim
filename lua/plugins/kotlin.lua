return {
    "AlexandrosAlexiou/kotlin.nvim",
    ft = { "kotlin" },
    dependencies = {
        "mason-org/mason.nvim",
        "mason-org/mason-lspconfig.nvim",
        "folke/trouble.nvim",
    },
    config = function()
        -- Self-managed kotlin-lsp. The JetBrains intellij-server is a time-bombed
        -- EAP build that expires ~monthly, and Mason's registry trails JetBrains
        -- by weeks (frequently only able to reinstall an already-expired build),
        -- so it is kept OUT of mason's ensure_installed. Instead the current build
        -- lives at ~/.local/share/kotlin-lsp/current (a symlink to the versioned
        -- dir); on each expiry, drop in the new build and repoint the symlink --
        -- no config change. kotlin.nvim probes $MASON first and only falls back to
        -- KOTLIN_LSP_DIR, so this stays a no-op on any machine that still installs
        -- kotlin-lsp through Mason. Guarded on existence so the resolver is never
        -- handed a dead path.
        local self_managed = vim.fn.expand("~/.local/share/kotlin-lsp/current")
        if vim.uv.fs_stat(self_managed) then
            vim.env.KOTLIN_LSP_DIR = self_managed
        end

        require("kotlin").setup({
            -- kotlin-lsp (v261+; this machine runs 262) only emits inlay hints
            -- when told to via the workspace/configuration handshake kotlin.nvim
            -- serves from these opts. Without inlay_hints the settings block in
            -- kotlin.nvim is skipped and the server returns zero hints.
            inlay_hints = { enabled = true },
        })
    end,
}
