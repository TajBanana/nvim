# nvim config

A personal Neovim setup built on [lazy.nvim](https://github.com/folke/lazy.nvim), with native LSP (Mason + nvim-lspconfig), nvim-cmp completion, Treesitter highlighting, Telescope, and an IntelliJ Material Darker-inspired colorscheme. The goal is an IDE-like experience that stays fast and keyboard-driven.

Requires **Neovim v0.11+** (uses the `vim.lsp.config`/`vim.lsp.enable` native LSP API).

> For the **reasoning** behind these choices — the nvm/PATH fix, the Kotlin/Java LSP quirks, the GitLab and repo-lint design, the inlay-hint support matrix — see **[docs/design-decisions.md](docs/design-decisions.md)**.

## Prerequisites

Install these before first launch — most failures without them are silent or cryptic:

| Tool                        | Needed for                                                            |
|-----------------------------|-----------------------------------------------------------------------|
| Neovim **v0.11+**           | The whole config (native LSP API)                                     |
| A **Nerd Font**             | File-tree / statusline icons (garbled boxes without one)              |
| **ripgrep**                 | `Space fw` live grep (silently finds nothing without it)              |
| **make** + a C compiler     | telescope-fzf-native builds on first `:Lazy` install                  |
| **node** (or nvm)           | All node-based LSPs and prettier (die with exit 127 without it)       |
| **tree-sitter** CLI         | Treesitter parser installs (`brew install tree-sitter-cli`)           |
| **lazygit**                 | `Space lg`                                                            |
| **ImageMagick**             | Inline image viewing conversions (`brew install imagemagick`)         |

Per-language, only if you use them: a **JDK** (Java's jdtls and your Gradle builds; Kotlin's kotlin-lsp bundles its own runtime and needs no separate JDK), **go**, **rustup/cargo**, **python3 + ruff** (`Space xr` on Python repos), and **glab** (optional, better `Space gm` — see the GitLab section).

macOS quick start:

```
brew install neovim ripgrep tree-sitter-cli lazygit glab
brew install --cask font-jetbrains-mono-nerd-font   # matches .wezterm.lua
```

Portability notes: the node PATH fix looks for nvm in `~/.nvm` (a system node on PATH also works); the rustup PATH fix assumes Homebrew on macOS (`/opt/homebrew/opt/rustup/bin`); the lazygit *color theme* lives in lazygit's own config outside this repo, so `Space lg` works everywhere but only matches this palette if you theme it separately.

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

**Discover shortcuts as you go:** press `Space` and pause — [which-key](https://github.com/folke/which-key.nvim) pops up a menu of what's available next, grouped by category (Find, Git/Goto, Diagnostics, Refactor, …). You never have to memorize the tables below; they're just a reference.

**On startup** the file tree (nvim-tree) opens on the left. Toggle it with `Alt-1`. Jump into a file with Telescope (`Space ff`), then start navigating code with the LSP shortcuts below.

A typical loop: `Space ff` to open a file → `Space gd` to jump to a definition → `K` to read a signature → `Space ca` (or `Option-Enter`) for a quick fix → `Space gf` to format → `Space lg` to stage and commit in lazygit.

## Keymaps

Leader is `Space`. "n" = normal mode, "i" = insert, "x" = visual.

### Files, search & navigation
| Key                         | Action                                                                |
|-----------------------------|-----------------------------------------------------------------------|
| `Space ff`                  | Find files (Telescope)                                                |
| `Space fw`                  | Live grep — search text across the project                            |
| `Ctrl-p`                    | Find git-tracked files                                                |
| `Alt-1`                     | Toggle the file tree                                                  |
| `E` (in file tree)          | Toggle recursive expand of the directory under the cursor             |
| `Ctrl-d` / `Ctrl-u`         | Half-page down / up, cursor centered                                  |
| `Esc`                       | Clear search highlight and close floating windows                     |

### Code navigation (LSP)
| Key                         | Action                                                                |
|-----------------------------|-----------------------------------------------------------------------|
| `Space gd`                  | Definition / type / implementation / references (opens normal mode)   |
| `Space gi`                  | Go to implementation                                                  |
| `Space gr`                  | Go to references (Telescope)                                          |
| `K`                         | Hover docs — signature, type, doc comment                             |
| `Ctrl-h` (i)                | Signature help while typing arguments                                 |
| `Space vws`                 | Search workspace symbols                                              |
| `Space ti`                  | Toggle inlay hints (inline types/params)                              |

### Refactor & code actions
| Key                         | Action                                                                |
|-----------------------------|-----------------------------------------------------------------------|
| `Space rf`                  | Rename symbol (project-wide)                                          |
| `Space ca` / `Option-Enter` | Code action (quick fix / refactor)                                    |
| `Space gf`                  | Format buffer (on-demand, never on save)                              |

### Diagnostics (Telescope, list left / preview right)
| Key                         | Action                                                                |
|-----------------------------|-----------------------------------------------------------------------|
| `Space xx`                  | Diagnostics across all analyzed buffers (workspace)                   |
| `Space xb`                  | Diagnostics in the current buffer only                                |
| `Space xr`                  | Repo-wide lint — runs the project's linter over every file            |
| `Space vd`                  | Show the diagnostic under the cursor in a float                       |
| `]e` / `[e`                 | Next / previous diagnostic, message shown in a float                  |

### Git
| Key                         | Action                                                                |
|-----------------------------|-----------------------------------------------------------------------|
| `Space lg`                  | **lazygit** — full TUI for staging, committing, branching, history    |
| `Space gb`                  | Toggle git blame: full-file annotate pane, IntelliJ-style             |
| `Space gp`                  | Preview the hunk under the cursor                                     |
| `Space pp` / `Space oo`     | Next / previous changed hunk, with a diff preview (dismiss: move/Esc) |
| `Space gB`                  | Toggle gutter base: whole-branch (vs main) ↔ working tree (vs index)  |
| `Space td`                  | Toggle showing deleted lines                                          |
| `Space dv`                  | Diff the file against the index                                       |
| `ih` (x/o)                  | Text object: select the current git hunk (e.g. `dih`, `vih`)          |

### GitLab (forge-specific — see the GitLab section below)
| Key                         | Action                                                                |
|-----------------------------|-----------------------------------------------------------------------|
| `Space gm`                  | Open (or create) the current branch's merge request                   |
| `Space gl` (n)              | Open the current file + line on GitLab                                |
| `Space gl` (x)              | Open the selected line range on GitLab                                |

### Buffers (open files — the IntelliJ tab bar equivalent)
| Key                         | Action                                                                |
|-----------------------------|-----------------------------------------------------------------------|
| `Space ]` / `Space [`       | Next / previous open file                                             |
| `Space fb`                  | Pick from open files (most-recent first; opens in normal mode)        |
| `dd` / `Alt-d` (in picker)  | Close the highlighted file (normal mode / while typing)               |

### Undo & testing
| Key                         | Action                                                                |
|-----------------------------|-----------------------------------------------------------------------|
| `Space uu`                  | Browse undo history in Telescope (diff preview)                       |
| `Space tt` / `tf` / `ta`    | Test nearest / file / suite (vim-test)                                |

### Selection, terminal & completion
| Key                         | Action                                                                |
|-----------------------------|-----------------------------------------------------------------------|
| `Alt-Up`                    | Start / expand a Treesitter-aware selection (IntelliJ-like)           |
| `Alt-Down` (x)              | Shrink the selection                                                  |
| `F2`                        | Toggle a terminal split                                               |
| `Space md`                  | Toggle in-buffer markdown rendering (formatted ↔ raw)                 |
| `Tab` (i, menu open)        | Confirm completion; else jump to next snippet placeholder             |
| `Shift-Tab` (i)             | Jump to the previous snippet placeholder                              |
| `Enter` (i, menu open)      | Confirm the explicitly selected item                                  |
| `Ctrl-Space` (i)            | Trigger completion manually                                           |
| `Ctrl-n` / `Ctrl-p` (i)     | Next / previous completion item                                       |

## Feature guides

**Completion & snippets.** As you type, nvim-cmp suggests from the LSP, snippets, and the current buffer. `Tab` is the do-everything key: it confirms the highlighted suggestion, and once you've expanded a snippet it jumps through the placeholders (`Shift-Tab` goes back). `Enter` confirms only when you've actively selected an item. Snippets come from [friendly-snippets](https://github.com/rafamadriz/friendly-snippets) (~2k across languages) — the IntelliJ "live template" equivalent.

**Inlay hints** show inferred types and parameter names inline (IntelliJ-style). They're on by default wherever the language server supports them — **TS/TSX/JS, Lua, Go, Rust, Kotlin, Java** — and toggle per buffer with `Space ti`. Python (pyright) and Bash (bashls) don't provide them.

**The `Space gd` picker** merges definition, type-definition, implementation, and references into one Telescope list, tagged and color-coded (`[def]` `[type]` `[impl]` `[ref]`). Type any of those words in the prompt to filter. It queries every attached language server, so it works even in buffers with several (e.g. a `.tsx` with ts_ls + eslint + tailwind).

**Repo-wide diagnostics (`Space xr`).** LSP servers only diagnose files you've opened, so `Space xx` can't show problems in files you've never visited. `Space xr` runs the project's actual linter over the whole repo and loads the results into the Telescope picker. It auto-detects the tool by project marker: **Go** → `go vet`, **Rust** → `cargo check`, **Python** → `ruff`, **JS/TS** → the local `node_modules/.bin/eslint` (falls back to `tsc`). Add more in `lua/tajbanana/repo_diagnostics.lua`.

**Viewing images.** Open a `.png` / `.jpeg` / `.gif` / `.webp` and [snacks.nvim](https://github.com/folke/snacks.nvim) renders it inline — this needs `enable_kitty_graphics = true` in `.wezterm.lua` (WezTerm ships with the protocol off). ImageMagick handles format conversion (see Prerequisites). `.svg` files intentionally open as their XML source instead — SVG rasterization proved unreliable on WezTerm stable, and the markup is usually what you want anyway; use the browser for visual SVG review. (snacks' *document* image preview — the float that popped up on image links inside markdown — is disabled, since WezTerm can't render it inline.)

**Viewing markdown.** Open any `.md` file and [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) renders it in the buffer — headings get icons, `#`/`**`/backticks are concealed, code blocks get a background, and lists and tables are drawn — while staying editable (the line under your cursor and insert mode fall back to raw source). `Space md` toggles rendering off/on.

**Git workflow.** For anything beyond a quick hunk preview, `Space lg` opens **lazygit** — stage/unstage with `Space`, commit with `c`, browse branches, and view diffs (range-select a span of commits with `v`, or diff two arbitrary commits with `W`). Inline, gitsigns shows changes in the sign column (add=green, change=blue, delete=red); `Space pp`/`oo` jump to the next/previous hunk and pop a diff preview of it, which clears as soon as you move the cursor or press `Esc`.

**Whole-branch gutter (IntelliJ-style).** By default the sign column diffs each file against the point where your branch forked from `main` (the merge-base), not against the last commit — so every line you've changed anywhere on the branch stays marked, *even after you commit it*. This mirrors IntelliJ's per-branch change view. `Space gB` toggles the current buffer back to the plain working-tree view (diff vs the index, i.e. only your uncommitted edits) and back again. Notes: gitsigns keeps one base per buffer, so committed-on-branch and still-uncommitted lines share the same sign — the colour encodes the *type* of change, not whether it's committed. The base is pinned at file-open time, so re-open (or toggle twice) after `main` moves. Repos with no `main`/`master`, and files outside git, fall back silently to the working-tree view.

## Repo layout

- `init.lua` — loads core settings, then bootstraps lazy.nvim
- `lua/tajbanana/set.lua` — core Vim options and global keymaps (leader = Space); wires in the feature modules below
- `lua/tajbanana/` modules — each keeps one concern out of `set.lua`: `gitlab.lua` (**GitLab-only** shortcuts, see below), `repo_diagnostics.lua` (the `Space xr` repo-wide linter), `env.lua` (node/cargo PATH fixes), `terminal.lua` (F2 terminal toggle), `incremental_selection.lua` (`M-Up`/`M-Down` node selection), `gitutil.lua` (shared git-root helper), `definition_picker.lua` (the `Space gd` picker), `inlay_tint.lua` (per-kind inlay colouring)
- `lua/plugins/` — one lazy.nvim spec file per concern: `lsp`, `telescope`, `colorscheme`, `treesitter`, `formatting`, `editor`, `git`, `ui`, `kotlin`, `snacks`, `markdown`
- `after/queries/` — custom Treesitter highlight queries per language

## Also in this repo

**`.ideavimrc`** — IdeaVim config for IntelliJ. It shares a few of these bindings (leader = Space) but is **not** a full mirror — several keys map to IntelliJ's own actions and some differ from the nvim setup. Symlink it:

```
ln -s ~/.config/nvim/.ideavimrc ~/.ideavimrc
```

**`.wezterm.lua`** — WezTerm terminal config (also translates macOS `Cmd`/`Option` chords into keys nvim can see). Symlink or copy to where WezTerm looks for it (e.g. `~/.wezterm.lua`).

## GitLab-only shortcuts

These keymaps assume the current file's git remote points at a **GitLab** instance — they build GitLab web URLs and will produce wrong links on GitHub, Bitbucket, or other forges. They live in their own module, `lua/tajbanana/gitlab.lua`, so the assumption stays in one place; delete the `require("tajbanana.gitlab").setup()` line in `set.lua` to disable them, or swap the module for a different forge.

`<leader>gm` prefers [`glab`](https://gitlab.com/gitlab-org/cli) (the official GitLab CLI) when it's installed — it looks up the MR by source branch via the API, which is robust to the local branch SHA drifting from the pushed MR head. If `glab` isn't installed it falls back to a token-free `git ls-remote` lookup (no CLI, no API token). `<leader>gl` is always token-free. To set glab up: `brew install glab` then `glab auth login --hostname <your-host> --stdin` (paste a PAT with `api` scope).

Resolving a branch's MR is a network round-trip to the GitLab server (~1–2s, mostly latency — the call is async, so nvim never blocks). Each `<leader>gm` press shows a brief "Looking up merge request…" while it resolves, then opens the MR (or the create page if there's none yet). It resolves fresh every time, so a just-created MR is always picked up.

`<leader>gl` links to the **current branch**, so the branch must be pushed — an unpushed branch's blob URL will 404.

## LSP servers and formatters

LSP servers are listed in `ensure_installed` in `lua/plugins/lsp.lua` and installed automatically by Mason. To add one, add it to that list; to install something manually, use `:Mason`. Per-server settings (inlay hints, etc.) also live in `lsp.lua`; Kotlin is managed separately by [kotlin.nvim](https://github.com/AlexandrosAlexiou/kotlin.nvim) in `lua/plugins/kotlin.lua`.

Node-based servers need `node` on PATH — since nvm is often lazy-loaded (so `node` isn't on PATH at startup), `set.lua` finds the newest nvm node and prepends it. The same fix is why `Space xr` and node-based formatters work.

Formatters are configured per-filetype in `lua/plugins/formatting.lua` (conform.nvim) and installed via `:Mason`. Formatting is on-demand with `<leader>gf`, not on save; for filetypes without a dedicated formatter it falls back to the LSP's own formatting.

## Customizing colors

The colorscheme is onedark.nvim with a Material Darker-inspired palette and extensive Treesitter/LSP highlight overrides in `lua/plugins/colorscheme.lua`.

Put the cursor on any token and run `:Inspect` to see its Treesitter/LSP highlight group, then add or edit the corresponding entry in `colorscheme.lua`. Use `:Inspect` liberally — it's the fastest way to find the right group to override.

## Troubleshooting

**Kotlin: `Space gd`, hover, and completion silently stop working — nothing attaches.** The JetBrains `intellij-server` binary behind kotlin-lsp is a time-limited **EAP build that expires every few weeks**. Once it lapses it still launches, prints an expiry notice, and exits *before* initializing — so the client never attaches and none of the `LspAttach` keymaps (`Space gd` among them) ever bind. Confirm it in `:LspLog` (or `~/.local/state/nvim/lsp.log`):

```
Client kotlin_lsp quit with exit code 7 ...
"stderr"    "This build of intellij-server has expired. The IDE will now close."
```

Fix — pull a fresh build and restart Neovim:

```
:MasonInstall kotlin-lsp
```

This **recurs**: when Kotlin features die out of nowhere again, it's almost always the same expiry, and the same one-liner fixes it. (Because `Space gd` is wired in the `LspAttach` autocmd in `lsp.lua`, *any* server that fails to attach takes its keymaps down with it — the same log check applies to other languages too.)

**`:MasonInstall` / `:Mason` → `E492: Not an editor command`.** Mason is lazy-loaded, so its commands only exist once the LSP stack has loaded — which happens when you open a file (`BufReadPre`). On the no-file start screen they aren't registered yet. Open any file first, or force the load:

```
:Lazy load nvim-lspconfig
:MasonInstall kotlin-lsp
```

**Kotlin's first open is slow, or `Space gd` finds nothing right after opening.** kotlin-lsp runs a full Gradle import and indexes the project before features light up — a few minutes on a cold project, and it needs network to resolve dependencies. The client attaches quickly but returns nothing until indexing finishes. If it stays broken after that (stale workspace state or a leftover analyzer lock), clear the workspace and reopen:

```
:KotlinCleanWorkspace
```

Only one kotlin-lsp runs at a time machine-wide: a second `intellij-server` (even for a different project) can die instantly on the shared analyzer-cache lock, so close other Kotlin sessions if a project won't come up.

## Validating changes

There is no build or test step. To verify things work:

1. `:messages` — check for startup errors
2. `:checkhealth` — verify plugin health
3. `:Lazy` — plugin status / sync
4. `:LspInfo` — verify LSP server attachment
5. `:TSInstallInfo` — check Treesitter parser status
