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
                    },
                },
            })

            -- Mason ships the kotlin-lsp binary as intellij-server; the
            -- bundled lspconfig default still uses the old kotlin-lsp name
            vim.lsp.config("kotlin_lsp", {
                cmd = { "intellij-server", "--stdio" },
            })

            -- Keymaps on LspAttach
            vim.api.nvim_create_autocmd("LspAttach", {
                callback = function(ev)
                    local opts = { buffer = ev.buf, remap = false }

                    -- One flat picker with every LSP location for the symbol,
                    -- tagged by kind; type "def"/"impl"/"ref" to filter
                    vim.keymap.set("n", "<leader>gd", function()
                        local bufnr = vim.api.nvim_get_current_buf()
                        local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/definition" })
                        if #clients == 0 then
                            vim.notify("No LSP client supporting definitions", vim.log.levels.WARN)
                            return
                        end
                        local methods = {
                            { kind = "def",  rank = 1, method = "textDocument/definition" },
                            { kind = "type", rank = 2, method = "textDocument/typeDefinition" },
                            { kind = "impl", rank = 3, method = "textDocument/implementation" },
                            { kind = "ref",  rank = 4, method = "textDocument/references" },
                        }
                        -- query every capable client and merge (a tsx buffer has
                        -- several attached; only ts_ls knows the answer)
                        local jobs = {}
                        for _, client in ipairs(clients) do
                            for _, m in ipairs(methods) do
                                if client:supports_method(m.method, bufnr) then
                                    table.insert(jobs, { client = client, m = m })
                                end
                            end
                        end
                        local remaining, items, seen = #jobs, {}, {}
                        local function open_picker()
                            if #items == 0 then
                                vim.notify("No locations found", vim.log.levels.INFO)
                                return
                            end
                            table.sort(items, function(a, b)
                                if a.rank ~= b.rank then return a.rank < b.rank end
                                if a.filename ~= b.filename then return a.filename < b.filename end
                                return a.lnum < b.lnum
                            end)
                            local pickers = require("telescope.pickers")
                            local finders = require("telescope.finders")
                            local conf = require("telescope.config").values
                            local displayer = require("telescope.pickers.entry_display").create({
                                separator = " ",
                                items = {
                                    { width = 6 },
                                    { width = 35 },
                                    { remaining = true },
                                },
                            })
                            local kind_hl = { def = "GdTagDef", type = "GdTagType", impl = "GdTagImpl", ref = "GdTagRef" }
                            pickers.new({}, {
                                prompt_title = "Go to: def / type / impl / ref",
                                finder = finders.new_table({
                                    results = items,
                                    entry_maker = function(it)
                                        local tail = vim.fn.fnamemodify(it.filename, ":t") .. ":" .. it.lnum
                                        return {
                                            value = it,
                                            ordinal = it.kind .. " " .. tail .. " " .. it.text,
                                            display = function()
                                                return displayer({
                                                    { "[" .. it.kind .. "]", kind_hl[it.kind] },
                                                    tail,
                                                    it.text,
                                                })
                                            end,
                                            filename = it.filename,
                                            lnum = it.lnum,
                                            col = it.col,
                                        }
                                    end,
                                }),
                                previewer = conf.qflist_previewer({}),
                                sorter = conf.generic_sorter({}),
                            }):find()
                        end
                        for _, job in ipairs(jobs) do
                            local enc = job.client.offset_encoding
                            local params = vim.lsp.util.make_position_params(0, enc)
                            if job.m.method == "textDocument/references" then
                                params.context = { includeDeclaration = false }
                            end
                            local ok = job.client:request(job.m.method, params, function(_, result)
                                local locs = result or {}
                                if not vim.islist(locs) then locs = { locs } end
                                for _, it in ipairs(vim.lsp.util.locations_to_items(locs, enc)) do
                                    local key = it.filename .. ":" .. it.lnum .. ":" .. it.col
                                    if not seen[key] then
                                        seen[key] = true
                                        it.rank = job.m.rank
                                        it.kind = job.m.kind
                                        it.text = vim.trim(it.text or "")
                                        table.insert(items, it)
                                    end
                                end
                                remaining = remaining - 1
                                if remaining == 0 then open_picker() end
                            end, bufnr)
                            if not ok then
                                remaining = remaining - 1
                                if remaining == 0 then open_picker() end
                            end
                        end
                    end, opts)
                    vim.keymap.set("n", "<leader>gi", vim.lsp.buf.implementation, opts)
                    vim.keymap.set("n", "<leader>gr", function() require("telescope.builtin").lsp_references() end, opts)
                    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
                    vim.keymap.set("n", "<leader>vws", vim.lsp.buf.workspace_symbol, opts)
                    vim.keymap.set("n", "<leader>vd", vim.diagnostic.open_float, opts)
                    vim.keymap.set("n", "]e", function() vim.diagnostic.jump({ count = 1 }) end, opts)
                    vim.keymap.set("n", "[e", function() vim.diagnostic.jump({ count = -1 }) end, opts)
                    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
                    vim.keymap.set("n", "<leader>rf", vim.lsp.buf.rename, opts)
                    vim.keymap.set("i", "<C-h>", vim.lsp.buf.signature_help, opts)
                end,
            })

            -- Diagnostics
            vim.diagnostic.config({
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
                    completion = cmp.config.window.bordered(),
                    documentation = cmp.config.window.bordered(),
                },
                mapping = cmp.mapping.preset.insert({
                    ["<C-p>"] = cmp.mapping.select_prev_item(cmp_select),
                    ["<C-n>"] = cmp.mapping.select_next_item(cmp_select),
                    ["<Tab>"] = cmp.mapping.confirm({ select = true }),
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
