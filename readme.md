# nvim config

Personal Neovim configuration using [lazy.nvim](https://github.com/folke/lazy.nvim) as the plugin manager, with native LSP (Mason + nvim-lspconfig) and nvim-cmp for completion.

Requires **Neovim v0.11+** (uses the `vim.lsp.config`/`vim.lsp.enable` native LSP API).

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
- `lua/tajbanana/gitlab.lua` — **GitLab-only** shortcuts (see below), isolated because they assume a GitLab remote
- `lua/plugins/` — one lazy.nvim spec file per concern (lsp, telescope, colorscheme, git, ui, ...)

## Also in this repo

**`.ideavimrc`** — IdeaVim config for IntelliJ, mirroring the Neovim keymaps. Symlink it to your home directory:

```
ln -s ~/.config/nvim/.ideavimrc ~/.ideavimrc
```

**`.wezterm.lua`** — WezTerm terminal config. Symlink or copy it to wherever WezTerm looks for config (e.g. `~/.wezterm.lua`).

## GitLab-only shortcuts

These keymaps assume the current file's git remote points at a **GitLab**
instance — they build GitLab web URLs and will produce wrong links on GitHub,
Bitbucket, or other forges. They live in their own module,
`lua/tajbanana/gitlab.lua`, so the GitLab assumption stays in one place; delete
the `require("tajbanana.gitlab").setup()` line in `set.lua` to disable them, or
swap the module for a different forge.

`<leader>gm` prefers [`glab`](https://gitlab.com/gitlab-org/cli) (the official
GitLab CLI) when it's installed — it looks up the MR by source branch via the
API, which is robust to the local branch SHA drifting from the pushed MR head.
If `glab` isn't installed it falls back to a token-free `git ls-remote` lookup
(no CLI, no API token). `<leader>gl` is always token-free. To set glab up:
`brew install glab` then `glab auth login --hostname <your-host> --stdin`
(paste a PAT with `api` scope).

Resolving a branch's MR is a network round-trip to the GitLab server (~1–2s,
mostly latency — the call is async, so nvim never blocks). The first
`<leader>gm` on a branch shows a brief "Looking up merge request…" while it
resolves; the result is cached for the nvim session, so subsequent opens of the
same branch's MR are instant. A "no MR yet" result is not cached, so a
freshly-created MR is picked up on the next press.

| Keymap | Mode | Action |
|--------|------|--------|
| `<leader>gm` | normal | Open the current branch's merge request (or the create page if none exists yet) |
| `<leader>gl` | normal | Open the current file + cursor line on GitLab (`…/-/blob/<branch>/<path>#L<n>`) |
| `<leader>gl` | visual | Open the selected line range on GitLab (`#L<start>-<end>`) |

`<leader>gl` links to the **current branch**, so the branch must be pushed —
an unpushed branch's blob URL will 404.

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
