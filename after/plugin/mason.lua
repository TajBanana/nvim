require("mason").setup()
require("mason-lspconfig").setup {
	ensure_installed = { "lua_ls", "jdtls", "tsserver", "eslint", "jsonls", "tailwindcss", "yamlls", "sqlls"},
}

