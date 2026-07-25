# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A personal Neovim configuration (~/.config/nvim) using **lazy.nvim** as the plugin manager. Also includes a `.wezterm.lua` (WezTerm terminal config) and `.ideavimrc` (IntelliJ IdeaVim config) in the same repo.

Requires Neovim v0.11+ (uses the `vim.lsp.config`/`vim.lsp.enable` native LSP API). Uses native LSP (not null-ls).

## Architecture

**Entry point:** `init.lua` loads core settings then bootstraps lazy.nvim, which auto-discovers plugin specs from `lua/plugins/`.

**Two key directories:**
- `lua/tajbanana/set.lua` — Core Vim options and global keymaps (leader = Space). Loaded first, before plugins. It `require(...).setup()`s the feature/helper modules below rather than defining features inline.
- `lua/plugins/` — Each file returns a lazy.nvim plugin spec table (or list of tables). Lazy auto-loads all files in this directory.

**`lua/tajbanana/` modules** (standalone Lua, not plugin specs; each keeps one concern out of `set.lua`):
- `gitlab.lua` — **GitLab-specific** shortcuts (`<leader>gm` open/create MR, `<leader>gl` open file/line in the browser). Deliberately isolated because it builds GitLab web URLs that don't work on other forges; keep forge-specific assumptions here, not in `set.lua`.
- `env.lua` — PATH bootstrapping for node (nvm lazy-load) and cargo/rustc (rustup) when they're missing from PATH.
- `terminal.lua` — the F2 bottom terminal-split toggle.
- `incremental_selection.lua` — treesitter incremental selection (`<M-Up>`/`<M-Down>`); the node stack is buffer-scoped.
- `gitutil.lua` — shared git-toplevel resolution (used by `gitlab.lua`, `repo_diagnostics.lua`, and `plugins/git.lua`).
- `repo_diagnostics.lua` — repo-wide lint (`<leader>xr`); the tool is picked by project marker.
- `definition_picker.lua` — the `<leader>gd` flat def/type/impl/ref Telescope picker (wired from `lsp.lua`'s `LspAttach`, not `set.lua`).
- `inlay_tint.lua` — re-tints inlay hints per LSP kind (type vs parameter); set up from `lsp.lua`.

**Plugin organization by file:**
- `lsp.lua` — nvim-lspconfig + Mason (auto-installs LSP servers) + nvim-cmp (completion)
- `colorscheme.lua` — onedark.nvim with a custom Material Darker-inspired palette and extensive treesitter/LSP highlight overrides
- `telescope.lua` — Fuzzy finder (file search, grep, open-buffer picker with dd-to-close)
- `treesitter.lua` — Syntax highlighting with auto-install for parsers
- `formatting.lua` — conform.nvim (format-on-demand, not auto-format)
- `editor.lua` — Editing utilities (surround, comments, autoclose, trouble, vim-test)
- `git.lua` — gitsigns (hunk nav `<leader>oo`/`pp` open a diff preview; gutter defaults to an IntelliJ-style whole-branch base = merge-base with main, toggled per-buffer with `<leader>gB`), git-blame (inline), blame.nvim (per-line annotate pane on `<leader>gb`), lazygit (fugitive removed: lazygit + gitsigns.diffthis cover it)
- `ui.lua` — lualine, indent-blankline, nvim-tree (file explorer; `E` toggles scoped expand)
- `kotlin.lua` — kotlin.nvim managing JetBrains kotlin-lsp (excluded from mason-lspconfig auto-enable)
- `snacks.lua` — snacks.nvim image module: inline raster viewing (svg opens as XML; the markdown document-image preview is disabled)
- `markdown.lua` — render-markdown.nvim: in-buffer markdown rendering (headings, lists, tables, code) on the markdown filetype; `<leader>md` toggles it

## Key Conventions

- **Plugin specs** follow lazy.nvim format: each `lua/plugins/*.lua` file returns a table with plugin name, dependencies, config/opts, and lazy-loading triggers (keys, event, cmd).
- **Keymaps** are defined in two places: global keymaps in `lua/tajbanana/set.lua`, plugin-specific keymaps in the plugin spec's `keys` field or `config` function.
- **LSP servers** are managed via Mason with `ensure_installed`; add new servers there. LSP keymaps are set via `LspAttach` autocmd.
- **Formatters** are configured per-filetype in `formatting.lua` via conform.nvim's `formatters_by_ft`. Formatters must be installed via Mason (`:Mason`).
- **Color customization** uses treesitter highlight groups and LSP semantic tokens in `colorscheme.lua`. Use `:Inspect` to find the highlight group under the cursor.

## Symlinks

The `.ideavimrc` should be symlinked to `~/.ideavimrc`:
```
ln -s ~/.config/nvim/.ideavimrc ~/.ideavimrc
```

## Validating Changes

There is no build/test/lint step. To verify changes work:
1. Open Neovim and check for errors: `:messages`
2. Run `:checkhealth` to verify plugin health
3. Run `:Lazy` to check plugin status and sync if needed
4. For LSP changes: `:LspInfo` to verify server attachment
5. For treesitter changes: `:TSInstallInfo` to check parser status
