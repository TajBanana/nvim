require("mason").setup()
require("mason-lspconfig").setup {
	ensure_installed = { "lua_ls", "jdtls", "tsserver", "eslint", "jsonls", "tailwindcss", "yamlls", "sqlls", "kotlin_language_server", "gradle_ls", "dockerls", "cssls", "emmet_ls", "graphql","html"},
}

