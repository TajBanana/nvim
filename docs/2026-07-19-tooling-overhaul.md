# 2026-07-19 — Language tooling overhaul: report

A single session took this config from "several silently broken subsystems"
to "verified working across 16 languages". This records what was broken, why,
what was changed, and how each fix was verified.

## Starting symptom

`<leader>gd` errored in a Kotlin buffer:
`Client kotlin_language_server quit with exit code 1`. Investigating that one
error uncovered four independent, silent breakages that had accumulated.

## Root causes found

### 1. Kotlin LSP crashed on JDK 25
The old fwcd `kotlin-language-server` (v1.3.13, unmaintained) throws
`IllegalArgumentException: 25.0.2` parsing the version string of the default
JDK (Corretto 25) and dies at startup — every attach since early July.

**Fix:** replaced it with JetBrains' official **kotlin-lsp** (`kotlin_lsp`,
Mason package `kotlin-lsp`, binary `intellij-server`) — built on the IntelliJ
analysis engine and targeting JDK 25. Managed via **kotlin.nvim**, which also
provides decompiled-source navigation, `:KotlinOrganizeImports`, inlay hints.
`kotlin_lsp` is excluded from mason-lspconfig `automatic_enable` because
kotlin.nvim enables it itself; a `cmd` override maps the old lspconfig name to
the `intellij-server` binary. The fwcd server was uninstalled to prevent
double-attach.

**Follow-up:** kotlin-lsp later threw FIR resolve errors
(`-32803`, `CONSTANT_EVALUATION → BODY_RESOLVE`) from its semantic-tokens
provider — 401 occurrences in its log. Wiping the analyzer caches
(`~/.cache/kotlin-lsp-workspaces`, `~/Library/Caches/JetBrains/analyzer`) and
re-indexing eliminated them (0 errors after). The cache had been corrupted by
the earlier crash era. If they return: file an issue on Kotlin/kotlin-lsp
(same family as their issue #144).

### 2. Every Node-based LSP died with exit 127
`.zshrc` lazy-loads nvm (for shell startup speed), so `node` is a shell
function and `~/.nvm/versions/node/*/bin` is not on PATH when nvim launches.
ts_ls, yamlls, jsonls, tailwindcss, eslint, cssls, html, dockerls all spawn
`#!/usr/bin/env node` scripts → `env: node: No such file or directory`.

**Fix:** `set.lua` prepends the newest installed nvm node's bin dir to PATH
when `node` isn't already executable. The same pattern was later applied for
rustup (`/opt/homebrew/opt/rustup/bin`, brew keeps toolchain proxies there).

### 3. Treesitter was entirely inert
Three stacked problems: (a) **zero parsers were installed** — the
nvim-treesitter *main* branch needs the `tree-sitter` CLI, which wasn't on
the machine, so every auto-install had failed silently; (b) the main branch
**doesn't auto-start highlighting** — the config never called
`vim.treesitter.start()`; (c) after plugins were updated, the kotlin parser
was **older than the plugin's queries** (`Invalid node type
"interpolation_expression_start"`), silently disabling kotlin highlighting.

**Fix:** `brew install tree-sitter-cli`; a `FileType` autocmd in
`treesitter.lua` that `pcall`s `vim.treesitter.start()`; parsers installed
synchronously (25 langs) and re-synced to the plugin's pinned revisions.
Highlighting had been coming from regex syntax + LSP semantic tokens all
along — which is also why the custom `Alt-Up/Down` incremental selection
(treesitter-node based) had been broken.

### 4. Missing languages entirely
The Documents sweep found real Rust (alphabet — 12k files), Python (agx,
skill-forge), Go, and Bash work with no LSP/parser support configured.

**Fix:** added `pyright`, `gopls`, `bashls`, `rust_analyzer` to Mason
`ensure_installed` + parsers (`python`, `go`, `bash`, `rust`, `markdown`).
Rust required installing the toolchain itself (`brew install rustup`,
`rustup default stable`) since rust-analyzer needs `cargo`/`rustc` to load a
workspace. Verified rust-analyzer hover works on an alphabet crate.

## Features added

- **Unified `<leader>gd` picker** — queries *all* attached LSP clients
  supporting each of definition/type-definition/implementation/references,
  merges + dedupes, and shows one Telescope list with colored kind tags
  (`[def]` yellow, `[type]` green, `[impl]` blue, `[ref]` purple — groups
  `GdTag*` in colorscheme.lua). Querying all clients matters: `graphql`
  attaches to tsx buffers claiming definition support and returns nothing.
- **New plugins:** fidget (LSP progress), which-key, trouble
  (`<leader>xx`/`xb`), telescope-fzf-native, telescope-ui-select (also
  upgrades `<leader>ca`), kotlin.nvim. `<leader>fw` switched to `live_grep`.
- **Formatting:** prettier wired into conform for JS/TS/TSX/JSON/YAML/CSS/HTML;
  stylua installed (was configured but missing).
- **TSX ↔ IntelliJ Material Darker color parity** — see
  `docs/tsx-intellij-color-parity.md` for the method (pixel-sampling
  screenshots), the resulting scheme, and known limits. Includes a custom
  treesitter query (`after/queries/tsx/highlights.scm`) for useState-setter
  declarations.
- **nvim-tree width** bounded to 25–45 cols (was unbounded adaptive).

## Verification methodology

Headless nvim probes against **real project files** for all 16 languages:
attach + client-alive checks, declared server capabilities per LSP function,
`vim.inspect_pos()`/extmark-priority checks for effective highlight colors,
direct `request_sync` calls for definition/hover, and pixel-sampling of
editor screenshots for color comparisons. Full confidence matrix delivered
in-session; headline: everything Verified/High except the known gaps below.

## Known gaps (deliberate)

- **Python formatting**: pyright doesn't format and conform has no python
  entry — `<leader>gf` is a no-op for Python. Candidate fix: ruff via Mason.
- **SQL**: sqlls offers completion/rename/code-action only — no
  hover/definition. Server limitation.
- **jdtls** registers capabilities dynamically during project import; first
  open on a cold project has a warm-up window.
- **Import-clause identifiers in tsx** can't be colored by resolved kind
  (ts_ls emits no semantic tokens there).

## Environment facts worth remembering

- Default JDK: Corretto 25 (17 and 11 also installed via `/usr/libexec/java_home -v 17`).
- nvm is lazy-loaded; node not on PATH at nvim start (handled in set.lua).
- rustup via brew: proxies live in `/opt/homebrew/opt/rustup/bin` (no `~/.cargo/bin`).
- tree-sitter CLI comes from `brew install tree-sitter-cli` (plain
  `tree-sitter` formula is lib-only).
- Mason installs must not run in two nvim instances concurrently — the shared
  staging dir gets cleared mid-build.
