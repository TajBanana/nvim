return {
    {
        "neovim/nvim-lspconfig",
        -- Loaded eagerly rather than on BufReadPre. BufReadPre only fires for
        -- files that already exist, so a brand-new file used to get no client, no
        -- completion and none of the LspAttach keymaps. Adding BufNewFile to the
        -- lazy event list is NOT a valid fix: lazy suppresses events while it
        -- loads a plugin, which swallows the FileType event that same BufNewFile
        -- would have triggered, leaving new buffers with no filetype at all.
        -- Loading at startup sidesteps the event-interception problem entirely.
        lazy = false,
        dependencies = {
            "mason-org/mason.nvim",
            "mason-org/mason-lspconfig.nvim",
            "hrsh7th/cmp-nvim-lsp",
        },
        config = function()
            local capabilities = require("cmp_nvim_lsp").default_capabilities()

            require("mason").setup()

            local servers = {
                "ts_ls",
                "lua_ls",
                "jdtls",
                "eslint",
                "jsonls",
                "tailwindcss", -- root gated below: Tailwind projects only
                "yamlls",
                -- kotlin_lsp is intentionally NOT listed: the JetBrains
                -- intellij-server ships as a time-bombed EAP build that expires
                -- ~monthly, and Mason's registry trails JetBrains by weeks -- often
                -- it can only reinstall an already-expired build. It is
                -- self-managed instead (see kotlin.lua's KOTLIN_LSP_DIR);
                -- kotlin.nvim enables it, and the statusline shows a ⏱ when the
                -- build has expired.
                "dockerls",
                "cssls",
                "graphql",
                "html",
                "pyright",
                "gopls",
                "bashls",
                "rust_analyzer",
                "helm_ls",
            }

            -- automatic_enable is an ALLOW-list: only the servers above are ever
            -- enabled. The default (every Mason package lspconfig recognises)
            -- attached whatever else happened to be installed -- leftover
            -- emmet_ls/gradle_ls/sqlls from :Mason experiments, and the stylua
            -- FORMATTER (installed for conform) whose lspconfig `lsp/stylua.lua`
            -- wrapper spawned `stylua --lsp` as a second formatting provider on
            -- every Lua buffer. An exclude list had to chase each of those.
            --
            -- rust_analyzer is dropped without a toolchain: its upstream root_dir
            -- calls `rustc` to locate the sysroot WITHOUT checking it exists, and
            -- the ENOENT inside the FileType callback aborts the rest of that
            -- buffer's FileType chain -- a traceback on every .rs file and, since
            -- treesitter's hook never runs, completely unhighlighted Rust.
            --
            -- ensure_installed skips a server Mason would have to BUILD with a
            -- toolchain this machine lacks (npm for ts_ls/pyright/bashls/...,
            -- go for gopls, python3 for pypi, cargo for crates): the install
            -- failed and was retried on every start. Read from the package's
            -- Mason source id, so no hand-kept list goes stale; an already
            -- installed server is kept. gopls is also not ENABLED without Go --
            -- it cannot work without a Go toolchain.
            local toolchain = { npm = "npm", golang = "go", pypi = "python3", cargo = "cargo" }
            -- Fallback for a FIRST start on a fresh machine, before Mason has
            -- downloaded its registry (get_package then fails, and the gate
            -- used to let everything through): the source kind of each
            -- configured server that needs a toolchain, as of 2026-09. Its npm
            -- entries are mirrored by lsp_status.lua's NPM_SERVERS (the statusline
            -- stops expecting them without npm).
            local known_kind = {
                gopls = "golang",
                ts_ls = "npm", eslint = "npm", jsonls = "npm", tailwindcss = "npm", yamlls = "npm",
                dockerls = "npm", cssls = "npm", graphql = "npm", html = "npm", pyright = "npm", bashls = "npm",
            }
            local function installable(server)
                local ok, map = pcall(function()
                    return require("mason-lspconfig").get_mappings().lspconfig_to_package
                end)
                local ok_reg, registry = pcall(require, "mason-registry")
                local pkg_name = ok and map[server]
                if ok_reg and pkg_name and registry.is_installed(pkg_name) then
                    return true
                end
                local ok_pkg, pkg = false, nil
                if ok_reg and pkg_name then
                    ok_pkg, pkg = pcall(registry.get_package, pkg_name)
                end
                local kind = ok_pkg and pkg.spec.source.id:match("^pkg:(%w+)/") or known_kind[server]
                local bin = kind and toolchain[kind]
                return not bin or vim.fn.executable(bin) == 1
            end
            local has_rust = vim.fn.executable("rustc") == 1 and vim.fn.executable("cargo") == 1
            local has_go = vim.fn.executable("go") == 1
            local installed = vim.tbl_filter(installable, servers)
            local enabled = vim.tbl_filter(function(name)
                return (name ~= "rust_analyzer" or has_rust) and (name ~= "gopls" or has_go)
            end, servers)

            require("mason-lspconfig").setup({
                ensure_installed = installed,
                automatic_enable = enabled,
            })

            -- tailwindcss only in actual Tailwind projects: upstream's root_dir
            -- falls back to a bare `.git`, which spawned the server for every
            -- README in every repo. See tajbanana/tailwind_root.lua; with no
            -- Tailwind marker on_dir is never called and it does not start.
            vim.lsp.config("tailwindcss", {
                root_dir = function(bufnr, on_dir)
                    local fname = vim.api.nvim_buf_get_name(bufnr)
                    local root = fname ~= "" and require("tajbanana.tailwind_root").find(fname)
                    if root then
                        on_dir(root)
                    end
                end,
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
            -- Captured BEFORE the vim.lsp.config("ts_ls", ...) call below replaces
            -- it: reading vim.lsp.config.ts_ls resolves nvim-lspconfig's own
            -- `lsp/ts_ls.lua`, so the @flow veto can be layered ON TOP of upstream
            -- instead of replacing it.
            local upstream_ts_root_dir = (vim.lsp.config.ts_ls or {}).root_dir
            vim.lsp.config("ts_ls", {
                -- Flow-typed .js is NOT TypeScript. ts_ls attaches to it happily
                -- and then reports every type annotation as a syntax error
                -- (measured: 1747 diagnostics on one React source file, 1537 of
                -- them severity-1, e.g. TS8006 "'import type' declarations can
                -- only be used in TypeScript files"). React and friends generate
                -- their .flowconfig at build time, so there is no checked-in
                -- marker to key off -- but the files themselves carry an `@flow`
                -- pragma in the header comment.
                --
                -- The veto has to happen in root_dir: it is the only hook nvim
                -- calls PER BUFFER before starting a client, so simply not
                -- calling on_dir() prevents the attach outright. (Detaching later
                -- from LspAttach does not work -- buf_detach_client leaves the
                -- client attached, and clearing the diagnostics only hides them
                -- until the next publish.)
                -- Delegating matters: the previous version reimplemented root
                -- resolution wholesale and silently dropped three upstream
                -- behaviours:
                --   * the Deno veto (deno.json/deno.lock closer than the package
                --     lock => do not attach), so ts_ls attached to Deno sources
                --     and flooded them with resolution errors;
                --   * rooting on the package-manager LOCK file, which is what
                --     makes a monorepo share ONE tsserver -- rooting on the
                --     nearest package.json spawns one per package;
                --   * the `or vim.fn.getcwd()` fallback, so a standalone
                --     /tmp/scratch.ts with no markers above it got no ts_ls at
                --     all: no completion, and no LspAttach keymaps.
                root_dir = function(bufnr, on_dir)
                    -- .jsx maps to `javascriptreact`, which is in ts_ls's
                    -- filetypes -- testing only "javascript" let Flow-typed .jsx
                    -- through and it still drew the 1747-diagnostic storm this
                    -- veto exists to stop.
                    local ft = vim.bo[bufnr].filetype
                    if ft == "javascript" or ft == "javascriptreact" then
                        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 40, false)
                        if require("tajbanana.flow_pragma").has_pragma(lines) then
                            return -- no on_dir() => no ts_ls for this buffer
                        end
                    end
                    if upstream_ts_root_dir then
                        return upstream_ts_root_dir(bufnr, on_dir)
                    end
                    -- Only reached if lspconfig ever stops shipping ts_ls.
                    on_dir(vim.fs.root(bufnr, {
                        "package-lock.json",
                        "yarn.lock",
                        "pnpm-lock.yaml",
                        "tsconfig.json",
                        "package.json",
                        ".git",
                    }) or vim.fn.getcwd())
                end,
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

            -- One augroup for every autocmd this config function registers, so
            -- re-sourcing the config replaces the handlers instead of stacking a
            -- second (uncancellable) copy of each.
            local grp = vim.api.nvim_create_augroup("TajbananaLsp", { clear = true })

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
                group = grp,
                callback = function(ev)
                    inlay_hinted[ev.buf] = nil
                end,
            })

            -- jdtls registers the inlayHint capability dynamically and LATE
            -- (after its slow workspace init), so the LspAttach check below runs
            -- too early and misses it. Re-check on LspProgress (jdtls emits
            -- progress while indexing) and enable as soon as the capability lands.
            vim.api.nvim_create_autocmd("LspProgress", {
                group = grp,
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
                group = grp,
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
                        -- rejects them with "Buffer newer than edits";
                        -- overwrite each edit's version with the live buffer
                        -- version before applying (stripping it to nil crashed
                        -- nvim 0.12, which requires a number)
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
                    -- cursor, tagged by kind. It opens in normal mode: press `i`, then
                    -- type "def"/"type"/"impl"/"ref" to filter.
                    -- Extracted to tajbanana/definition_picker to keep this file declarative.
                    vim.keymap.set("n", "<leader>gd", require("tajbanana.definition_picker").open, opts("Go to def/type/impl/ref"))
                    -- Telescope like <leader>gr: a picker with preview instead of the
                    -- native quickfix dump; a single result still jumps directly.
                    vim.keymap.set("n", "<leader>gi", function() require("telescope.builtin").lsp_implementations() end, opts("Go to implementation"))
                    vim.keymap.set("n", "<leader>gr", function() require("telescope.builtin").lsp_references() end, opts("Go to references"))
                    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts("Hover docs"))
                    -- Live project-wide symbol search (IntelliJ Navigate -> Symbol):
                    -- re-queries the server as you type, instead of the native
                    -- blind `Query:` prompt followed by a quickfix list.
                    vim.keymap.set("n", "<leader>vws", function() require("telescope.builtin").lsp_dynamic_workspace_symbols() end, opts("Workspace symbols"))
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
                -- When several diagnostics share a line, nvim draws a marker for
                -- each but prints only ONE message. Unsorted it picks the last
                -- one, which is severity-blind: on `if (left < right) {}` kotlin
                -- reports two ERRORs (unresolved left/right) plus a WARN (empty
                -- body) all on that line, and the WARN's text was displayed --
                -- making the file look merely warned-about when it does not
                -- compile. Sorting puts the highest severity in the message slot.
                -- (Verified: false -> "if has empty body", true -> "Unresolved
                -- reference left". `{ reverse = true }` reverts to the warning.)
                severity_sort = true,
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
            -- Backs the { name = "buffer" } fallback source below. Without it the
            -- source is configured but never registered, so the word-from-buffer
            -- fallback silently did nothing.
            "hrsh7th/cmp-buffer",
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
                            if not cmp.confirm({ select = true }) then fallback() end
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
                    ["<CR>"] = cmp.mapping(function(fallback)
                        if not cmp.confirm({ select = false }) then fallback() end
                    end),
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
