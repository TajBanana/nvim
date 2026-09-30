return {
    {
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
                -- nvim gives tsconfig.json / jsconfig.json / .eslintrc.json /
                -- devcontainer.json the `jsonc` filetype, not `json`. Without this
                -- entry those files fell through to the LSP fallback while their
                -- sibling package.json went through prettier, so <leader>gf produced
                -- two different styles inside one project.
                jsonc = { "prettier" },
                yaml = { "prettier" },
                css = { "prettier" },
                html = { "prettier" },
                markdown = { "prettier" }, -- proseWrap defaults to "preserve": no re-wrapping
                kotlin = { "ktlint" },
                -- pyright has no formatting, so <leader>gf used to be a no-op on
                -- Python. Sort imports first, then format (ruff's isort + black).
                python = { "ruff_organize_imports", "ruff_format" },
                -- gopls formatting (the old LSP fallback) never adds or removes
                -- imports; goimports does, gofumpt is a stricter gofmt on top.
                go = { "goimports", "gofumpt" },
                -- bashls only formats when shfmt exists, so wire shfmt directly.
                sh = { "shfmt" },
                bash = { "shfmt" },
            },
            formatters = {
                ktlint = {
                    -- ktlint exits 1 when a file contains a violation it cannot
                    -- auto-correct (`standard:no-wildcard-imports` is the common one --
                    -- 62% of files in a real Kotlin repo), even though it has already
                    -- written correctly formatted code to stdout. conform treats a
                    -- non-zero exit as failure and throws the output away, so
                    -- <leader>gf was a silent no-op on most Kotlin files. Accept 1.
                    exit_codes = { 0, 1 },
                },
            },
        },
    },
    {
        -- Non-LSP tools Mason should always have: the formatters above and the
        -- linters <leader>xr (repo_diagnostics.lua) runs. Previously these only
        -- existed on machines where they had been :MasonInstall-ed by hand, so on
        -- a fresh machine <leader>gf silently fell back to the LSP (or did
        -- nothing). LSP servers stay in lsp.lua's ensure_installed.
        "WhoIsSethDaniel/mason-tool-installer.nvim",
        dependencies = { "mason-org/mason.nvim" },
        event = "VeryLazy",
        opts = function()
            local function has(bin)
                return function()
                    return vim.fn.executable(bin) == 1
                end
            end
            -- Mason installs pypi packages into a venv, which Debian/Ubuntu's
            -- python3 cannot create until python3-venv is installed. The probe
            -- spawns python3 (~100ms, blocking), and mason-tool-installer
            -- evaluates conditions BEFORE its is-installed check -- so skip the
            -- probe when yamllint is already there (the condition then only
            -- lets mason-tool-installer see it is installed).
            local function has_venv()
                local ok, registry = pcall(require, "mason-registry")
                if ok and registry.is_installed("yamllint") then
                    return true
                end
                if vim.fn.executable("python3") ~= 1 then
                    return false
                end
                vim.fn.system({ "python3", "-c", "import venv, ensurepip" })
                return vim.v.shell_error == 0
            end
            -- Tools built by a language toolchain carry a `condition`: without
            -- the toolchain Mason's install fails, and mason-tool-installer
            -- retried (and reported the failure) on every single start.
            return {
                ensure_installed = {
                    -- formatters
                    { "prettier", condition = has("npm") },
                    "stylua",
                    "ktlint",
                    "ruff", -- also the Python linter for <leader>xr
                    { "goimports", condition = has("go") }, -- built with `go install`
                    { "gofumpt", condition = has("go") },
                    "shfmt",
                    -- linters for <leader>xr
                    "golangci-lint",
                    "hadolint",
                    { "yamllint", condition = has_venv },
                },
                run_on_start = true,
                start_delay = 0,
            }
        end,
        config = function(_, opts)
            local mti = require("mason-tool-installer")
            mti.setup(opts)
            -- The plugin triggers its start-up install from a VimEnter autocmd
            -- (plugin/mason-tool-installer.lua), and VeryLazy fires AFTER
            -- VimEnter -- so without this call nothing would ever install.
            mti.run_on_start()
            -- :MasonToolsClean uninstalls every Mason package NOT in this
            -- plugin's ensure_installed -- which would be every LSP server
            -- (they are ensured by mason-lspconfig in lsp.lua). Replace it with
            -- a refusal; :Mason can uninstall individual packages.
            vim.api.nvim_create_user_command("MasonToolsClean", function()
                vim.notify(
                    "MasonToolsClean is disabled: it would uninstall every LSP server "
                        .. "(ensured by lsp.lua, not mason-tool-installer). Use :Mason to remove packages.",
                    vim.log.levels.WARN
                )
            end, { force = true, desc = "Disabled (would uninstall LSP servers)" })
        end,
    },
}
