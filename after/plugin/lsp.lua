local lsp_zero = require("lsp-zero")

--lsp_zero.on_attach(function(client, bufnr)
-- see :help lsp-zero-keybindings
-- to learn the available actions
--  lsp_zero.default_keymaps({buffer = bufnr})
--end)

require("mason").setup({})
require("mason-lspconfig").setup({
    ensure_installed = { "tsserver" },
    handlers = {
        lsp_zero.default_setup,
        lua_ls = function()
            local lua_opts = lsp_zero.nvim_lua_ls()
            require("lspconfig").lua_ls.setup(lua_opts)
        end,
    },
})

local cmp = require("cmp")
local cmp_select = { behavior = cmp.SelectBehavior.Select }

cmp.setup({
    snippet = {
        expand = function(args)
            require("luasnip").lsp_expand(args.body) -- For `luasnip` users.
        end,
    },
    window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
    },
    mapping = cmp.mapping.preset.insert({
        ["<C-p>"] = cmp.mapping.select_prev_item(cmp_select),
        ["<C-n>"] = cmp.mapping.select_next_item(cmp_select),
        ["<C-y>"] = cmp.mapping.confirm({ select = true }),
        ["<C-Space>"] = cmp.mapping.complete(),
    }),
    sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "luasnip" }, -- For luasnip users.
    }, {
        { name = "buffer" },
    }),
})
-- The nvim-cmp almost supports LSP's capabilities so You should advertise it to LSP servers..
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- An example for configuring `clangd` LSP to use nvim-cmp as a completion engine
require("lspconfig").clangd.setup({
    capabilities = capabilities,
    ..., -- other lspconfig configs
})

lsp_zero.set_preferences({
    suggest_lsp_servers = false,
    sign_icons = {
        error = "E",
        warn = "W",
        hint = "H",
        info = "I",
    },
})

require("luasnip.loaders.from_vscode").lazy_load()

lsp_zero.on_attach(function(client, bufnr)
    local opts = { buffer = bufnr, remap = false }

    vim.keymap.set("n", "<leader>gd", function()
        vim.lsp.buf.definition()
    end, opts)
    vim.keymap.set("n", "<leader>gi", function()
        vim.lsp.buf.implementation()
    end, opts)
    vim.keymap.set("n", "<leader>gu", function()
        vim.lsp.buf.references()
    end, opts)
    vim.keymap.set("n", "K", function()
        vim.lsp.buf.hover()
    end, opts)
    vim.keymap.set("n", "<leader>vws", function()
        vim.lsp.buf.workspace_symbol()
    end, opts)
    vim.keymap.set("n", "<leader>vd", function()
        vim.diagnostic.open_float()
    end, opts)
    vim.keymap.set("n", "]e", function()
        vim.diagnostic.goto_next()
    end, opts)
    vim.keymap.set("n", "[e", function()
        vim.diagnostic.goto_prev()
    end, opts)
    vim.keymap.set("n", "<leader>ca", function()
        vim.lsp.buf.code_action()
    end, opts)
    vim.keymap.set("n", "<leader>rf", function()
        vim.lsp.buf.rename()
    end, opts)
    vim.keymap.set("i", "<C-h>", function()
        vim.lsp.buf.signature_help()
    end, opts)
end)

lsp_zero.setup()

vim.diagnostic.config({
    virtual_text = true,
})
