# nvim config

A personal Neovim setup built on [lazy.nvim](https://github.com/folke/lazy.nvim), with native LSP (Mason + nvim-lspconfig), nvim-cmp completion, Treesitter highlighting, Telescope, and an IntelliJ Material Darker-inspired colorscheme. The goal is an IDE-like experience that stays fast and keyboard-driven.

Requires **Neovim v0.11+** (uses the `vim.lsp.config`/`vim.lsp.enable` native LSP API).

> For the **reasoning** behind these choices — the nvm/PATH fix, the Kotlin/Java LSP quirks, the GitLab and repo-lint design, the inlay-hint support matrix — see **[docs/design-decisions.md](docs/design-decisions.md)**.

## Setup

Clone this repo into `~/.config` and name it `nvim`:

```
git clone <repo-url> ~/.config/nvim
```

Open Neovim. On first launch:

- lazy.nvim bootstraps itself and installs all plugins
- Mason auto-installs the configured LSP servers
- Treesitter parsers auto-install on startup

No manual sync step is needed. Give the LSP servers a moment on first open of a language (some, like jdtls for Java, index the whole project before features light up). If something looks off, run `:Lazy` for plugin status or `:checkhealth`.

## Getting started

**The leader key is `Space`.** Almost every custom shortcut starts with it.

**Discover shortcuts as you go:** press `Space` and pause — [which-key](https://github.com/folke/which-key.nvim) pops up a menu of what's available next, grouped by category (Find, Git/Goto, Harpoon, Diagnostics, Refactor, …). You never have to memorize the tables below; they're just a reference.

**On startup** the file tree (nvim-tree) opens on the left. Toggle it with `Alt-1`. Jump into a file with Telescope (`Space ff`), then start navigating code with the LSP shortcuts below.

A typical loop: `Space ff` to open a file → `Space gd` to jump to a definition → `K` to read a signature → `Space ca` (or `Option-Enter`) for a quick fix → `Space gf` to format → `Space lg` to stage and commit in lazygit.

## Keymaps

Leader is `Space`. "n" = normal mode, "i" = insert, "x" = visual.

### Files, search & navigation
| Key                         | Action                                                             |
|-----------------------------|--------------------------------------------------------------------|
| `Space ff`                  | Find files (Telescope)                                             |
| `Space fw`                  | Live grep — search text across the project                         |
| `Ctrl-p`                    | Find git-tracked files                                             |
| `Alt-1`                     | Toggle the file tree                                               |
| `Ctrl-d` / `Ctrl-u`         | Half-page down / up, cursor centered                               |

### Code navigation (LSP)
| Key                         | Action                                                             |
|-----------------------------|--------------------------------------------------------------------|
| `Space gd`                  | Definition / type / implementation / references — one picker       |
| `Space gi`                  | Go to implementation                                               |
| `Space gr`                  | Go to references (Telescope)                                       |
| `K`                         | Hover docs — signature, type, doc comment                          |
| `Ctrl-h` (i)                | Signature help while typing arguments                              |
| `Space vws`                 | Search workspace symbols                                           |
| `Space ti`                  | Toggle inlay hints (inline types/params)                           |

### Refactor & code actions
| Key                         | Action                                                             |
|-----------------------------|--------------------------------------------------------------------|
| `Space rf`                  | Rename symbol (project-wide)                                       |
| `Space ca` / `Option-Enter` | Code action (quick fix / refactor)                                 |
| `Space gf`                  | Format buffer (on-demand, never on save)                           |

### Diagnostics (Telescope, list left / preview right)
| Key                         | Action                                                             |
|-----------------------------|--------------------------------------------------------------------|
| `Space xx`                  | Diagnostics across all analyzed buffers (workspace)                |
| `Space xb`                  | Diagnostics in the current buffer only                             |
| `Space xr`                  | Repo-wide lint — runs the project's linter over every file         |
| `Space vd`                  | Show the diagnostic under the cursor in a float                    |
| `]e` / `[e`                 | Next / previous diagnostic                                         |

### Git
| Key                         | Action                                                             |
|-----------------------------|--------------------------------------------------------------------|
| `Space lg`                  | **lazygit** — full TUI for staging, committing, branching, history |
| `Space gs`                  | Git status (vim-fugitive, vertical split)                          |
| `Space gb`                  | Git branches (Telescope)                                           |
| `Space gp`                  | Preview the hunk under the cursor                                  |
| `Space pp` / `Space oo`     | Next / previous changed hunk                                       |
| `Space td`                  | Toggle showing deleted lines                                       |
| `Space dv`                  | Diff the file against the index                                    |
| `ih` (x/o)                  | Text object: select the current git hunk (e.g. `dih`, `vih`)       |

### GitLab (forge-specific — see the GitLab section below)
| Key                         | Action                                                             |
|-----------------------------|--------------------------------------------------------------------|
| `Space gm`                  | Open (or create) the current branch's merge request                |
| `Space gl` (n)              | Open the current file + line on GitLab                             |
| `Space gl` (x)              | Open the selected line range on GitLab                             |

### Harpoon (pin a few files, jump instantly)
| Key                         | Action                                                             |
|-----------------------------|--------------------------------------------------------------------|
| `Space ha`                  | Add the current file to the list                                   |
| `Space he`                  | Edit the list (quick menu)                                         |
| `Space h1`–`h4`             | Jump to pinned file 1–4                                            |
| `Space [` / `Space ]`       | Previous / next pinned file                                        |

### Undo & testing
| Key                         | Action                                                             |
|-----------------------------|--------------------------------------------------------------------|
| `Space uu`                  | Browse undo history in Telescope (diff preview)                    |
| `Space tt` / `tf` / `ta`    | Test nearest / file / suite (vim-test)                             |

### Selection, terminal & completion
| Key                         | Action                                                             |
|-----------------------------|--------------------------------------------------------------------|
| `Alt-Up`                    | Start / expand a Treesitter-aware selection (IntelliJ-like)        |
| `Alt-Down` (x)              | Shrink the selection                                               |
| `F2`                        | Toggle a terminal split                                            |
| `Tab` (i, menu open)        | Confirm completion; else jump to next snippet placeholder          |
| `Shift-Tab` (i)             | Jump to the previous snippet placeholder                           |
| `Enter` (i, menu open)      | Confirm the explicitly selected item                               |
| `Ctrl-Space` (i)            | Trigger completion manually                                        |
| `Ctrl-n` / `Ctrl-p` (i)     | Next / previous completion item                                    |

## Feature guides

**Completion & snippets.** As you type, nvim-cmp suggests from the LSP, snippets, and the current buffer. `Tab` is the do-everything key: it confirms the highlighted suggestion, and once you've expanded a snippet it jumps through the placeholders (`Shift-Tab` goes back). `Enter` confirms only when you've actively selected an item. Snippets come from [friendly-snippets](https://github.com/rafamadriz/friendly-snippets) (~2k across languages) — the IntelliJ "live template" equivalent.

**Inlay hints** show inferred types and parameter names inline (IntelliJ-style). They're on by default wherever the language server supports them — **TS/TSX/JS, Lua, Go, Rust, Kotlin, Java** — and toggle per buffer with `Space ti`. Python (pyright) and Bash (bashls) don't provide them.

**The `Space gd` picker** merges definition, type-definition, implementation, and references into one Telescope list, tagged and color-coded (`[def]` `[type]` `[impl]` `[ref]`). Type any of those words in the prompt to filter. It queries every attached language server, so it works even in buffers with several (e.g. a `.tsx` with ts_ls + eslint + tailwind).

**Repo-wide diagnostics (`Space xr`).** LSP servers only diagnose files you've opened, so `Space xx` can't show problems in files you've never visited. `Space xr` runs the project's actual linter over the whole repo and loads the results into the Telescope picker. It auto-detects the tool by project marker: **Go** → `go vet`, **Rust** → `cargo check`, **Python** → `ruff`, **JS/TS** → the local `node_modules/.bin/eslint` (falls back to `tsc`). Add more in `lua/tajbanana/repo_diagnostics.lua`.

**Git workflow.** For anything beyond a quick hunk preview, `Space lg` opens **lazygit** — stage/unstage with `Space`, commit with `c`, browse branches, and view diffs (range-select a span of commits with `v`, or diff two arbitrary commits with `W`). Inline, gitsigns shows changes in the sign column and `Space pp`/`oo` jump between hunks.

## Repo layout

- `init.lua` — loads core settings, then bootstraps lazy.nvim
- `lua/tajbanana/set.lua` — core Vim options, global keymaps, and custom functions (leader = Space)
- `lua/tajbanana/gitlab.lua` — **GitLab-only** shortcuts (see below), isolated because they assume a GitLab remote
- `lua/tajbanana/repo_diagnostics.lua` — the `Space xr` repo-wide linter
- `lua/plugins/` — one lazy.nvim spec file per concern: `lsp`, `telescope`, `colorscheme`, `treesitter`, `formatting`, `editor`, `git`, `harpoon`, `ui`, `kotlin`
- `after/queries/` — custom Treesitter highlight queries per language

## Also in this repo

**`.ideavimrc`** — IdeaVim config for IntelliJ, mirroring these keymaps. Symlink it:

```
ln -s ~/.config/nvim/.ideavimrc ~/.ideavimrc
```

**`.wezterm.lua`** — WezTerm terminal config (also translates macOS `Cmd`/`Option` chords into keys nvim can see). Symlink or copy to where WezTerm looks for it (e.g. `~/.wezterm.lua`).

## GitLab-only shortcuts

These keymaps assume the current file's git remote points at a **GitLab** instance — they build GitLab web URLs and will produce wrong links on GitHub, Bitbucket, or other forges. They live in their own module, `lua/tajbanana/gitlab.lua`, so the assumption stays in one place; delete the `require("tajbanana.gitlab").setup()` line in `set.lua` to disable them, or swap the module for a different forge.

`<leader>gm` prefers [`glab`](https://gitlab.com/gitlab-org/cli) (the official GitLab CLI) when it's installed — it looks up the MR by source branch via the API, which is robust to the local branch SHA drifting from the pushed MR head. If `glab` isn't installed it falls back to a token-free `git ls-remote` lookup (no CLI, no API token). `<leader>gl` is always token-free. To set glab up: `brew install glab` then `glab auth login --hostname <your-host> --stdin` (paste a PAT with `api` scope).

Resolving a branch's MR is a network round-trip to the GitLab server (~1–2s, mostly latency — the call is async, so nvim never blocks). The first `<leader>gm` on a branch shows a brief "Looking up merge request…" while it resolves; the result is cached for the nvim session, so subsequent opens of the same branch's MR are instant. A "no MR yet" result is not cached, so a freshly-created MR is picked up on the next press.

`<leader>gl` links to the **current branch**, so the branch must be pushed — an unpushed branch's blob URL will 404.

## LSP servers and formatters

LSP servers are listed in `ensure_installed` in `lua/plugins/lsp.lua` and installed automatically by Mason. To add one, add it to that list; to install something manually, use `:Mason`. Per-server settings (inlay hints, etc.) also live in `lsp.lua`; Kotlin is managed separately by [kotlin.nvim](https://github.com/AlexandrosAlexiou/kotlin.nvim) in `lua/plugins/kotlin.lua`.

Node-based servers need `node` on PATH — since nvm is often lazy-loaded (so `node` isn't on PATH at startup), `set.lua` finds the newest nvm node and prepends it. The same fix is why `Space xr` and node-based formatters work.

Formatters are configured per-filetype in `lua/plugins/formatting.lua` (conform.nvim) and installed via `:Mason`. Formatting is on-demand with `<leader>gf`, not on save; for filetypes without a dedicated formatter it falls back to the LSP's own formatting.

## Customizing colors

The colorscheme is onedark.nvim with a Material Darker-inspired palette and extensive Treesitter/LSP highlight overrides in `lua/plugins/colorscheme.lua`.

Put the cursor on any token and run `:Inspect` to see its Treesitter/LSP highlight group, then add or edit the corresponding entry in `colorscheme.lua`. Use `:Inspect` liberally — it's the fastest way to find the right group to override.

## Validating changes

There is no build or test step. To verify things work:

1. `:messages` — check for startup errors
2. `:checkhealth` — verify plugin health
3. `:Lazy` — plugin status / sync
4. `:LspInfo` — verify LSP server attachment
5. `:TSInstallInfo` — check Treesitter parser status
