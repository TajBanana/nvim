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
            -- kotlin-lsp (v261+; this machine runs 263) only emits inlay hints
            -- when told to via the workspace/configuration handshake kotlin.nvim
            -- serves from these opts. Without inlay_hints the settings block in
            -- kotlin.nvim is skipped and the server returns zero hints.
            inlay_hints = { enabled = true },
        })

        -- :KotlinLspUpdate -- the one-command answer to the ~monthly EAP expiry.
        -- It runs scripts/update-kotlin-lsp.sh (discovers the newest build via the
        -- Open VSX kotlin-server extension, downloads + sha256-verifies it, and
        -- repoints ~/.local/share/kotlin-lsp/current), then reattaches. The script
        -- is idempotent, so running it when already current is a harmless no-op.
        -- Run this when the statusline shows ⏱.
        vim.api.nvim_create_user_command("KotlinLspUpdate", function()
            local script = vim.fn.stdpath("config") .. "/scripts/update-kotlin-lsp.sh"
            if vim.fn.filereadable(script) == 0 then
                vim.notify("KotlinLspUpdate: missing " .. script, vim.log.levels.ERROR)
                return
            end
            vim.notify("kotlin-lsp: checking for a newer build…", vim.log.levels.INFO, { title = "KotlinLspUpdate" })
            vim.system({ "bash", script }, { text = true }, function(res)
                vim.schedule(function()
                    if res.code ~= 0 then
                        vim.notify(
                            "kotlin-lsp update failed:\n" .. vim.trim((res.stdout or "") .. (res.stderr or "")),
                            vim.log.levels.ERROR,
                            { title = "KotlinLspUpdate" }
                        )
                        return
                    end
                    local build = (res.stdout or ""):match("kotlin%-server%-([%w.]+)") or "?"
                    -- Point the resolver at the (now-present) self-managed dir, in
                    -- case it did not exist when this config first ran.
                    local cur = vim.fn.expand("~/.local/share/kotlin-lsp/current")
                    if vim.uv.fs_stat(cur) then
                        vim.env.KOTLIN_LSP_DIR = cur
                    end
                    if (res.stdout or ""):match("UP%-TO%-DATE") then
                        vim.notify(
                            "kotlin-lsp already current (" .. build .. ")",
                            vim.log.levels.INFO,
                            { title = "KotlinLspUpdate" }
                        )
                        return
                    end
                    -- Updated: clear the expiry flag and reattach on Kotlin buffers.
                    pcall(function()
                        require("tajbanana.lsp_status")._expired_kotlin = false
                    end)
                    for _, c in ipairs(vim.lsp.get_clients({ name = "kotlin_lsp" })) do
                        c:stop()
                    end
                    -- Defer the reattach so the stopped server releases its
                    -- machine-wide analyzer lock before the new one starts.
                    vim.defer_fn(function()
                        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                            if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "kotlin" then
                                vim.api.nvim_exec_autocmds("FileType", { buffer = buf, modeline = false })
                            end
                        end
                    end, 1500)
                    vim.notify(
                        "kotlin-lsp updated to " .. build .. " — reattaching (restart nvim if it doesn't).",
                        vim.log.levels.INFO,
                        { title = "KotlinLspUpdate" }
                    )
                end)
            end)
        end, { desc = "Update self-managed kotlin-lsp to the latest build and reattach" })
    end,
}
