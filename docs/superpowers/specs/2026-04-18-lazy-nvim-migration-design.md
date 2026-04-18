# Neovim Config Migration: Packer to lazy.nvim + Native LSP

## Goal

Migrate the Neovim configuration from Packer to lazy.nvim, replace lsp-zero with native 0.11 LSP APIs, and replace none-ls with conform.nvim.

## Approach

Big bang migration — rewrite all config files in one pass. Git history provides rollback.

## New File Structure

```
init.lua                          # Bootstrap lazy.nvim, load set.lua, call lazy.setup("plugins")
lua/
  tajbanana/
    set.lua                       # Editor settings (mostly unchanged)
  plugins/
    colorscheme.lua               # onedark
    telescope.lua                 # telescope
    harpoon.lua                   # harpoon2
    treesitter.lua                # treesitter
    lsp.lua                       # mason + mason-lspconfig + nvim-lspconfig + nvim-cmp + luasnip
    formatting.lua                # conform.nvim (replaces none-ls)
    git.lua                       # fugitive + gitsigns + git-blame
    ui.lua                        # lualine + indent-blankline + nvim-tree + nvim-web-devicons
    editor.lua                    # nvim-surround + Comment + autoclose + undotree + vim-test
```

## Deleted Files

- `lua/tajbanana/packer.lua`
- `plugin/packer_compiled.lua`
- `after/plugin/` (entire directory — all 15 files)

## Changes by Component

### 1. init.lua

- Bootstrap lazy.nvim (auto-clone from GitHub if not installed)
- `require("tajbanana.set")`
- `require("lazy").setup("plugins")` — auto-loads all files in `lua/plugins/`

### 2. lua/tajbanana/set.lua

Mostly unchanged. Two fixes:
- Use `vim.fn.stdpath("state") .. "/undodir"` instead of `~/.vim/undodir` and auto-create the directory
- Replace `vim.cmd("set splitright")` and `vim.cmd("set clipboard+=unnamedplus")` with `vim.opt` equivalents

### 3. lua/plugins/lsp.lua — Native 0.11 LSP

**Plugins:** mason.nvim, mason-lspconfig.nvim, nvim-lspconfig, nvim-cmp, cmp-nvim-lsp, LuaSnip, cmp_luasnip

**LSP servers (12):**
- ts_ls, eslint, tailwindcss, html, cssls, jsonls, yamlls — web
- jdtls, kotlin_language_server — JVM
- graphql — API
- dockerls — infra
- lua_ls — Neovim config

**Setup flow:**
1. `mason.setup()`
2. `mason-lspconfig.setup({ ensure_installed = [...] })` with automatic handler
3. `vim.lsp.config()` for each server with capabilities from cmp-nvim-lsp
4. `vim.lsp.enable()` for each server
5. Special handling for `lua_ls` (Neovim runtime settings)
6. `LspAttach` autocmd for keymaps (replaces lsp-zero `on_attach`)
7. nvim-cmp setup (unchanged mappings: C-p, C-n, Tab, C-Space)

**Keymaps (on LspAttach):**
- `<leader>gd` — definition
- `<leader>gi` — implementation
- `<leader>gr` — references
- `K` — hover
- `<leader>vws` — workspace symbol
- `<leader>vd` — diagnostic float
- `]e` / `[e` — next/prev diagnostic (using `vim.diagnostic.jump()`)
- `<leader>ca` — code action
- `<leader>rf` — rename
- `<C-h>` (insert) — signature help

**Diagnostics config:**
- Virtual text enabled
- Sign icons: E, W, H, I

### 4. lua/plugins/formatting.lua — conform.nvim

Replaces none-ls. Formatters:
- `stylua` for Lua files

Keymap: `<leader>gf` calls `conform.format()`

### 5. lua/plugins/colorscheme.lua

Same OneDark deep config with all custom colors and highlights. Set `lazy = false, priority = 1000` so it loads first.

### 6. lua/plugins/telescope.lua

Same config. Single `setup()` call (fixes current duplicate setup calls). Keymaps:
- `<C-p>` — git files
- `<leader>ff` — find files
- `<leader>fw` — grep string
- `<leader>gb` — git branches

### 7. lua/plugins/harpoon.lua

Same harpoon2 config with telescope integration. All keymaps preserved.

### 8. lua/plugins/treesitter.lua

Same config minus `scala` parser (not in your stack). Drop `nvim-treesitter/playground` (use built-in `:InspectTree`).

### 9. lua/plugins/git.lua

Three plugins in one spec:
- fugitive — `<leader>gs`, `<leader>dv`
- gitsigns — all current keymaps
- git-blame — no config needed

### 10. lua/plugins/ui.lua

Four plugins:
- lualine (same config)
- indent-blankline (same config)
- nvim-tree (same config, keeps netrw disabled)
- nvim-web-devicons (dependency)

### 11. lua/plugins/editor.lua

Four plugins:
- nvim-surround — `require("nvim-surround").setup({})` only (no source dump)
- Comment.nvim — `require("Comment").setup()`
- autoclose — same angle bracket config
- undotree — `<leader>ut` keymap
- vim-test — same keymaps (`<leader>tt`, `<leader>tf`, `<leader>ta`)

## Lazy Loading

- colorscheme: `lazy = false, priority = 1000`
- telescope: load on keymaps
- harpoon: load on keymaps
- undotree: load on keymap
- fugitive: load on command `Git`
- nvim-tree: load on keymap
- git-blame: load on event `BufReadPre`
- gitsigns: load on event `BufReadPre`
- treesitter: load on event `BufReadPost`
- lsp/cmp: load on event `BufReadPre`
- conform: load on keymap
- Comment, surround, autoclose: load on event `BufReadPre`
- vim-test: load on keymaps

## Post-Migration Cleanup

- Remove packer cache: `~/.local/share/nvim/site/pack/packer/`
- Run `:Lazy sync` to install all plugins
- Run `:checkhealth` to verify
