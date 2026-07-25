return {
    {
        "neovim/nvim-lspconfig",
        event = "BufReadPre",
        dependencies = {
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
            "hrsh7th/cmp-nvim-lsp",
        },
        config = function()
            local capabilities = require("cmp_nvim_lsp").default_capabilities()

            require("mason").setup()
            require("mason-lspconfig").setup({
                ensure_installed = {
                    "ts_ls",
                    "lua_ls",
                    "jdtls",
                    "eslint",
                    "jsonls",
                    "tailwindcss",
                    "yamlls",
                    "kotlin_lsp",
                    "dockerls",
                    "cssls",
                    "graphql",
                    "html",
                    "pyright",
                    "gopls",
                    "bashls",
                    "rust_analyzer",
                    "helm_ls",
                },
                -- kotlin_lsp is enabled by kotlin.nvim instead
                automatic_enable = { exclude = { "kotlin_lsp" } },
            })

            -- Set capabilities for all servers via wildcard
            vim.lsp.config("*", {
                capabilities = capabilities,
            })

            -- lua_ls with Neovim runtime settings
            vim.lsp.config("lua_ls", {
                settings = {
                    Lua = {
                        runtime = { version = "LuaJIT" },
                        workspace = {
                            checkThirdParty = false,
                            library = { vim.env.VIMRUNTIME },
                        },
                        hint = { enable = true }, -- inlay hints
                    },
                },
            })

            -- Inlay hints are OFF by default in most servers and must be opted
            -- into per-server (the LspAttach handler then turns them on for the
            -- buffer). rust_analyzer emits them without extra settings.
            local ts_inlay = {
                includeInlayParameterNameHints = "all",
                includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                includeInlayFunctionParameterTypeHints = true,
                includeInlayVariableTypeHints = true,
                includeInlayVariableTypeHintsWhenTypeMatchesName = false,
                includeInlayPropertyDeclarationTypeHints = true,
                includeInlayFunctionLikeReturnTypeHints = true,
                includeInlayEnumMemberValueHints = true,
            }
            vim.lsp.config("ts_ls", {
                settings = {
                    typescript = { inlayHints = ts_inlay },
                    javascript = { inlayHints = ts_inlay },
                },
            })

            vim.lsp.config("gopls", {
                settings = {
                    gopls = {
                        hints = {
                            assignVariableTypes = true,
                            compositeLiteralFields = true,
                            compositeLiteralTypes = true,
                            constantValues = true,
                            functionTypeParameters = true,
                            parameterNames = true,
                            rangeVariableTypes = true,
                        },
                    },
                },
            })

            vim.lsp.config("pyright", {
                settings = {
                    python = {
                        analysis = {
                            inlayHints = {
                                variableTypes = true,
                                functionReturnTypes = true,
                                callArgumentNames = true,
                            },
                        },
                    },
                },
            })

            -- Mason ships the kotlin-lsp binary as intellij-server; the
            -- bundled lspconfig default still uses the old kotlin-lsp name
            vim.lsp.config("kotlin_lsp", {
                cmd = { "intellij-server", "--stdio" },
            })

            -- Enable inlay hints once per buffer when a client supports them.
            -- The guard makes it idempotent so a later re-trigger never fights a
            -- manual <leader>ti toggle-off.
            local inlay_hinted = {}
            local function enable_inlay(client, buf)
                if not inlay_hinted[buf]
                    and vim.api.nvim_buf_is_valid(buf)
                    and client:supports_method("textDocument/inlayHint", buf)
                then
                    inlay_hinted[buf] = true
                    vim.lsp.inlay_hint.enable(true, { bufnr = buf })
                end
            end
            -- Buffer numbers are reused after a wipeout; clear the guard so a
            -- new file that lands on a recycled number still gets hints enabled.
            vim.api.nvim_create_autocmd("BufWipeout", {
                callback = function(ev)
                    inlay_hinted[ev.buf] = nil
                end,
            })

            -- jdtls registers the inlayHint capability dynamically and LATE
            -- (after its slow workspace init), so the LspAttach check below runs
            -- too early and misses it. Re-check on LspProgress (jdtls emits
            -- progress while indexing) and enable as soon as the capability lands.
            vim.api.nvim_create_autocmd("LspProgress", {
                callback = function(ev)
                    local client = vim.lsp.get_client_by_id(ev.data.client_id)
                    if not client then return end
                    for buf in pairs(client.attached_buffers or {}) do
                        enable_inlay(client, buf)
                    end
                end,
            })

            -- Keymaps on LspAttach
            vim.api.nvim_create_autocmd("LspAttach", {
                callback = function(ev)
                    -- kotlin-lsp only declares "." as a completion trigger, so
                    -- typing "@" never opens annotation completion; add it
                    local client = vim.lsp.get_client_by_id(ev.data.client_id)
                    if client and client.name == "kotlin_lsp" then
                        local cp = client.server_capabilities.completionProvider
                        if cp and cp.triggerCharacters and not vim.tbl_contains(cp.triggerCharacters, "@") then
                            table.insert(cp.triggerCharacters, "@")
                        end

                        -- kotlin-lsp stamps stale document versions on rename
                        -- edits (e.g. v27 while the buffer is at v35), so nvim
                        -- rejects them with "Buffer newer than edits"; strip
                        -- the version before applying
                        client.handlers["textDocument/rename"] = function(err, result)
                            if err then
                                vim.notify("Rename failed: " .. (err.message or ""), vim.log.levels.ERROR)
                                return
                            end
                            if not result then return end
                            for _, dc in ipairs(result.documentChanges or {}) do
                                local td = dc.textDocument
                                if td and td.version then
                                    -- nvim 0.12 requires a number here, so
                                    -- overwrite with the real buffer version
                                    local buf = vim.uri_to_bufnr(td.uri)
                                    td.version = vim.lsp.util.buf_versions[buf] or td.version
                                end
                            end
                            vim.lsp.util.apply_workspace_edit(result, client.offset_encoding)
                        end
                    end

                    -- Inlay hints (IntelliJ-style inline types/params). Enable
                    -- via the shared helper, which is idempotent and also covers
                    -- servers that register the capability late (jdtls, via the
                    -- LspProgress autocmd above). Toggle with <leader>ti.
                    if client then
                        enable_inlay(client, ev.buf)
                    end
                    local function toggle_inlay()
                        vim.lsp.inlay_hint.enable(
                            not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }),
                            { bufnr = ev.buf }
                        )
                    end

                    local function opts(desc)
                        return { buffer = ev.buf, remap = false, desc = desc }
                    end
                    vim.keymap.set("n", "<leader>ti", toggle_inlay, opts("Toggle inlay hints"))

                    -- One flat picker with every LSP location for the symbol under the
                    -- cursor, tagged by kind; type "def"/"type"/"impl"/"ref" to filter.
                    -- Extracted to tajbanana/definition_picker to keep this file declarative.
                    vim.keymap.set("n", "<leader>gd", require("tajbanana.definition_picker").open, opts("Go to def/type/impl/ref"))
                    vim.keymap.set("n", "<leader>gi", vim.lsp.buf.implementation, opts("Go to implementation"))
                    vim.keymap.set("n", "<leader>gr", function() require("telescope.builtin").lsp_references() end, opts("Go to references"))
                    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts("Hover docs"))
                    vim.keymap.set("n", "<leader>vws", vim.lsp.buf.workspace_symbol, opts("Workspace symbols"))
                    vim.keymap.set("n", "<leader>vd", vim.diagnostic.open_float, opts("Show diagnostic"))
                    vim.keymap.set("n", "]e", function() vim.diagnostic.jump({ count = 1 }) end, opts("Next diagnostic"))
                    vim.keymap.set("n", "[e", function() vim.diagnostic.jump({ count = -1 }) end, opts("Previous diagnostic"))
                    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts("Code action"))
                    vim.keymap.set({ "n", "v" }, "<M-CR>", vim.lsp.buf.code_action, opts("Code action"))
                    vim.keymap.set("n", "<leader>rf", vim.lsp.buf.rename, opts("Rename symbol"))
                    vim.keymap.set("i", "<C-h>", vim.lsp.buf.signature_help, opts("Signature help"))
                end,
            })

            -- Re-tint inlay hints per kind (type/parameter palette colors)
            require("tajbanana.inlay_tint").setup()

            -- Diagnostics
            vim.diagnostic.config({
                -- show the full message in a float (like hover) after ]e / [e
                -- (0.12 replaced the old `float = true` with an on_jump hook)
                jump = {
                    on_jump = function()
                        -- Show the diagnostic in a float, closed by any REAL
                        -- cursor movement. The stock close_events CursorMoved
                        -- can't be used directly: ghost CursorMoved events
                        -- (fired without actual movement, including by the
                        -- jump itself) kill the float instantly. So close
                        -- manually, comparing against the landing position.
                        local _, win = vim.diagnostic.open_float({
                            scope = "cursor",
                            focus = false,
                            close_events = {},
                        })
                        if not win then
                            return
                        end
                        local landing = vim.api.nvim_win_get_cursor(0)
                        local grp = vim.api.nvim_create_augroup("DiagJumpFloat", { clear = true })
                        vim.api.nvim_create_autocmd({ "CursorMoved", "InsertEnter", "BufLeave", "WinLeave" }, {
                            group = grp,
                            callback = function(ev)
                                if ev.event == "CursorMoved" then
                                    local p = vim.api.nvim_win_get_cursor(0)
                                    if p[1] == landing[1] and p[2] == landing[2] then
                                        return -- ghost event: cursor didn't actually move
                                    end
                                end
                                pcall(vim.api.nvim_win_close, win, false)
                                pcall(vim.api.nvim_del_augroup_by_id, grp)
                            end,
                        })
                    end,
                },
                virtual_text = true,
                signs = {
                    text = {
                        [vim.diagnostic.severity.ERROR] = "E",
                        [vim.diagnostic.severity.WARN] = "W",
                        [vim.diagnostic.severity.HINT] = "H",
                        [vim.diagnostic.severity.INFO] = "I",
                    },
                },
            })
        end,
    },
    {
        "hrsh7th/nvim-cmp",
        event = "InsertEnter",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            "L3MON4D3/LuaSnip",
            "saadparwaiz1/cmp_luasnip",
            "rafamadriz/friendly-snippets",
        },
        config = function()
            local cmp = require("cmp")
            local cmp_select = { behavior = cmp.SelectBehavior.Select }

            cmp.setup({
                snippet = {
                    expand = function(args)
                        require("luasnip").lsp_expand(args.body)
                    end,
                },
                window = {
                    -- newer cmp defers to vim.o.winborder (empty by default),
                    -- so the style must be explicit
                    completion = cmp.config.window.bordered({ border = "rounded" }),
                    documentation = cmp.config.window.bordered({ border = "rounded" }),
                },
                mapping = cmp.mapping.preset.insert({
                    ["<C-p>"] = cmp.mapping.select_prev_item(cmp_select),
                    ["<C-n>"] = cmp.mapping.select_next_item(cmp_select),
                    -- Tab: confirm completion, else jump to next snippet
                    -- placeholder, else literal tab
                    ["<Tab>"] = cmp.mapping(function(fallback)
                        local luasnip = require("luasnip")
                        if cmp.visible() then
                            cmp.confirm({ select = true })
                        elseif luasnip.locally_jumpable(1) then
                            luasnip.jump(1)
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                    ["<S-Tab>"] = cmp.mapping(function(fallback)
                        local luasnip = require("luasnip")
                        if luasnip.locally_jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                    ["<CR>"] = cmp.mapping.confirm({ select = false }),
                    ["<C-Space>"] = cmp.mapping.complete(),
                }),
                sources = cmp.config.sources({
                    { name = "nvim_lsp" },
                    { name = "luasnip" },
                }, {
                    { name = "buffer" },
                }),
            })

            require("luasnip.loaders.from_vscode").lazy_load()
        end,
    },
}
