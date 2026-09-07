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
        -- Download progress (phases + curl's byte %) streams to a fidget bar.
        -- Run this when the statusline shows ⏱.
        vim.api.nvim_create_user_command("KotlinLspUpdate", function()
            local script = vim.fn.stdpath("config") .. "/scripts/update-kotlin-lsp.sh"
            if vim.fn.filereadable(script) == 0 then
                vim.notify("KotlinLspUpdate: missing " .. script, vim.log.levels.ERROR)
                return
            end
            -- Progress via fidget. It lazy-loads on LspAttach, which may not have
            -- happened when the server is dead/expired, so force it loaded first;
            -- fall back to plain notifications if it is somehow unavailable.
            pcall(function()
                require("lazy").load({ plugins = { "fidget.nvim" } })
            end)
            local ok_fidget, fidget = pcall(require, "fidget.progress")
            local handle
            if ok_fidget then
                handle = fidget.handle.create({
                    title = "kotlin-lsp",
                    message = "checking for a newer build…",
                    lsp_client = { name = "kotlin-lsp update" },
                    percentage = 0,
                })
            else
                vim.notify("kotlin-lsp: checking for a newer build…", vim.log.levels.INFO, { title = "KotlinLspUpdate" })
            end

            local out_chunks, err_chunks = {}, {}
            local last_pct = -1
            local function report(props)
                vim.schedule(function()
                    if handle then
                        handle:report(props)
                    end
                end)
            end

            vim.system({ "bash", script }, {
                text = true,
                -- The script prints "· downloading/verifying/extracting" phase lines
                -- to stdout; curl --progress-bar writes "…  42.1%" to stderr.
                stdout = function(_, data)
                    if not data then
                        return
                    end
                    out_chunks[#out_chunks + 1] = data
                    for line in data:gmatch("[^\r\n]+") do
                        local phase = line:match("^·%s+(%a+)")
                        if phase then
                            report({ message = phase .. "…" })
                        end
                    end
                end,
                stderr = function(_, data)
                    if not data then
                        return
                    end
                    err_chunks[#err_chunks + 1] = data
                    local latest
                    for pct in data:gmatch("(%d+%.?%d*)%%") do
                        latest = pct
                    end
                    if latest then
                        local p = math.floor(tonumber(latest) + 0.5)
                        if p ~= last_pct then
                            last_pct = p
                            report({ message = "downloading…", percentage = p })
                        end
                    end
                end,
            }, function(res)
                local out = table.concat(out_chunks)
                vim.schedule(function()
                    if res.code ~= 0 then
                        if handle then
                            handle:cancel()
                        end
                        local err = vim.trim(out .. "\n" .. table.concat(err_chunks))
                        vim.notify(
                            "kotlin-lsp update failed:\n" .. err:sub(-800),
                            vim.log.levels.ERROR,
                            { title = "KotlinLspUpdate" }
                        )
                        return
                    end
                    local build = out:match("kotlin%-server%-([%w.]+)") or "?"
                    -- Point the resolver at the (now-present) self-managed dir, in
                    -- case it did not exist when this config first ran.
                    local cur = vim.fn.expand("~/.local/share/kotlin-lsp/current")
                    if vim.uv.fs_stat(cur) then
                        vim.env.KOTLIN_LSP_DIR = cur
                    end
                    local function finish(msg)
                        if handle then
                            handle:report({ message = msg, percentage = 100 })
                            handle:finish()
                        else
                            vim.notify("kotlin-lsp: " .. msg, vim.log.levels.INFO, { title = "KotlinLspUpdate" })
                        end
                    end
                    if out:match("UP%-TO%-DATE") then
                        finish("already current (" .. build .. ")")
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
                    finish("updated to " .. build .. " — reattaching")
                end)
            end)
        end, { desc = "Update self-managed kotlin-lsp to the latest build and reattach" })
    end,
}
