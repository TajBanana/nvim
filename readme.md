# nvim config

Personal Neovim configuration using [lazy.nvim](https://github.com/folke/lazy.nvim) as the plugin manager, with native LSP (Mason + nvim-lspconfig) and nvim-cmp for completion.

Requires **Neovim v0.9+**.

## Setup

Clone this repo into `~/.config` and name it `nvim`:

```
git clone <repo-url> ~/.config/nvim
```

Open Neovim. On first launch:

- lazy.nvim bootstraps itself automatically and installs all plugins
- Mason auto-installs the configured LSP servers
- Treesitter parsers auto-install on startup

No manual sync step is needed. If something looks off, run `:Lazy` to check plugin status.

## Repo layout

- `init.lua` — loads core settings, then bootstraps lazy.nvim
- `lua/tajbanana/set.lua` — core Vim settings, keymaps, and custom functions (leader = Space)
- `lua/plugins/` — one lazy.nvim spec file per concern (lsp, telescope, colorscheme, git, ui, ...)

## Also in this repo

**`.ideavimrc`** — IdeaVim config for IntelliJ, mirroring the Neovim keymaps. Symlink it to your home directory:

```
ln -s ~/.config/nvim/.ideavimrc ~/.ideavimrc
```

**`.wezterm.lua`** — WezTerm terminal config. Symlink or copy it to wherever WezTerm looks for config (e.g. `~/.wezterm.lua`).

## LSP servers and formatters

LSP servers are listed in `ensure_installed` in `lua/plugins/lsp.lua` and installed automatically by Mason. To add one, add it to that list; to install something manually, use `:Mason`.

Formatters are configured per-filetype in `lua/plugins/formatting.lua` (conform.nvim) and must also be installed via `:Mason`. Formatting is on-demand with `<leader>gf`, not on save.

## Customizing colors

The colorscheme is onedark.nvim with a Material Darker-inspired palette and extensive highlight overrides in `lua/plugins/colorscheme.lua`.

Put the cursor on any token and run `:Inspect` to see its treesitter/LSP highlight group, then add or edit the corresponding entry in `colorscheme.lua`.

## Validating changes

There is no build or test step. To verify things work:

1. `:messages` — check for startup errors
2. `:checkhealth` — verify plugin health
3. `:Lazy` — plugin status / sync
4. `:LspInfo` — verify LSP server attachment
5. `:TSInstallInfo` — check treesitter parser status
