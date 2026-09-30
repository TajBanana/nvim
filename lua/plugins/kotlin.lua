return {
    "AlexandrosAlexiou/kotlin.nvim",
    ft = { "kotlin" },
    -- The commands are defined in config below, so without this they did not
    -- exist until a .kt buffer loaded the plugin -- including on a fresh machine,
    -- where :KotlinLspUpdate is exactly what performs the first install.
    cmd = { "KotlinLspUpdate", "KotlinLspRollback" },
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
        -- kotlin-lsp through Mason.
        --
        -- KOTLIN_LSP_DIR is the `current` SYMLINK path (not the build it
        -- resolves to), so every launch -- in this and every other Neovim --
        -- follows whatever `current` points at when the server starts, and an
        -- update or rollback is picked up by the next start.
        -- History (2026-09-29): this was briefly changed to the resolved
        -- versioned directory, so the updater could see from process command
        -- lines which builds were in use. That regressed: Neovim's own FileType
        -- handler starts the server from the command kotlin.nvim configured on
        -- the PREVIOUS launch, so after an update or rollback the old build was
        -- relaunched. Reverted; the updater instead prunes nothing while any
        -- server started through `current` is running.
        -- Set even while `current` dangles (lstat, not stat), so repairing the
        -- link needs no editor restart; a KOTLIN_LSP_DIR exported by the user
        -- is left alone, and nothing is set without a self-managed install.
        -- (kotlin_update.point_at_current is called again after an update, so a
        -- first install -- no `current` yet at load -- attaches without a restart.)
        require("tajbanana.kotlin_update").point_at_current()

        require("kotlin").setup({
            -- kotlin-lsp (v261+; this machine runs 263) only emits inlay hints
            -- when told to via the workspace/configuration handshake kotlin.nvim
            -- serves from these opts. Without inlay_hints the settings block in
            -- kotlin.nvim is skipped and the server returns zero hints.
            inlay_hints = { enabled = true },
        })

        -- GitHub first; an expired GitHub build offers a separately confirmed
        -- Open VSX download. Progress, retries, and overlap guards live here.
        vim.api.nvim_create_user_command("KotlinLspUpdate", function()
            require("tajbanana.kotlin_update").start()
        end, { desc = "Update Kotlin LSP with confirmed Open VSX fallback" })
        vim.api.nvim_create_user_command("KotlinLspRollback", function()
            require("tajbanana.kotlin_update").rollback()
        end, { desc = "Roll Kotlin LSP back to the previous build" })
    end,
}
