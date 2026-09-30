# nvim config

A personal Neovim setup built on [lazy.nvim](https://github.com/folke/lazy.nvim), with native LSP (Mason + nvim-lspconfig), nvim-cmp completion, Treesitter highlighting, Telescope, and an IntelliJ Material Darker-inspired colorscheme. The goal is an IDE-like experience that stays fast and keyboard-driven.

Requires **Neovim v0.12+** (the pinned nvim-treesitter `main` branch needs 0.12, and the config uses 0.12-only APIs such as the `ui2` message UI; LSP uses the native `vim.lsp.config`/`vim.lsp.enable` API).

> For the **reasoning** behind these choices — the nvm/PATH fix, the Kotlin/Java LSP quirks, the GitHub and repo-lint design, the inlay-hint support matrix — see **[docs/design-decisions.md](docs/design-decisions.md)**.

## Prerequisites

Install these before first launch — most failures without them are silent or cryptic:

| Tool                        | Needed for                                                            |
|-----------------------------|-----------------------------------------------------------------------|
| Neovim **v0.12+**           | The whole config (treesitter `main`, native LSP API, `ui2`)           |
| A **Nerd Font**             | File-tree / statusline icons (garbled boxes without one)              |
| **ripgrep**                 | `Space fw` live grep (silently finds nothing without it)              |
| **make** + a C compiler     | telescope-fzf-native builds on first `:Lazy` install                  |
| **node** (or nvm)           | All node-based LSPs and prettier (die with exit 127 without it)       |
| **tree-sitter** CLI         | Treesitter parser installs (`brew install tree-sitter-cli`)           |
| **lazygit**                 | `Space lg`                                                            |
| **git-delta**               | Side-by-side diffs in lazygit, `Space gc`/`gh`, and terminal git      |
| **ImageMagick**             | Inline image viewing conversions (`brew install imagemagick`)         |

Per-language, only if you use them: a **JDK** (Java's jdtls and your Gradle builds; Kotlin's kotlin-lsp bundles its own runtime, but the **ktlint** formatter behind `Space gf` is a JVM tool, so Kotlin formatting still needs a JDK on `PATH`), **go** (also needed for Mason to install `gopls`, `goimports` and `gofumpt` — without it they are skipped), **rustup/cargo**, **python3** with `venv` (Mason installs `yamllint` into its own venv; on Debian/Ubuntu that needs the `python3-venv` package), **helm** (`Space xr` on charts), and the **gh** CLI (optional, better `Space gm` — see the forge section). Formatters and linters themselves (prettier, stylua, ktlint, ruff, goimports, gofumpt, shfmt, golangci-lint, hadolint, yamllint) are installed automatically by Mason — no manual `:MasonInstall`; the ones that need a toolchain (`go`, `npm`, python3 venv) are skipped on machines without it rather than failing on every start.

macOS quick start:

```
brew install neovim ripgrep tree-sitter-cli lazygit git-delta imagemagick gh
brew install --cask font-jetbrains-mono-nerd-font   # matches .wezterm.lua
```

Portability notes: the node PATH fix looks for nvm in `~/.nvm` (a system node on PATH also works); the cargo PATH fix tries `~/.cargo/bin` first and then Homebrew's rustup prefix (`/opt/homebrew/opt/rustup/bin`, or `/usr/local/opt/rustup/bin` on Intel Macs), so it covers a standard rustup install on Linux/WSL as well as macOS — but it only helps if a toolchain is actually installed. The lazygit theme lives in `lazygit/config.yml`, which `Space lg` always uses; link it into lazygit's own config dir only if you also want it for terminal `lazygit` (see [Symlinks](#symlinks)).

## Setup

Clone this repo into `~/.config` and name it `nvim`:

```
git clone <repo-url> ~/.config/nvim
```

Open Neovim. On first launch:

- lazy.nvim bootstraps itself and installs all plugins
- Mason auto-installs the configured LSP servers, and mason-tool-installer the formatters and linters (in the background — leave nvim open until they finish; anything interrupted is retried on the next start)
- Treesitter parsers auto-install on startup
- Kotlin is the exception: its server is self-managed, so run `:KotlinLspUpdate` once (see [Troubleshooting](#troubleshooting))

No manual sync step is needed. Give the LSP servers a moment on first open of a language (some, like jdtls for Java, index the whole project before features light up). If something looks off, run `:Lazy` for plugin status or `:checkhealth`.

## Getting started

**The leader key is `Space`.** Almost every custom shortcut starts with it.

**Discover shortcuts as you go:** press `Space` and pause — [which-key](https://github.com/folke/which-key.nvim) pops up a menu of what's available next, grouped by category (Find, Git/Goto, Diagnostics, Refactor, …). You never have to memorize the tables below; they're just a reference.

**On startup** the file tree (nvim-tree) opens on the left when you launch nvim to *browse* — `nvim .` on a directory, or bare `nvim` with no file. Opening a single file (`nvim foo.ts`) leaves you in the file with no tree. Toggle it any time with `Alt-1`. Jump into a file with Telescope (`Space ff`), then start navigating code with the LSP shortcuts below.

A typical loop: `Space ff` to open a file → `Space gd` to jump to a definition → `K` to read a signature → `Space ca` (or `Option-Enter`) for a quick fix → `Space gf` to format → `Space lg` to stage and commit in lazygit.

## Keymaps

Leader is `Space`. "n" = normal mode, "i" = insert, "x" = visual.

### Files, search & navigation
| Key                         | Action                                                                |
|-----------------------------|-----------------------------------------------------------------------|
| `Space ff`                  | Find files (Telescope)                                                |
| `Space fw`                  | Live grep — search text across the project                            |
| `Space fk`                  | Search every keymap by name (mode + keys + description)               |
| `Ctrl-p`                    | Find git-tracked files (all files when not in a git repo)             |
| `Alt-1`                     | Toggle the file tree                                                  |
| `E` (in file tree)          | Toggle recursive expand of the directory under the cursor             |
| `Ctrl-d` / `Ctrl-u`         | Half-page down / up, cursor centered                                  |
| `Esc`                       | Clear search highlight and close floating windows                     |
| `/` search                  | Case-insensitive, unless the pattern has a capital (`smartcase`)      |

### Code navigation (LSP)
| Key                         | Action                                                                |
|-----------------------------|-----------------------------------------------------------------------|
| `Space gd`                  | Definition / type / implementation / references (opens normal mode)   |
| `Space gi`                  | Go to implementation (Telescope; jumps directly if only one)          |
| `Space gr`                  | Go to references (Telescope)                                          |
| `K`                         | Hover docs — signature, type, doc comment                             |
| `Ctrl-h` (i)                | Signature help while typing arguments                                 |
| `Space vws`                 | Find a symbol anywhere in the project — live search (Telescope)       |
| `Space ti`                  | Toggle inlay hints (inline types/params)                              |

### Refactor & code actions
| Key                         | Action                                                                |
|-----------------------------|-----------------------------------------------------------------------|
| `Space rf`                  | Rename symbol (project-wide), in a popup at the cursor                |
| `Space ca` / `Option-Enter` | Code action (quick fix / refactor)                                    |
| `Space gf`                  | Format buffer (on-demand, never on save)                              |

### Diagnostics (Telescope, list left / preview right)
| Key                         | Action                                                                |
|-----------------------------|-----------------------------------------------------------------------|
| `Space xx`                  | Diagnostics across all analyzed buffers (workspace)                   |
| `Space xb`                  | Diagnostics in the current buffer only                                |
| `Space xr`                  | Project-wide lint — runs the nearest project's linter over all its files |
| `Space vd`                  | Show the diagnostic under the cursor in a float                       |
| `Space e`                   | Show every diagnostic on the current line, with its source            |
| `]e` / `[e`                 | Next / previous diagnostic, message shown in a float                  |

`Space vd` and `Space e` overlap but are not the same: `Space vd` is scoped to the symbol under the *cursor* and is only bound where an LSP is attached, while `Space e` covers the whole *line*, labels which tool produced each message, and works with any diagnostic source even with no language server running. (`Space xr`'s repo lint is not one: its results go to the quickfix list and its Telescope picker.)

### Git
| Key                         | Action                                                                |
|-----------------------------|-----------------------------------------------------------------------|
| `Space lg`                  | **lazygit** — full TUI for staging, committing, branching, history    |
| `Space gb`                  | Toggle git blame: full-file annotate pane, IntelliJ-style             |
| `Space gp`                  | Preview the hunk under the cursor                                     |
| `Space pp` / `Space oo`     | Next / previous changed hunk, with a diff preview (dismiss: move/Esc) |
| `Space gc`                  | Browse repo commits; preview the diff through delta (side by side when the pane is wide) |
| `Space gh`                  | History of the current file; preview each commit's change to it       |
| `Space gB`                  | Toggle gutter base: whole-branch (vs main) ↔ working tree (vs index)  |
| `Space td`                  | Preview the hunk under the cursor inline (deleted lines in place)     |
| `Space dv`                  | Side-by-side diff against the gutter's base (fork point, or index)    |
| `ih` (x/o)                  | Text object: select the current git hunk (e.g. `dih`, `vih`)          |

### Forge (GitHub / GitLab — see the forge section below)
| Key                         | Action                                                                |
|-----------------------------|-----------------------------------------------------------------------|
| `Space gm`                  | Open (or create) the current branch's PR / MR                         |
| `Space gl` (n)              | Permalink (commit SHA) to the current line — opens + copies it        |
| `Space gl` (x)              | Permalink to the selected line range — opens + copies it              |

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
| `F2`                        | Toggle a terminal split (a dead shell is replaced with a fresh one)   |
| `Space go`                  | Open the file in the OS default app; in the file tree, the node       |
| `gcc` / `gc{motion}`        | Toggle comments (Neovim built-in, treesitter-aware)                   |
| `Space md`                  | Toggle in-buffer markdown rendering (formatted ↔ raw)                 |
| `Tab` (i, menu open)        | Confirm completion; else jump to next snippet placeholder             |
| `Shift-Tab` (i)             | Jump to the previous snippet placeholder                              |
| `Enter` (i, menu open)      | Confirm the explicitly selected item                                  |
| `Ctrl-Space` (i)            | Trigger completion manually                                           |
| `Ctrl-n` / `Ctrl-p` (i)     | Next / previous completion item                                       |

## Feature guides

**Incremental selection (`Option-Up` / `Option-Down` on macOS).** `Alt-Up` starts at the syntax node under the cursor and expands through larger parent ranges; `Alt-Down` shrinks through the selection history. Leading whitespace starts at the first nonblank character. Helm uses the injected YAML tree on YAML keys and the Go-template tree inside expressions. At the outermost node, further expansion keeps the selection unchanged. Leaving visual mode or editing resets the history; missing parsers leave the shortcut inactive.

YAML/Helm entry and block selections include the first line's leading whitespace and list marker; the initial scalar/word selection remains precise. Expanding a Helm entry includes its complete unquoted `{{ ... }}` value, and expansion from inside an expression passes through the enclosing YAML entry before larger blocks. Ancestors that produce the same visible selection are skipped, so shrinking retraces distinct selections without invisible steps.

**Indent scope highlighting.** indent-blankline draws a muted rose guide for the selected Treesitter scope, with scope start/end underlines disabled. For Kotlin, TypeScript/TSX, JavaScript/JSX, YAML (including chart values, compose and GitLab CI files), Lua and Python, custom lookup uses the cursor position (or the first nonblank character when in leading whitespace) instead of including the entire line prefix. In Lua a multi-line `{ ... }` table or call is a scope of its own (so inside a `vim.lsp.config("x", { ... })` spec the guide marks the table, not the enclosing function), and in Python so are multi-line dicts, lists, sets, tuples and calls; one-line literals are not. Helm uses the line anchor described below. Other filetypes keep the plugin’s default lookup.

- **Kotlin:** variable declarations, multiline calls and initializers, `try`/`catch`/`finally` blocks, and anonymous objects.
- **TypeScript / JavaScript / React:** declarations, multiline calls, objects, arrays, type/interface/class/enum bodies, and multiline self-closing JSX components, alongside the plugin's existing block and JSX scopes.
- **YAML:** guides anchor at the owning mapping key or sequence item; flow mappings and sequences are also supported. Scope endpoints are trimmed to the last content line so trailing blank lines or a following sibling cannot pull the highlight left. For `kafka → repository → image`, the guide on `image` aligns with `repository`.
- **Helm templates:** the injected YAML uses the same scope handling. Lookup anchors at the first nonblank character of each line so moving into `{{ ... }}` inside a YAML value keeps the surrounding mapping/list guide. Template-only directives do not get a separate Go-template scope guide.
- In these languages, inline calls, objects, and callbacks fall back to the enclosing multiline scope so they do not hide its guide. Kotlin variable declarations remain selectable even on one line.

Configured in [lua/plugins/ui.lua](lua/plugins/ui.lua), with cursor lookup and scope selection in [lua/tajbanana/indent_scope.lua](lua/tajbanana/indent_scope.lua). Restart Neovim after changing these settings. Highlighting depends on Treesitter: parser errors, including plain YAML parsing of `{{ ... }}` templates, can affect nearby guides. The YAML customization applies to `yaml`, its compound filetypes (`yaml.helm-values`, `yaml.docker-compose`, `yaml.gitlab`), and the YAML injected into `helm` buffers; plain `gotmpl` keeps the plugin defaults. Selecting a scope does not guarantee a visible guide on a single-line declaration.

For a Helm template with misplaced guides, check `:set filetype?`: it should report `helm`. The rules in `lua/tajbanana/set.lua` recognize YAML and `.tpl` files under a chart's `templates/` directory when its parent contains `Chart.yaml` or `Chart.yml`; `*.yaml.gotmpl` and `*.yml.gotmpl` are also recognized. A chart's values files (`values.yaml`, `values-*.yaml`, `values_*.yaml`, `values.*.yaml` beside its `Chart.yaml`) get `yaml.helm-values`, so helm_ls attaches alongside yamlls (a `values.yaml` outside a chart stays `yaml`); `compose.yaml`, `compose.<name>.yaml`, `docker-compose.yml` and `docker-compose.<name>.yml` (either extension; not `composer.yml`) get `yaml.docker-compose`, and `.gitlab-ci.yml` / `*.gitlab-ci.yml` (either extension) get `yaml.gitlab`. Inside a chart's `templates/`, every YAML file is a helm template whatever its name. These compound filetypes still highlight, format and indent-guide as YAML. Helm guides require the Helm parser and its YAML injection queries; they do not depend on `helm_ls` resolving values. See [the design notes](docs/design-decisions.md#indent-guides-yaml-and-helm-scope-boundaries) for the rendering fix.

**Messages & notifications.** `cmdheight=0` gives the command line's row back to the editor, which used to mean any multi-line message raised a "Press ENTER" prompt. Now `vim.notify` messages (lint results, the Kotlin updater, forge links) appear as [fidget](https://github.com/j-hui/fidget.nvim) toasts in the bottom-right corner, and other messages go through Neovim 0.12's experimental `ui2` message window, which collapses long output instead of prompting. `g<` shows the full message history; `Esc` dismisses the message window. Toasts do **not** land in `:messages` — `:Fidget history` lists past notifications.

**Completion & snippets.** As you type, nvim-cmp suggests from the LSP, snippets, and the current buffer. `Tab` is the do-everything key: it confirms the highlighted suggestion, and once you've expanded a snippet it jumps through the placeholders (`Shift-Tab` goes back). `Enter` confirms only when you've actively selected an item. Snippets come from [friendly-snippets](https://github.com/rafamadriz/friendly-snippets) (~2k across languages) — the IntelliJ "live template" equivalent.

**Inlay hints** show inferred types and parameter names inline (IntelliJ-style). They're on by default wherever the language server supports them — **TS/TSX/JS, Lua, Go, Rust, Kotlin, Java** — and toggle per buffer with `Space ti`. Python (pyright) and Bash (bashls) don't provide them.

**LSP status in the statusline.** Beside the filetype, the statusline shows whether the language server for the current file is up: **✓** (green) once the server has attached *and finished loading*, **⟳** (yellow) while it's still indexing, **✗** (red) when a server is expected but hasn't attached, **⏱** (red) for the specific case of an expired kotlin-lsp build (see [Troubleshooting](#troubleshooting)), and **○** (grey) for filetypes with no configured server. It waits on LSP work-done progress, so `✓` means genuinely ready rather than merely attached — a slow server like Kotlin or Java reads `✗ → ⟳ → ✓`. Only each filetype's primary server counts (a `.tsx` buffer draws ts_ls, eslint and graphql; the indicator tracks ts_ls), so secondary clients can't make it flicker. Lives in `lua/tajbanana/lsp_status.lua`; add a language by extending the `PRIMARY` table there to match `ensure_installed`.

**The `Space gd` picker** merges definition, type-definition, implementation, and references into one Telescope list, tagged and color-coded (`[def]` `[type]` `[impl]` `[ref]`). It opens in normal mode (`j`/`k`, `Enter` to jump); press `i` and type any of those words to filter. It queries every attached language server, so it works even in buffers with several (e.g. a `.tsx` with ts_ls + eslint + graphql).

**Repo-wide diagnostics (`Space xr`).** LSP servers only diagnose files you've opened, so `Space xx` can't show problems in files you've never visited. `Space xr` runs the project's actual linter over all of the project's files and loads the results into the Telescope picker. It lints the **nearest project** containing the current file — the closest ancestor directory with a marker, never above the git root — so in a monorepo you get the sub-project you're working in (all of a tool's markers count equally, so a nearer `tsconfig.json` beats a repo-root `package.json`). Helm's "yaml: line N" counts lines of the *rendered* template and is labelled as such. The tool is picked by marker: **Go** → `golangci-lint` (else `go vet`), **Rust** → `cargo check`, **Python** → `ruff`, **JS/TS** → the local `node_modules/.bin/eslint` in JSON mode (falls back to `tsc`; looked up from the project up to the git root, so tools hoisted to a workspace root are found), **Helm chart** (`Chart.yaml`) → `helm lint`, a `.yamllint` config → `yamllint`, **Dockerfile** → `hadolint`. One tool runs per press; when several markers sit at the same depth, the order above decides. Add more in `lua/tajbanana/repo_diagnostics.lua`.

**Viewing images.** Open a `.png` / `.jpeg` / `.gif` / `.webp` and [snacks.nvim](https://github.com/folke/snacks.nvim) renders it inline — this needs `enable_kitty_graphics = true` in `.wezterm.lua` (WezTerm ships with the protocol off). ImageMagick handles format conversion (see Prerequisites). `.svg` files intentionally open as their XML source instead — SVG rasterization proved unreliable on WezTerm stable, and the markup is usually what you want anyway; use the browser for visual SVG review. (snacks' *document* image preview — the float that popped up on image links inside markdown — is disabled, since WezTerm can't render it inline.)

**Viewing markdown.** Open any `.md` file and [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) renders it in the buffer — headings get icons, `#`/`**`/backticks are concealed, code blocks get a background, and lists and tables are drawn — while staying editable (the line under your cursor and insert mode fall back to raw source). `Space md` toggles rendering off/on.

**Git workflow.** For anything beyond a quick hunk preview, `Space lg` opens **lazygit** — stage/unstage with `Space`, commit with `c`, browse branches, and view diffs (range-select a span of commits with `v`, or diff two arbitrary commits with `W`). Inline, gitsigns shows changes in the sign column (add=green, change=blue, delete=red); `Space pp`/`oo` jump to the next/previous hunk and pop a diff preview of it, which clears as soon as you move the cursor or press `Esc`.

**Whole-branch gutter (IntelliJ-style).** By default the sign column diffs each file against the point where your branch forked from `main` (the merge-base), not against the last commit — so every line you've changed anywhere on the branch stays marked, *even after you commit it*. This mirrors IntelliJ's per-branch change view. `Space gB` toggles the current buffer back to the plain working-tree view (diff vs the index, i.e. only your uncommitted edits) and back again. Notes: gitsigns keeps one base per buffer, so committed-on-branch and still-uncommitted lines share the same sign — the colour encodes the *type* of change, not whether it's committed. Whenever HEAD moves — a branch switch, a rebase onto a newer `main`, a reset; in nvim, in the F2 terminal or anywhere else — every open buffer is moved to the new fork point automatically (the repo's git dir is watched, and the check runs in the background), unless you toggled that buffer to the working-tree view; that choice survives `:e`. If only `main` moves in a way that changes the fork point (e.g. part of your branch was merged into it), re-open the file or toggle twice. The reference tried is local `main`, then `master`, then `origin/main`/`origin/master` — so a single-branch clone or a `git worktree` checkout with no local `main` still works. Repos with none of those (a `develop`-only trunk, say) fall back silently to the working-tree view, and `Space gB` then says so. Files outside git have no git signs, so `Space gB` does not exist there.

## Repo layout

- `init.lua` — loads core settings, then bootstraps lazy.nvim
- `lua/tajbanana/set.lua` — core Vim options and global keymaps (leader = Space); initializes core helpers. Plugin-specific helpers are loaded by their plugin specs
- `lua/tajbanana/` modules — reusable feature helpers: `forge.lua` (**forge shortcuts**, GitHub/GitLab auto-detected, see below), `platform.lua` (OS detection), `system_open.lua` (the `Space go` / forge OS launcher), `repo_diagnostics.lua` (the `Space xr` repo-wide linter), `env.lua` (node/cargo PATH fixes and the SDKMAN JDK override), `terminal.lua` (F2 terminal toggle), `kotlin_update.lua` + `kotlin_update_prompt.lua` (`:KotlinLspUpdate` / `:KotlinLspRollback`), `completion.lua` (an intentionally *unwired* paren-skip experiment — see its header), `incremental_selection.lua` (`M-Up`/`M-Down` node selection), `gitutil.lua` (shared git-root helper), `git_pickers.lua` (the `Space gc`/`gh` commit-history pickers), `flow_pragma.lua` (the Flow `@flow` check behind ts_ls's veto), `definition_picker.lua` (the `Space gd` picker), `inlay_tint.lua` (per-kind inlay colouring), `lsp_status.lua` (the statusline LSP-load indicator), `indent_scope.lua` (custom cursor/scope lookup, initialized from `ui.lua`), `tailwind_root.lua` (when tailwindcss starts)
- `lua/plugins/` — one lazy.nvim spec file per concern: `lsp`, `telescope`, `colorscheme`, `treesitter`, `formatting`, `editor`, `git`, `ui`, `kotlin`, `snacks`, `markdown`, `lazy` (pins lazy.nvim itself to `lazy-lock.json`)
- `after/queries/` — custom Treesitter highlight queries per language
- `scripts/` — `update-kotlin-lsp.sh` + `kotlin-lsp-release.py` (the Kotlin LSP updater)
- `scripts/tests/` — regression checks (headless Lua + one offline Python suite); `bash scripts/tests/run_all.sh` runs them all
- `lazygit/config.yml`, `git/delta.gitconfig`, `starship.toml` — lazygit, terminal-git delta and shell-prompt configs (see [Symlinks](#symlinks))

## Also in this repo

**`.ideavimrc`** — IdeaVim config for IntelliJ. It shares a few of these bindings (leader = Space) but is **not** a full mirror — several keys map to IntelliJ's own actions and some differ from the nvim setup. Symlink it:

```
ln -s ~/.config/nvim/.ideavimrc ~/.ideavimrc
```

**`.wezterm.lua`** — WezTerm terminal config, cross-platform. It branches on `wezterm.target_triple`: a 15pt editor font (14pt tab bar) on macOS and Linux, 12pt for both on Windows, where the display scale differs:

- **macOS** — translates `Cmd`/`Option` chords into keys nvim can see.
- **Windows** — the same chords remapped to `Ctrl`/`Alt`, plus a `WSL:Debian` domain set as `default_domain` so panes open straight into WSL at `~`.
- **Linux (Debian and Fedora)** — uses `Ctrl`/`Alt` bindings and the native shell; no WSL domain. Both distributions share the Linux selection in Neovim's `tajbanana.platform` module as well.

Copy or symlink it to `~/.wezterm.lua` on macOS/Linux. On Windows, copy it to your **Windows** home (`C:\Users\<you>\.wezterm.lua`) — *not* the WSL home, since WezTerm runs on the Windows side.

For Neovim options that differ by OS, use `platform.pick({ linux = ..., mac = ..., windows = ... }, default)` or `platform.linux`; Debian and Fedora need no separate branch. WSL also counts as Linux, with an optional `wsl` entry taking precedence in `platform.pick`. Desktop file opening uses `xdg-open` on native Linux. Fonts, clipboard providers, and external tools must be installed on each machine; the theme and plugin settings are shared.

Two things that are easy to get wrong on Windows and fail silently:

- Use a **WSL domain**, not `default_prog = { 'wsl.exe', ... }`. The latter spawns wsl.exe as an opaque process, so WezTerm can't track a pane's working directory — which is exactly what the tab-title function reads.
- Set the domain's `default_cwd`. Without it, panes open in the Windows cwd (`/mnt/c/...`), i.e. the Windows filesystem over the 9p bridge, which is markedly slower for git than the distro's own ext4.

### Symlinks

```
ln -s ~/.config/nvim/.ideavimrc ~/.ideavimrc                  # IdeaVim
ln -s ~/.config/nvim/starship.toml ~/.config/starship.toml    # starship prompt (not Neovim)
ln -sfn ~/.config/nvim/lazygit/config.yml "$(lazygit -cd)/config.yml"   # terminal lazygit only
git config --global --add include.path ~/.config/nvim/git/delta.gitconfig
```

`Space lg` needs no link: lazygit.nvim always passes the repo's `lazygit/config.yml`. For *terminal* `lazygit`, `lazygit -cd` prints its per-OS config dir — `~/Library/Application Support/lazygit` on macOS, `~/.config/lazygit` on Linux/WSL — which is why a `~/.config/lazygit` link does nothing on a Mac. `git/delta.gitconfig` is *included*, not linked, so `git config --global` edits and this repo never overwrite each other.

## Forge shortcuts (GitHub / GitLab)

These keymaps work on **GitHub and GitLab**, including self-hosted instances. The forge is detected per buffer from the remote's host — so a GitHub checkout and a GitLab checkout on the same machine each get the right URLs. The host is matched by its dot-separated labels (`gitlab.example.com`, `github.acme.internal`); a self-hosted host without the vendor name in it (`git.thalesdigital.io`) needs a one-time per-repo `git config --local nvim.forge gitlab` (or `github`). SSH hosts are looked up with `ssh -G` (using the `-F` file from `GIT_SSH_COMMAND`/`core.sshCommand` when one is given). The `HostName` is used when the host is an alias — no dot (`work-gitlab`), a last label that is not a domain ending (`github.com-work`), a sub-domain of github.com / gitlab.com (`work.github.com`) — or when the `HostName` is github.com / gitlab.com (`github.personal`). Any other name is used as written, even if `~/.ssh/config` gives it another `HostName` (often a dedicated ssh host or an IP for the same forge). IP addresses and one-word intranet names without a `HostName` are real hosts and are used as written; a dotted alias with no `HostName` is refused rather than linked as itself. Other forges (Bitbucket, Gitea) report "Unsupported forge" rather than producing a wrong link. They live in `lua/tajbanana/forge.lua`; delete the `require("tajbanana.forge").setup()` line in `set.lua` to disable them, or add a `FORGES` entry to support another host.

`<leader>gm` prefers the forge's own CLI when it's installed — [`gh`](https://cli.github.com/) for GitHub, [`glab`](https://gitlab.com/gitlab-org/cli) for GitLab. Either looks the change request up by head branch via the API, which is robust to the local branch SHA drifting from the pushed head. If the CLI isn't installed it falls back to a token-free `git ls-remote` lookup (no CLI, no API token), which works because both forges publish change-request heads as fetchable refs. `<leader>gl` is always token-free. To set the CLI up: install it, then `gh auth login` (or `glab auth login`).

Resolving a branch's change request is a network round-trip to the forge (~1–2s, mostly latency — the call is async, so nvim never blocks). With `gh`/`glab` installed, `<leader>gm` shows a brief "Looking up pull request…" (or "merge request…") while it resolves, then opens the PR (or the compare/create page if there's none yet). It resolves fresh every time, so a just-created PR is always picked up.

`<leader>gl` builds a **permalink**: the URL names the commit SHA, not the branch, so a link pasted into a review keeps pointing at the same code after more commits land. It opens the link and copies it to the clipboard. It refuses (with a message) when HEAD is not on the remote yet, or the file is not committed, since either link would 404 — commit and push first; it works on a detached HEAD (linking via `origin`) and through a symlink into the repo (e.g. `~/.ideavimrc`); it only says "copied" after reading the clipboard back (on Linux/WSL clipboard tools, once the copy has settled), and warns if it did not get there; and it warns when the file has uncommitted edits, because the line numbers then come from your working tree rather than the linked commit.

## Diagnostics: one message per line

When several diagnostics land on the same line, Neovim draws a marker for each but prints only **one message** as virtual text. The config sets `severity_sort = true`, so the message shown is the **highest severity** on that line.

This matters more than it sounds. Unsorted — Neovim's default — the message is whichever diagnostic happened to arrive last, regardless of severity. On real Kotlin like `if (left < right) {}` the server reports two errors (unresolved `left`, unresolved `right`) *and* a warning (empty `if` body) all on that one line, and the **warning's** text was displayed: a file that does not compile looked merely warned-about.

The markers still show the true picture — count the `■` glyphs, or check the gutter sign and the statusline counts. `Space e` shows every diagnostic on the current line in a float, and `Space xb` lists them all in Telescope.

## Opening files in the OS default app (`Space go`)

`Space go` hands the current file to the desktop's default handler — `.html` opens the browser, `.pdf` the viewer, and so on. In the file tree it opens the file or folder under the cursor. It only ever hands over a real path on disk: in terminal, scratch or other special buffers it says "Not a file on disk" instead (on WSL, `explorer.exe` given a bogus path silently opened its default folder). The forge shortcuts (`Space gm` and `Space gl`) use the same launcher. It works on **macOS, WSL and Linux** (plus a `cmd.exe start` launcher for native Windows nvim), but the environments are genuinely different and the config picks the launcher itself rather than delegating to `vim.ui.open`:

| platform | launcher | path passed | exit code |
|---|---|---|---|
| macOS | `open` | POSIX | 0 on success |
| WSL | `explorer.exe` | **Windows** path, via `wslpath -w` | always 1, even on success — ignored |
| Linux | `xdg-open` | POSIX | 0 on success, 1–4 on failure |
| Fedora Toolbx | `flatpak-spawn --host xdg-open` | shared POSIX path or URL | host handler's exit code |
| native Windows nvim | `cmd.exe /c start ""` | Windows | non-zero reported |

Two reasons this is not left to `vim.ui.open`, both learned the hard way:

- **Its preference order is `xdg-open` → `wslview` → `explorer.exe`**, so `explorer.exe` is a *fallback*, not the WSL rule. Installing `wl-clipboard` (to fix the system clipboard) pulled in `xdg-utils` as a dependency, which put `xdg-open` on `PATH` and moved nvim's choice onto it. On a WSL box with no desktop session and no registered MIME handler, `xdg-open` exits 4 for *every* file — so `Space go` broke with no change to this config at all.
- **It launches detached and never reports the exit code.** Its error return is non-`nil` only when *no* handler exists, so a launcher that runs and then fails is invisible. That is why the breakage above went unnoticed.

The launcher and the path format are therefore chosen together — converting the path to Windows form and then letting something else pick the launcher was the original bug — and a non-zero exit is now reported as an error toast instead of being swallowed. WSL is exempt from that check because `explorer.exe` returns 1 even when it succeeds.

If a shortcut does nothing on native Linux, run `xdg-open <file-or-url>` in a shell. Inside Fedora Toolbx, test `flatpak-spawn --host xdg-open <file-or-url>` instead; the host bridge is necessary because rpm-ostree applications and their desktop entries are outside the container.

## LSP servers and formatters

LSP servers are listed in the `servers` table in `lua/plugins/lsp.lua` and installed automatically by Mason. That list is also the **only** set of servers that get enabled — installing something else through `:Mason` does not make it attach — so to add a server, add it there. tailwindcss starts only in Tailwind projects (a `tailwind.config.*` file, a `package.json` / `deno.json` that mentions `tailwindcss` (usually as a dependency) — including a monorepo root — or a postcss config / `mix.lock` / `Gemfile.lock` that mentions tailwind; Django's `theme/static_src/` counts too). A server Mason would have to build with a toolchain the machine lacks (`npm` for the node-based ones, `go`, `python3`, `cargo`) is not auto-installed, so it isn't retried and failed on every start; one that is already installed is kept. gopls is neither installed nor enabled on a machine without Go. Per-server settings (inlay hints, etc.) also live in `lsp.lua`. **Kotlin is the one exception:** it is managed by [kotlin.nvim](https://github.com/AlexandrosAlexiou/kotlin.nvim) in `lua/plugins/kotlin.lua` and is deliberately **not** in `ensure_installed` — its `intellij-server` is a time-bombed build that expires monthly and Mason's registry lags JetBrains, so it is self-managed at `~/.local/share/kotlin-lsp/current` via `KOTLIN_LSP_DIR` (see [Troubleshooting](#troubleshooting) for how to refresh it).

Node-based servers need `node` on PATH — since nvm is often lazy-loaded (so `node` isn't on PATH at startup), `lua/tajbanana/env.lua` prepends the nvm node that nvm's `default` alias resolves to (the newest installed one when the alias is unset or unusable). The same fix is why `Space xr` and node-based formatters work.

Formatters are configured per-filetype in `lua/plugins/formatting.lua` (conform.nvim): stylua (Lua), prettier (JS/TS/JSON/YAML/CSS/HTML/Markdown), ktlint (Kotlin), ruff (Python: organize imports + format), goimports + gofumpt (Go), shfmt (sh/bash). mason-tool-installer, in the same file, installs them — and the `Space xr` linters — automatically on every machine that has the toolchain to install them (`go`, `npm`, python3 with venv); `:MasonToolsClean` is disabled because it would uninstall every LSP server. Formatting is on-demand with `<leader>gf`, not on save; for filetypes without a dedicated formatter it falls back to the LSP's own formatting.

## Customizing colors

The colorscheme is onedark.nvim with a Material Darker-inspired palette and extensive Treesitter/LSP highlight overrides in `lua/plugins/colorscheme.lua`.

Put the cursor on any token and run `:Inspect` to see its Treesitter/LSP highlight group, then add or edit the corresponding entry in `colorscheme.lua`. Use `:Inspect` liberally — it's the fastest way to find the right group to override.

## Troubleshooting

**Kotlin: `Space gd`, hover, and completion silently stop working — nothing attaches.** The JetBrains `intellij-server` binary behind kotlin-lsp is a time-limited **EAP build that expires roughly monthly**. Once it lapses it still launches, prints an expiry notice, and exits *before* initializing — so the client never attaches and none of the `LspAttach` keymaps (`Space gd` among them) ever bind. You get two tells: the statusline shows a red **⏱** beside the `kotlin` filetype (instead of the usual ✗) and, ~10s after opening a Kotlin file, a floating prompt shows the failed LSP version and installation source, looks up the proposed GitHub version, and asks whether to update — press **`y`** and it runs `:KotlinLspUpdate` for you (see below). Confirm the cause in `:LspLog` (or `~/.local/state/nvim/lsp.log`):

```
Client kotlin_lsp quit with exit code 7 ...
"stderr"    "This build of intellij-server has expired. The IDE will now close."
```

**`:MasonInstall kotlin-lsp` does _not_ fix this.** Mason's registry trails JetBrains by weeks and usually only re-offers the same expired build. kotlin-lsp is therefore **self-managed** outside Mason: the current build lives at `~/.local/share/kotlin-lsp/current` — a symlink that `lua/plugins/kotlin.lua` hands to kotlin.nvim as `KOTLIN_LSP_DIR`, so every launch — in every open Neovim — runs whatever `current` points at, and an update or rollback is picked up by the next start.

**Checking versions.** The build you currently have installed:

```sh
readlink ~/.local/share/kotlin-lsp/current        # -> …/kotlin-server-<build>
cat ~/.local/share/kotlin-lsp/current/build.txt    # -> ILS-<build>
```

In a Kotlin buffer, inspect the running client's reported version and command with:

```vim
:lua for _, c in ipairs(vim.lsp.get_clients({ name = "kotlin_lsp" })) do vim.print({ server = c.server_info, command = c.config.cmd }) end
```

**Expiry popup.** The popup labels the proposed replacement as pending an expiry check. Looking up that version fetches only GitHub metadata; downloads and server checks start when you press `y`. New downloads record their source (GitHub or Open VSX) beside the server. Older self-managed installs without that record show an unknown source rather than guessing. Expiry log entries for a different installed version are ignored — including an old build's expiry logged before `current` was last repointed.

**Update source order.** The updater prefers the [latest GitHub release](https://github.com/Kotlin/kotlin-lsp/releases/latest). It reads the platform's archive and SHA-256 links from the release metadata, verifies the download, and tests LSP initialization with temporary configuration, cache, and log directories and no project. An already-installed candidate is also checked: matching version numbers do not prove that a build is still valid.

**Confirmed fallback workflow.**

1. If Kotlin LSP fails to attach and logs an expiry message, the first popup shows the failed version/source and previews the latest GitHub replacement version.
2. Press `y` to download the GitHub server, verify its SHA-256, and test initialization in isolation. An installed candidate can be reused, but still undergoes the startup check.
3. Only an explicit `intellij-server has expired` or `kotlin-server has expired` response allows an Open VSX alternative. The updater reads the latest extension's `server-bundle.json` to find its server version, archive URL, and checksum. This fetches the extension package for metadata; the server archive is not downloaded yet.
4. A **second popup** shows the expired GitHub version, the failure reason, and the proposed Open VSX server version/source. (If that Open VSX build is already your current one -- after an earlier fallback -- there is no popup: it is checked and reported up to date. A GitHub build found expired once is remembered and not downloaded again.) Press `y` again to download and validate that exact candidate. Press `n`, `q`, or `Esc` (or close the popup) to dismiss and keep the installation unchanged.
5. Only after validation succeeds does the updater install the build, atomically repoint `current`, and restart Kotlin LSP. The statusline returns to its normal loading/ready state when the server attaches.

**Failure safeguards.** Network errors, checksum mismatches, unrelated startup errors, and the 45-second startup timeout offer **retry/dismiss**, without automatically changing sources. Retry starts the GitHub-first workflow again; an Open VSX download always requires its own confirmation. If Open VSX offers the same expired version, there is no second download prompt. If both candidates explicitly expire, the updater reports that no usable alternative is available. Build age is never treated as proof of expiry. All candidate-validation failures preserve the existing installation.

**Overlapping updates.** An in-editor guard blocks another update while downloading, waiting for either confirmation/retry, or restarting. An OS file lock also blocks competing updaters from other Neovim instances or terminals, including while the second confirmation is pending. The OS releases the lock when the updater exits; the `.update.lock` file itself may remain and does not mean an update is active. Metadata-only previews do not take this lock. Async confirmation and retry popups wait for normal mode so they do not consume typing keystrokes.

**Easiest — `:KotlinLspUpdate`.** Run `:KotlinLspUpdate` from any buffer — it exists before you open a Kotlin file. It runs `scripts/update-kotlin-lsp.sh`, installs the validated candidate, repoints `current`, and reattaches the server in place, with progress in a **fidget** bar. It also handles first-time installation. A valid GitHub release takes priority even if Open VSX offers a higher build number. If the chosen build is already current and passes the check, no installation is performed.

**Rolling back — `:KotlinLspRollback`.** Each update keeps the build it replaced as `~/.local/share/kotlin-lsp/previous` (older builds are pruned, about 1 GB each — but not while a server launched through a `current` path is running, nor when `current` was broken before the update; that cleanup waits for a later update. A build a running server was started from directly is kept). If a new build starts but misbehaves, `:KotlinLspRollback` probes the previous build and, if it still starts, swaps `current` and `previous` and reattaches — run it again to swap back. It refuses when there is no previous build (or it already is the current one), or when the previous build has itself expired (the usual case after an expiry-driven update); a failed swap leaves both links as they were. It shares the updater's in-editor guard and cross-process lock; from a shell: `bash scripts/update-kotlin-lsp.sh rollback`.

The script **auto-detects OS and arch** (macOS and Linux/WSL, arm64/x64) and pulls the matching asset, so the same command works on either machine — each box just needs its own one-time `:MasonUninstall kotlin-lsp` + first run, and `curl`, `unzip`, and `python3` on `PATH`. To **preview the expiry prompt** yourself without waiting for a real expiry, run `:lua require('tajbanana.lsp_status')._prompt_expired()` (press `y` in the float to run the update, `n`/`Esc` to dismiss); or check the whole flow from a shell with `bash ~/.config/nvim/scripts/update-kotlin-lsp.sh`, which prints `UP-TO-DATE …` or `UPDATED …`.

From a terminal, `bash ~/.config/nvim/scripts/update-kotlin-lsp.sh` also asks before the Open VSX server download. Without an interactive terminal it declines fallback rather than assuming consent. `--preview` fetches only the GitHub candidate metadata. Neovim uses `--interactive` to receive the second-confirmation marker and reply over stdin.

The manual Open VSX extraction steps below are a troubleshooting reference; they do not provide the updater's confirmation, startup validation, or locking safeguards:

**To update to a fresh build (manually):**

1. **Find the newest build.** JetBrains' GitHub *releases* and Mason both lag; their **Open VSX `kotlin-server` extension** pins the current build first. Ask the registry for the latest extension version, then read the `server-bundle.json` inside its platform `.vsix` — the `.vsix` is a small zip that *references* the server rather than bundling it, and `server-bundle.json` names the build number, the `.sit` download URL, and its sha256:
   ```sh
   # latest extension version:
   curl -s https://open-vsx.org/api/JetBrains/kotlin-server \
     | python3 -c 'import sys,json;print(json.load(sys.stdin)["version"])'
   # read that version's bundle manifest (darwin-arm64 shown; x64 drops "-aarch64"):
   V=<version-from-above>
   curl -sL "https://open-vsx.org/api/JetBrains/kotlin-server/darwin-arm64/$V/file/JetBrains.kotlin-server-$V@darwin-arm64.vsix" -o /tmp/k.vsix
   unzip -p /tmp/k.vsix extension/server-bundle.json
   ```
2. **Download, verify, and extract** the `.sit` (it is a zip, *not* a tarball) into `~/.local/share/kotlin-lsp/`, using the build number, URL, and sha256 from the manifest:
   ```sh
   B=<build-from-bundle>            # e.g. 263.4421.0
   curl -L -o /tmp/kls.sit "https://download-cdn.jetbrains.com/language-server/kotlin-server/$B/kotlin-server-$B-aarch64.sit"
   echo "<sha256-from-bundle>  /tmp/kls.sit" | shasum -a 256 -c -    # must print: /tmp/kls.sit: OK
   mkdir -p ~/.local/share/kotlin-lsp
   ditto -x -k /tmp/kls.sit ~/.local/share/kotlin-lsp/              # or: unzip -q /tmp/kls.sit -d ~/.local/share/kotlin-lsp/
   ```
3. **Repoint the symlink** and restart Neovim — the whole fix once the build is on disk:
   ```sh
   ln -sfn ~/.local/share/kotlin-lsp/kotlin-server-$B ~/.local/share/kotlin-lsp/current
   ```

**First time only** (fresh clone or new machine): `:KotlinLspUpdate` performs the
initial install; done by hand, the three steps above *are* the initial install —
they create `~/.local/share/kotlin-lsp/` and the `current` symlink. Additionally run `:MasonUninstall kotlin-lsp` once, so `kotlin.nvim`
resolves your self-managed dir instead of a leftover Mason copy (it probes
`$MASON` first), then restart Neovim.

This **recurs** every ~30 days; the ⏱ (or the exit-code-7 log line) is the tell. (Because `Space gd` is wired in the `LspAttach` autocmd in `lsp.lua`, *any* server that fails to attach takes its keymaps down with it — the same log check applies to other languages too.)

**`:MasonInstall` / `:Mason` → `E492: Not an editor command`.** The LSP stack is loaded at startup (`lazy = false`), so Mason commands should be available even before opening a file. Check `:messages` for startup errors and `:Lazy` for missing or failed plugins; opening a file is not required to register these commands.

**Mason installs fail when two Neovim instances install at once.** Don't let two instances run Mason installs concurrently (e.g. opening two windows on a fresh machine, where both start the auto-installs). Mason wipes a package's staging dir (`~/.local/share/nvim/mason/staging/<package>`) when an install starts, which is how the original setup lost an in-flight build; current Mason also takes a per-package lockfile, so the second instance now fails with *"Lockfile exists, installation is already running in another process"*. Let one instance finish — anything that failed is retried on the next start. If nvim was killed mid-install and the lock is left behind, run `:MasonInstall --force <package>`.

**Kotlin diagnostics never appear, even though the LSP is attached.** kotlin-lsp publishes **nothing on open** — it only analyses after the document changes. Measured: a correctly-attached client sat at zero diagnostics for **9 minutes**, then produced all of them the moment a single edit landed. So "wait longer" is the wrong remedy; type a character and delete it (`i`, space, `Backspace`, `Esc`) and they arrive within seconds. Confirm with `:lua =#vim.diagnostic.get(0)` before and after.

**Kotlin's first open is slow, or `Space gd` finds nothing right after opening.** kotlin-lsp runs a full Gradle import and indexes the project before features light up — a few minutes on a cold project, and it needs network to resolve dependencies. The client attaches quickly but returns nothing until indexing finishes. If it stays broken after that (stale workspace state or a leftover analyzer lock), clear the workspace and reopen:

```
:KotlinCleanWorkspace
```

Only one kotlin-lsp runs at a time machine-wide: a second `intellij-server` (even for a different project) can die instantly on the shared analyzer-cache lock, so close other Kotlin sessions if a project won't come up.

**Kotlin: `:LspLog` fills with FIR resolve errors (`-32803`, `CONSTANT_EVALUATION → BODY_RESOLVE`).** These come from kotlin-lsp's semantic-tokens provider reading a corrupted analyzer cache (the first time, 401 of them, left over from an earlier run of crashes). Quit Neovim, wipe both caches and let the project re-index:

```sh
rm -rf ~/.cache/kotlin-lsp-workspaces ~/Library/Caches/JetBrains/analyzer   # macOS paths
```

That brought the count to zero. If they come back on a clean cache, it is a server bug worth reporting to [Kotlin/kotlin-lsp](https://github.com/Kotlin/kotlin-lsp/issues). (Background: [docs/2026-07-19-tooling-overhaul.md](docs/2026-07-19-tooling-overhaul.md).)

## Validating changes

There is no build step. Run every regression check with:

```sh
bash scripts/tests/run_all.sh
```

It runs each `*.lua` and `*.py` file in `scripts/tests/` using the `Run:` command on its first line and prints a pass/fail summary (non-zero exit on any failure): completion, incremental selection, indent scope, inlay tint, the Kotlin update popup/prompt/flow and `KOTLIN_LSP_DIR` resolution, repo lint, the `Space gl` permalink guards, tailwind root detection, the F2 terminal toggle, the whole-branch gutter (against real gitsigns and throwaway repos), which Kotlin build a launch/restart/first install really runs (real kotlin.nvim), the Kotlin expiry check, the statusline's toolchain gates, `set.lua`'s filetype rules and keymaps, the Flow pragma check, the `Space gd` picker, the `Space gc`/`gh` commit previews, parser installs mid-session, and the offline Kotlin updater suite (Python). The repo-lint suite says which tool-gated checks it skipped when golangci-lint or hadolint is not installed. `treesitter_install.lua` needs the `json` treesitter parser installed (it stands in for a parser that "arrives" mid-session). To verify things work interactively:

1. `:messages` — check for startup errors
2. `:checkhealth` — verify plugin health
3. `:Lazy` — plugin status / sync
4. `:LspInfo` — verify LSP server attachment
5. `:lua =require("nvim-treesitter").get_installed()` — list installed Treesitter parsers

Run the committed indent scope regression checks from this repository after installing indent-blankline and the Kotlin, TypeScript, TSX, YAML, Lua, Python and Helm parsers (including Helm’s inherited Go-template queries). This harness currently looks in `~/.local/share/nvim/lazy/indent-blankline.nvim` and `~/.local/share/nvim/site`; custom data/install paths need corresponding changes in the harness (`whole_branch.lua` likewise loads gitsigns from lazy's install dir):

```sh
nvim --headless -n -u NONE -i NONE -l scripts/tests/indent_scope.lua
```

For incremental selection, run `nvim --headless -n -u NONE -i NONE -l scripts/tests/incremental_selection.lua`. It requires the YAML and Helm parsers/queries in `~/.local/share/nvim/site` and checks expansion, shrinking, root stability, first-line indentation, complete Helm values, nested/multiline actions, UTF-8 endpoints, and missing-parser fallback. Fixture cursor sweeps verify that expansion contains the previous selection and shrinking restores it exactly.

The checks cover cursor positions in leading whitespace, nested multiline scopes, inline-call fallback, React props, YAML mappings/lists, Kotlin exception blocks, and unchanged cursor lookup for unrelated filetypes. YAML regression cases also inspect the rendered virtual-text overlay column with trailing blank lines and a following sibling. Helm cases check overlay columns while moving across keys, list entries, and embedded template expressions. These are headless checks, not terminal screenshot comparisons.

One-off project checks on 2026-09-16 sampled Kotlin, TypeScript/TSX, and YAML files in `kafka_apicurio`, `exploration-control-ui`, and `exploration-control-manager`. Those external projects and audit scripts are not part of the committed test suite. The checks exercised scope selection, not rendered guide placement; some TSX files and a YAML template had parser errors, so this was not a clean parse or visual-validation guarantee for every file.

A subsequent check of `kafka_apicurio/helm/kafka-lab/templates/kafka-depolyment.yaml` verified rendered overlay columns on metadata, selectors, labels, container images, and ports, including cursor positions inside template expressions. The committed Helm fixture covers the same mapping/list and embedded-expression behavior without requiring that external project.
