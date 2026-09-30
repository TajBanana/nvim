# Design decisions




The *why* behind this config — the non-obvious decisions, what drove them, how they work, and what they cost. The [readme](../readme.md) covers *how to use* the config; this covers *why it is the way it is*. Read it when a choice here looks surprising, before changing it.

Each entry is **Context → Decision → How → Trade-offs**.

---

## Plugin manager: lazy.nvim (migrated from packer)

**Context.** The config originally used packer.nvim. Packer is unmaintained, compiles a `packer_compiled.lua` that drifts out of sync, and has no built-in lazy-loading ergonomics.

**Decision.** Migrate to [lazy.nvim](https://github.com/folke/lazy.nvim). Every file in `lua/plugins/` returns a spec table; lazy auto-discovers them.

**How.** `init.lua` loads core settings (`lua/tajbanana/set.lua`) first, then bootstraps lazy and calls `require("lazy").setup("plugins")`. Plugins lazy-load on `keys`/`cmd`/`event` triggers, so startup only pays for what a session actually uses.

**Trade-offs.** One concern per file means more files, but each is small and independently reasoned about. The old `packer.lua` and all `after/plugin/*.lua` were deleted — no dual system.

*Later:* lazy.nvim now pins itself. The bootstrap in `init.lua` clones the moving `stable` tag, which drifted from `lazy-lock.json` and left a dirty tree on first launch. It now checks the clone out at the lockfile's commit, and `lua/plugins/lazy.lua` sets `pin = true` so `:Lazy update` cannot bump it. `rocks = { enabled = false }` is set because no plugin needs luarocks, and leaving it on made `:checkhealth` report an error for the missing hererocks toolchain.

---

## LSP: the native `vim.lsp.config` API (not null-ls, not the old lspconfig setup)

**Context.** Neovim 0.11 introduced a first-class LSP configuration API (`vim.lsp.config` / `vim.lsp.enable`). The older pattern was `require('lspconfig').<server>.setup{}`; null-ls (now archived) was the common way to bolt formatters/linters onto the LSP client.

**Decision.** Use native `vim.lsp.config` with Mason + mason-lspconfig for install/enable, and conform.nvim for formatting (not null-ls). The LSP API alone needs 0.11+; the config as a whole now **requires Neovim 0.12+** (the nvim-treesitter `main` branch, `vim.diagnostic`'s `jump.on_jump`, and `ui2`).

**How.** `lua/plugins/lsp.lua` sets a wildcard `vim.lsp.config("*", { capabilities })` for cmp capabilities, then per-server overrides. (*Later, 2026-09-29:* on a first start, before Mason has downloaded its registry, the toolchain gate below let every server through; a built-in table of the configured servers' source kinds is used until the registry exists.) Servers are enabled by `mason-lspconfig` from an **allow-list** — `automatic_enable` is the same `servers` list as `ensure_installed` (minus `rust_analyzer` without a Rust toolchain and `gopls` without Go) — and Kotlin is left to its own plugin (see below). `ensure_installed` additionally skips any server Mason would have to *build* with a toolchain the machine lacks — npm for the ~11 node-based servers, go, python3 (pypi), cargo — read from the package's Mason source id (`pkg:npm/…`), so a machine without npm no longer retries and fails those installs on every start; an already-installed server is kept.

**Why an allow-list.** The default `automatic_enable` turns on *every* Mason package lspconfig recognises, so whatever happened to be installed attached: leftover emmet_ls (html/css/jsx/tsx), gradle_ls and sqlls from `:Mason` experiments, and the stylua *formatter* — installed for conform — whose lspconfig `lsp/stylua.lua` wrapper started `stylua --lsp` as a second formatting provider on every Lua buffer. The previous exclude list had to chase each of those; an allow-list makes the config the only thing that decides which servers run. tailwindcss is in the list but its `root_dir` is overridden (`lua/tajbanana/tailwind_root.lua`): upstream's markers are kept *except* the final bare `.git` fallback, which spawned a ~97 MB server on every README in every repo. So the root is a `tailwind.config.*` (or Django's `theme/static_src/tailwind.config.*`), a `package.json` / `deno.json` mentioning `tailwindcss` (Tailwind v4 has no config file), or — only when the file mentions tailwind — a postcss config (v4's `@tailwindcss/postcss`, also under Django's `theme/static_src/`), `mix.lock` (Phoenix) or `Gemfile.lock` (Rails). A bare postcss config (plain autoprefixer) does not start it. It is **one upward walk** checking every marker at every level, nearest directory first: lspconfig's `insert_package_json` / `root_markers_with_field` each stop at the first file of a kind they find, so combining them lost projects — a tailwind-free postcss config hid the Rails `Gemfile.lock` beside it, a sub-package's `package.json` hid a monorepo root that depends on tailwind, and Django's `theme/static_src/postcss.config.js` was looked up by its bare name. The walk stops at the repository root (the directory holding `.git`), which the dropped `.git` marker used to provide. Outside git it stops below `$HOME` for a file under `$HOME`, so a `~/package.json` that mentions tailwindcss cannot root the server at `$HOME`. *(Corrected 2026-09-29: this said the walk "never checks `$HOME` or anything above it" in general; a file outside both `$HOME` and git is walked up to `/`, as upstream does.)* Regression checks: `scripts/tests/tailwind_root.lua`.

**Trade-offs.** Ties the config to recent Neovim (0.11+ for this API, 0.12+ overall). In exchange: no archived dependencies, less indirection, and server settings live in one obvious place.

---

## The nvm PATH fix (why node-based tooling would otherwise be dead)

**Context.** nvm is *lazy-loaded* in the user's `.zshrc`: `node`/`npm`/`npx` are defined as **shell functions** that source nvm on first call. This keeps shell startup fast — but it means node is **not on `PATH`** when a GUI/terminal launches nvim.

**Decision.** In `lua/tajbanana/env.lua` (called from `set.lua`), if `node` isn't executable, pick an `~/.nvm/versions/node/*/bin` and prepend it to `vim.env.PATH`. The version chosen is the one nvm's own `default` alias resolves to — following the alias chain (`default` → `lts/*` → `lts/hydrogen` → `v18.20.4`) up to a few hops — falling back to the *newest* installed version when the alias is unset, non-numeric (`node`, `stable`), or names a version that isn't installed.

**How & why it's necessary.** Shell **functions are not inherited by child processes** — only exported env vars and real `PATH` entries cross the process boundary. When nvim spawns an LSP server (or `eslint`/`tsc` via `vim.system`), it execs the real binary or a non-interactive shell that never sourced the `.zshrc` function. So the lazy-load stub is invisible, and without the fix node-based Mason servers die with exit 127. The fix puts a **real** node directory on nvim's `PATH`, inherited by every subprocess. This is also why `<leader>xr`'s eslint/tsc and node-based formatters work.

**Trade-offs.** Honours nvm's `default` alias but not a project's `.nvmrc` version — virtually always fine for LSP/lint, only a problem for a project pinned to a different node than your default. A sibling fix prepends `~/.cargo/bin` (and Homebrew's rustup prefix) for cargo/rust-analyzer, and a third overrides the system JDK with SDKMAN's default — unlike the other two, that one runs even when `java` already resolves, because on macOS `/usr/bin/java` always does.

---

## Kotlin: JetBrains kotlin-lsp via kotlin.nvim (not fwcd kotlin-language-server)

**Context.** The default JDK on the machine where this was decided was Corretto **25**, and the long-standing `fwcd/kotlin-language-server` crashes on JDK 25. (The WSL machine ran SDKMAN's Temurin **21.0.12**, as recorded in the now-historical `docs/deviations-from-main.md`; that is why the two documents name different JDKs. The decision stands either way: kotlin-lsp bundles its own runtime, so it is unaffected by whichever JDK is default.)

**Decision.** Migrate to JetBrains' official **kotlin-lsp** (binary `intellij-server`, lspconfig name `kotlin_lsp`), managed by [kotlin.nvim](https://github.com/AlexandrosAlexiou/kotlin.nvim) rather than mason-lspconfig (it is simply absent from the `automatic_enable` allow-list). It is **self-managed rather than Mason-installed** — see the sub-decision below.

**How.** `lua/plugins/kotlin.lua` calls `require("kotlin").setup{...}`. kotlin.nvim builds the launch command itself — `bin/intellij-server --stdio --system-path=<per-project workspace>` — resolving the install directory by globbing `$MASON/packages/kotlin-lsp/kotlin-server-*` and, when that is absent, falling back to the `KOTLIN_LSP_DIR` env var. `kotlin.lua` sets `KOTLIN_LSP_DIR` to the `~/.local/share/kotlin-lsp/current` **symlink path** (see *Running servers* below for a resolved-path variant that was tried and reverted).

**Trade-offs.** kotlin-lsp is powerful (it's the IntelliJ engine) but young, so several LSP features are incomplete or behave unusually — which drove the three sub-decisions below. It also imports the whole Gradle project on open (slow first attach), because it's the IDEA project model, not a lightweight indexer. kapt/MapStruct-generated symbols show "unresolved" because kotlin-lsp doesn't register kapt source roots.

### Kotlin sub-decision: the rename handler override
kotlin-lsp stamps **stale document versions** on rename edits (e.g. version 27 while the buffer is at 35), so Neovim 0.12 rejects the workspace edit with "Buffer newer than edits" and the rename silently fails. The fix overrides the client's `textDocument/rename` handler to rewrite each edit's version with the live buffer version (`vim.lsp.util.buf_versions[buf]`) before applying. An earlier version set the version to `nil`, which crashed nvim 0.12 (`compare number with nil`) — the current version overwrites with the real number.

### Kotlin sub-decision: the `@` completion trigger
kotlin-lsp only declares `.` as a completion trigger, so typing `@` never opens annotation completion. On attach, `@` is appended to the client's `completionProvider.triggerCharacters`.

### Kotlin sub-decision: inlay hints need explicit config
kotlin-lsp (v261+; v262 when this was diagnosed, 263 now) **advertises** the inlayHint capability but returns **zero hints** unless told which hint types to emit — and it requests that configuration *dynamically* via a `workspace/configuration` handshake that kotlin.nvim serves. With a bare `setup({})` the settings block is skipped and no hints appear (this was initially — and wrongly — diagnosed as a server stub). The fix passes `inlay_hints = { enabled = true }`, which populates the `jetbrains.kotlin.hints.*` settings. Verified live: 21 hints on a real controller file.

### Kotlin sub-decision: self-managed outside Mason (the expiry treadmill)
**Context.** `intellij-server` is a time-bombed JetBrains EAP build with a ~30-day evaluation window (confirmed by JetBrains' own "each build renews the evaluation period and is limited to 30 days"). When it lapses it launches, prints `This build of intellij-server has expired`, and exits with code 7 *before* the LSP `initialize` handshake — so the client never attaches, no `LspAttach` keymaps bind, and no Gradle import runs (the workspace log stops right after "Server extensions loaded"). The failure recurs monthly and is not a config bug.

The obvious fix — `:MasonUpdate` + reinstall — **does not work** once you are on the newest published build: Mason's registry trails JetBrains by weeks, and reinstalling re-fetches the *same* pinned (expired) build number from the CDN. Observed 2026-09: Mason and JetBrains' GitHub *releases* were both stuck at the expired `262.9593.0` with nothing newer to pull.

**Decision.** Take kotlin-lsp out of Mason's `ensure_installed` entirely and self-manage the build: keep it at `~/.local/share/kotlin-lsp/current` (a symlink to a versioned `kotlin-server-<build>/` dir) and let `kotlin.lua` point `KOTLIN_LSP_DIR` at the `current` symlink path. *(Corrected 2026-09-29: an edit on the review branch had changed this to "the build it resolves to" -- the per-launch resolved path that was tried and reverted, see below.)* Refreshing on expiry is then a download plus one `ln -sfn` symlink repoint — no config change. *(Later: `:KotlinLspUpdate` automates this, see below. It swaps the link atomically with Python's `os.replace` instead of `ln -sfn`.)*

**Source selection.** Prefer the latest GitHub release, using its published platform archive and checksum links. Before changing `current`, verify its SHA-256 and require a successful LSP `initialize` response from an isolated startup probe. Only an explicit build-expired message permits offering Open VSX, and downloading its server requires a second confirmation. The extension's `server-bundle.json` provides the fallback server version, URL, and checksum; the fallback must also pass initialization. A timeout, unrelated startup failure, download failure, or checksum mismatch aborts without changing the installation. A valid GitHub release wins even when Open VSX has a higher build number. Do not infer expiry from the release date or an assumed 30-day lifetime.

**Automation.** `:KotlinLspUpdate` runs `scripts/update-kotlin-lsp.sh` with `scripts/kotlin-lsp-release.py` for release parsing and startup probing. The probe keeps stdin open through initialization, uses temporary configuration/cache/log directories with no project, and terminates its own process group afterward. It does not stop the editor's running server. Even an already-installed candidate is probed before reporting `UP-TO-DATE`. Installation repoints `current`, records the build it replaced as a `previous` symlink, prunes every other build (older or newer) that is neither current, previous nor in use by a running server, and reattaches Kotlin buffers; download and check phases appear in fidget. The final machine-readable status line identifies the selected build, including after fallback. Downloaded builds retain `install-source.json` for provenance. The expiry popup shows the failed version/source and asynchronously previews the GitHub replacement using `--preview` (metadata only), explicitly marking its expiry check as pending until the user updates. Old installs without provenance are labeled unknown; expiry entries for a different installed version are ignored. *Later (2026-09-29):* with the server launched through the `current` symlink the log line names `current`, not a version, so that check could not tell builds apart and an old build's expiry flagged a freshly updated one; an expiry logged before `current` was last repointed (the link's mtime) is now ignored (`scripts/tests/kotlin_expiry_current.lua`).

**Confirmation protocol and safeguards.** `lua/tajbanana/kotlin_update.lua` owns progress, retry/dismiss, and the in-editor busy guard. After GitHub explicitly expires, the script reads Open VSX bundle metadata. Identical versions terminate without an offer. Otherwise it emits `CONFIRM-OPEN-VSX <github-build> <vsx-build>` and waits for stdin: only `y`/`Y` permits downloading the Open VSX server. The bundle remains in memory so approval applies to the displayed version, even if upstream publishes another release meanwhile. Dismissal or EOF exits 20; expired Open VSX exits 11; the identical expired build exits 12. Other failures offer a GitHub-first retry rather than switching sources. The shared confirmation float waits for normal mode and treats closing the buffer as dismissal.

The helper acquires a nonblocking OS file lock before an update and inherits it across exec into the shell, preventing competing processes during download, validation, and the second prompt (busy exit 75). The lock is automatically released on process exit. Metadata-only `--preview` is exempt. The in-editor guard also covers retry prompts and reattachment. The updater validates before activation and uses `os.replace` for the `current` symlink; pruning happens only after activation and pruning errors are warnings.

**Validation.** Offline Python tests cover GitHub preference, explicit fallback consent, decline/EOF, both-expired and identical-build cases, download checksums and source recording, unrelated failures, startup timeout, metadata preview, and lock contention during confirmation. Headless Neovim checks cover version/source display, split stdout markers, second confirmation, retry/dismiss, restart, busy guards, and stale expiry logs.

**Rollback.** Pruning every other build left no way back from a build that starts but then misbehaves (crashes while indexing, a feature regression). The updater now keeps exactly one previous build (~1 GB), and `:KotlinLspRollback` (script mode `rollback`) swaps `current` and `previous` under the same cross-process lock — after running the same isolated startup probe on the previous build. Each link is replaced atomically (`os.replace`), but a swap is two replacements, so `previous` is repointed first and restored if repointing `current` then fails: a failure changes nothing. It refuses (exit 14) when that build has expired — after the usual expiry-driven update it has, and switching back would only produce a server that refuses to start — and exits 13 when there is none, when `previous` already equals `current`, or when `previous` dangles (the link is removed). Any other probe failure exits 1 and leaves `current` unchanged. Rollback needs only python3, not curl/unzip.

*(Superseded 2026-09-29 — see the "Later" note after this paragraph. Kept as the record of what was tried.)* **Running servers.** Neovim launches kotlin-lsp from the *versioned* directory that `current` resolves to, not through the symlink: `kotlin.lua` re-resolves `KOTLIN_LSP_DIR` (`kotlin_update.self_managed_dir()`, honouring `KOTLIN_LSP_HOME`) on **every** Kotlin FileType. Resolving it once at load was a regression — other Neovim instances kept launching the old build after an update elsewhere, until it was pruned. Launching from the versioned directory means an update or rollback never swaps files under a running server, and the directory appears in the server's command line, so pruning skips any build a running process uses. The check is a bash `[[ == ]]` match over `ps -A -ww -o args=`: the earlier `printf | grep -q` died of SIGPIPE on an early match and, with `pipefail`, read an in-use build as unused. `DEST` is resolved (symlinks, trailing slash) to match the launched path. Pruning fails **closed**: nothing is pruned without a process list, or while any server launched through `current` runs (its build cannot be told). An update links `previous` before `current` and restores it if activation fails, so "installation preserved" is true. Offline tests cover all of these, plus `current == previous`, a dangling `previous`, rollback without curl/unzip and a relative `KOTLIN_LSP_HOME`; `scripts/tests/kotlin_lsp_dir.lua` covers the per-launch resolution. *(That test was deleted with the revert; `scripts/tests/kotlin_launch.lua` replaced it.)*

*Later (2026-09-29): reverted.* An independent verifier ran the real kotlin.nvim and found that after `:KotlinLspUpdate` / `:KotlinLspRollback` Neovim relaunched the **old** build: Neovim's own `vim.lsp.enable` FileType handler (registered at startup, so it runs before any autocmd a plugin adds later) starts the server from the command kotlin.nvim configured on the *previous* launch, and that command now held a resolved build path, which never follows a swap. Other Neovims did not follow an update either. `KOTLIN_LSP_DIR` is the `current` symlink path again (the design on `main`), so every spawn follows the link. (A launcher script that resolved `current` at spawn was drafted and dropped in favour of the revert.) Consequences kept: `KOTLIN_LSP_DIR` is set even while `current` dangles (so a repair needs no restart), an exported `KOTLIN_LSP_DIR` is respected, and nothing is set without a self-managed install. Pruning can no longer see which build a server started through `current` runs, so nothing is pruned while any `…/current/bin/intellij-server` process runs (matched broadly, symlinked homes included — a false match only postpones cleanup); servers started from a versioned directory are still recognised. A failed activation with no previous link now removes the `previous` it had just created. `scripts/tests/kotlin_launch.lua` (real kotlin.nvim, fake builds that log their version) checks which build a restart and a later launch actually run — through the real `restart_clients()`, i.e. with Neovim's FileType handler ordering that caused the regression (added after a verifier noted the first version ran the command by hand). *Later still:* the revert had dropped main's step that points kotlin.nvim at `current` after an update, so a **first** install through `:KotlinLspUpdate` did not attach until a restart; `kotlin_update.point_at_current()` now runs at load and before every restart (covered in the same test); `kotlin_lsp_dir.lua`, which only checked the environment variable, was removed; the updater tests use a fake process list so an open Kotlin session cannot change their outcome.

**Availability.** Both commands are defined in kotlin.nvim's `config`, which lazy-loads on `ft = kotlin`, so until a `.kt` buffer opened they did not exist — including on a fresh machine, where `:KotlinLspUpdate` is what performs the first install. The spec also declares `cmd = { "KotlinLspUpdate", "KotlinLspRollback" }`, so lazy.nvim creates stubs that load the plugin on first use.

**Trade-offs.** Still a monthly (manual-trigger) refresh rather than zero-touch, and `:Mason` shows kotlin-lsp oddly (its receipt may still reference an old build) — harmless, since kotlin.nvim resolves the dir itself. There is no supported way to disable the expiry timer (it is compiled into the IntelliJ platform build; clock-rollback and binary-patching are out of scope), so refreshing is the sanctioned free path. If JetBrains ever ships a non-expiring/stable channel, or Mason's registry starts tracking closely, this can revert to plain `ensure_installed`. Detection is automated: `lsp_status.lua` scans the LSP log tail, shows ⏱, and pops a small floating prompt offering to run `:KotlinLspUpdate` (see the indicator decision below).

---

## Treesitter: the `main` branch + the `tree-sitter` CLI

**Context.** nvim-treesitter's `main` branch changed the activation model and requires the `tree-sitter` CLI for `:TSInstall`. Without both, highlighting is inert.

**Decision.** Use the `main` branch, install the CLI via `brew install tree-sitter-cli` (the plain `tree-sitter` formula is lib-only), and start highlighting explicitly.

**How.** A `FileType` autocmd calls `vim.treesitter.start()` (the main branch does not auto-start). Custom captures live in `after/queries/<lang>/highlights.scm` (`;; extends`) at priority 130. That is above LSP semantic tokens (125), so these captures win over the server where the two disagree.

**Why the `after/queries` exist.** Each one fixes a spot where the server's colour, or the lack of one, is wrong for the scheme:
- `after/queries/{tsx,typescript}/highlights.scm` capture the setter half of a `useState`/`useReducer` destructure (`const [x, setX] = useState(…)`) as `@function.setter`. `colorscheme.lua` does not define that group, so it falls back to `@function`, which is blue. The setter is therefore blue at its declaration even though ts_ls reports it there only as a plain variable, and it is blue before semantic tokens arrive.
- `after/queries/kotlin/highlights.scm` captures annotations (`@`, the use-site target and the annotation's type name) as `@attribute`, which is purple italic. kotlin-lsp tags annotation names with a `function` semantic token, which would otherwise make them blue.
- Known limit: import-clause identifiers (`import { useState, Foo }`) render as plain `@variable` white, because ts_ls sends no semantic tokens for import specifiers and treesitter cannot know a name's kind. A `type X` import is captured as `@type`, so it is yellow. These files and this limit were first recorded in `docs/tsx-intellij-color-parity.md`, which is now a superseded historical record.

**Trade-offs.** Capture names were renamed upstream (`@method.call` → `@function.method.call`, `@parameter` → `@variable.parameter`, `@constant.builtin` booleans → `@boolean`, `@float` → `@number.float`); the colorscheme restores all of these, or onedark defaults leak through.

---

## Colors: onedark + a Material Darker palette, one consistent scheme

**Context.** The scheme originally chased pixel-level IntelliJ parity, which meant
*per-language* overrides — free functions were yellow in TS/TSX but blue in
Kotlin/Go/Lua, primitives purple in TS/Kotlin but cyan elsewhere. That divergence
made colours feel unpredictable when jumping between files, so the goal shifted to
**one consistent role→colour mapping applied identically in every language**.

**Decision.** Base is onedark.nvim (`deep` style) with a custom Material Darker
palette in `lua/plugins/colorscheme.lua`. Each capture is defined **once**; there
are **no** `.tsx`/`.typescript`/`.kotlin`/`.java`/… overrides — language-scoped
captures fall back to the base, so a role is the same colour everywhere.

**How.** Two layers: Treesitter captures (`@keyword`, `@type`, …) and LSP semantic
tokens (`@lsp.type.*`, higher priority, the source of truth wherever a server
provides them). The role→colour mapping: functions/methods **blue**; types /
classes / enums / constructors / namespaces / generics **yellow**; interfaces
**green italic**; primitive types (`string`/`int`/`bool`) **cyan**; variables /
constants **white**; parameters / numbers / enum-members **orange**; properties /
fields **grey-blue**; keywords / booleans / null / this / annotations **purple
italic**; strings **green**; operators and `${}` interpolation **cyan**;
brackets / delimiters a **muted rose** (`#C9A6B8`, the one hue no role uses);
comments **grey**; tags **red**. The keyword family is generated from one list.
`:Inspect` finds the group under any token.

**Previews.** Telescope preview buffers get treesitter highlighting only. No LSP
client attaches to a preview, so semantic-token colours never appear there, and a
token the server recolours can look different in the preview than in the real
buffer. This is by design, and there is no supported way around it. It was first
recorded in the historical
[2026-07-20 audit](2026-07-20-color-discrepancy-audit.md).

**Completeness.** Beyond the primary roles, the table also pins the low-frequency
fallback/sub-captures that grammars emit — `@comment.documentation`, `@string.special`,
`@function.macro`/`@lsp.type.macro`, `@lsp.typemod.property.static`/`.readonly`,
`@none`, `@label`, and the `@markup.*` family — because onedark's own defaults for
those are off-palette (darker greys, reds, teals). A 20-language headless audit
([2026-07-26](2026-07-26-cross-language-color-audit.md)) confirmed the scheme is
correct wherever it is defined and surfaced exactly these unmapped captures as the
only defects; they are now all mapped. What remains are LSP/grammar quirks (e.g.
rust_analyzer mis-classification, ts_ls not emitting `interface` tokens), not
scheme gaps. That audit lists them. Its scheme findings were re-checked against
`colorscheme.lua` on 2026-09-29, but the quirks are runtime observations from
2026-07-26 that were not re-run.

**Trade-offs.** Dropped IntelliJ pixel-parity for predictability — the historical
per-language values are recorded in `tsx-intellij-color-parity.md` and the
2026-07-20 audit. Both are kept as historical records, superseded by this scheme. A few nuances went away with the
overrides: JSX component vs builtin tags are no longer distinguished (all tags
red), and `bold` on tsx constructors dropped.

**Trade-offs (earlier approach, superseded).** It's a large declarative table, but flat and single-concern. Per-language scoping (`.tsx` vs `.typescript`) is verbose but necessary — the same capture legitimately differs by language in IntelliJ. *(This described the IntelliJ-parity version. The single scheme above removed all per-language scoping: `colorscheme.lua` defines each capture once. The table is still large, flat and single-concern.)*

---

## `<leader>gd`: one picker that queries every attached client

**Context.** A buffer often has several LSP clients (a `.tsx` may have ts_ls + eslint + graphql). Querying only the first client returns empty results when a *different* client owns the answer. Separate `gd`/`gtd`/`gi`/`gr` keys also fragment muscle memory.

**Decision.** A single `<leader>gd` that merges definition, type-definition, implementation, and references into one Telescope picker, tagged and color-coded by kind.

**How.** It enumerates every client that supports each method, fires all requests, dedups by `file:line:col`, sorts by kind then location, and renders a `[kind]` tag column. The picker opens in normal mode (`j`/`k`, `<CR>`); press `i`, then type `def`/`type`/`impl`/`ref` to filter. Library locations that arrive as URIs (kotlin-lsp `jar://`, jdtls `jdt://`) have no file on disk, so the stock previewer would render them empty. They are previewed by loading the URI buffer inside the preview window so kotlin.nvim's decompiler (`BufReadCmd`) runs. A decompile that timed out during import is re-read (`edit!`) on the next preview.

*Later (2026-09-29, backlog_005 B7):* the picker used to wait for every request with no timeout, so one server that never answered showed nothing; it now opens after 3 s with what arrived and names the silent servers. De-duplication by location used to keep only the first request's tag, so a location that is both definition and type definition could not be found by filtering "type"; it now keeps every kind (`[def,type]`). Requests still outstanding at the timeout are cancelled on the server.

*Later:* `<leader>gi` and `<leader>gr` were kept as separate single-kind Telescope pickers (`lsp_implementations`, `lsp_references`), not the native quickfix dump, for when only one kind is wanted.

**Trade-offs.** More code than the built-in single-method maps, but it's correct in multi-client buffers and collapses four keystrokes into one.

---

## Inlay hints: per-server settings, `supports_method`, and the `LspProgress` catch

**Context.** Inlay hints (inline inferred types / parameter names) are **off by default in most servers** and must be opted into per-server. Servers also advertise the capability differently.

**Decision.** Enable inlay hints on by default wherever the server produces them, with a `<leader>ti` per-buffer toggle. Opt into hints per server; detect capability via `supports_method`, not `server_capabilities`; and re-check on `LspProgress` for late registrants.

**How.**
- Per-server opt-in: `ts_ls` (typescript/javascript `inlayHints.*`), `gopls` (`hints.*`), `pyright` (`python.analysis.inlayHints`), `lua_ls` (`hint.enable`), Kotlin via kotlin.nvim (above). rust_analyzer emits them without extra config.
- Capability check uses `client:supports_method("textDocument/inlayHint", buf)`, **not** `client.server_capabilities.inlayHintProvider`. jdtls registers the capability **dynamically**, so `server_capabilities` is `nil` and the static check silently skips it.
- **The `LspProgress` catch:** jdtls registers inlayHint *late* — after its slow workspace init, well after `LspAttach` has fired. So the attach-time enable misses it. An `LspProgress` autocmd re-checks each client's buffers as the server reports progress and enables hints the moment the capability lands. A per-buffer guard makes it fire exactly once, so it never fights a manual `<leader>ti` toggle-off.

**Verified support matrix (live counts):** TS 2 / TSX 1 / JS 30 / Lua 147 / Go 2 / Rust 12 / **Kotlin 21** / **Java 52**. Not supported: **Python** (open-source pyright doesn't expose the capability — basedpyright would), **Bash** (bashls has no provider; nothing to infer).

**Trade-offs.** The `LspProgress` handler runs on every progress tick, but the guard makes it a cheap no-op after the first enable. jdtls's own slowness (below) is a separate issue.

---

## jdtls (Java): accept the slow shared workspace, don't fight it

**Context.** The bundled-lspconfig jdtls uses a single shared `~/.cache/jdtls/workspace`. Logged init times vary wildly: **0.6s warm, ~40s cold, and one ~290s** outlier after a heavy multi-project import. Until init finishes, Java features report "method not supported".

**Decision.** Keep the default shared-workspace jdtls (simple), and handle the *consequence* (late inlay registration) via the `LspProgress` catch above, rather than adopting `nvim-jdtls` for per-project workspaces.

**Trade-offs.** First Java open in a heavy state can take a minute or two; day-to-day warm opens are seconds. If Java becomes a daily driver, `nvim-jdtls` with a per-project workspace (or clearing the stale shared workspace) is the escalation path.

---

## `<leader>go`: pick the launcher here, not in `vim.ui.open`

**Context.** "Open this file in the OS default app" looks like one line of code — `vim.ui.open(path)` — and for a single-platform config it is. Across macOS, WSL and Linux it is three launchers with two different path formats and three different exit-code conventions.

**What went wrong.** The first version called `vim.ui.open` and, under WSL, translated the path with `wslpath -w` first. That worked until `wl-clipboard` was installed to fix the system clipboard: it pulled in `xdg-utils` as a dependency (same dpkg transaction), which put `xdg-open` on `PATH`. `vim.ui.open` prefers `xdg-open` over `explorer.exe`, so nvim silently switched launcher — and this box has no desktop session, so `xdg-open` exits 4 for every file. `<leader>go` stopped working with no change to the config.

Two distinct defects, and the second is why the first survived:

1. **The launcher and the path format are coupled.** Translating to a Windows path and then letting something *else* choose the launcher is only correct while that choice happens to be `explorer.exe`. It is not a stable assumption — it depends on what else is installed.
2. **`vim.ui.open` cannot report a failed launch.** It launches detached and returns the process object; its error return is non-`nil` only when *no* handler is found at all. A launcher that runs and then fails is indistinguishable from success at the call site.

**Decision.** Select the launcher in `set.lua`, alongside the path translation, and report non-zero exits.

**How.**
- `platform.wsl` is tested **before** the Linux path, because WSL is also Linux — the more specific case has to win.
- WSL uses `explorer.exe` with the `wslpath -w` path, and **ignores the exit code**: explorer returns 1 even on success. macOS uses `open`, Linux `xdg-open`, both with POSIX paths.
- The mac branch is gated on `platform.mac`, not on `executable("open")`. Debian ships `/usr/bin/open` as a symlink to `xdg-open`, so a capability test would happily pick the wrong binary on Linux.
- `<leader>go` only hands over a **path that exists on disk**. Special buffers (terminals, scratch buffers, the file tree) have a non-empty but fake `%:p`, which made `open`/`xdg-open` fail and — since WSL has no exit check — made `explorer.exe` silently open its default folder. Such buffers now get "Not a file on disk"; in nvim-tree the node under the cursor is opened instead.
- mac and Linux launches are **not** detached: both hand off to the desktop and exit immediately, so the exit code arrives at once and the spawned application is unaffected. A non-zero exit becomes an error toast.

*Later:* the launcher moved out of `set.lua` into `lua/tajbanana/system_open.lua`, because `forge.lua` opens URLs through it too. The `<leader>go` keymap stays in `set.lua` and does the on-disk check. The choices above are unchanged, with these additions:
- The non-WSL launcher is picked with `platform.pick` on the mutually exclusive `platform.name`, still never with an `executable("open")` test.
- Native Windows Neovim uses `cmd.exe /c start ""`.
- Inside Fedora Toolbx (`/run/.toolboxenv`), `xdg-open` runs on the host via `flatpak-spawn --host`, because the container cannot see the host's desktop files.
- On WSL, a URL (`scheme:`) is passed to `explorer.exe` as is, without `wslpath`. A missing `explorer.exe` or a failed `wslpath` is reported.

**Trade-off.** This duplicates a little of what `vim.ui.open` does, and will not automatically benefit if upstream improves its detection. That is accepted deliberately: the failure mode being avoided is *silent*, and it was caused by an unrelated package's dependency. Explicit beats clever when the alternative fails quietly.

**Not verified on macOS.** The command construction was verified for all three branches by intercepting `vim.system`, and the Linux failure path was verified with a real failing `xdg-open`. Actual macOS behaviour has not been exercised — there is no Mac in reach of this checkout.

---

## Forge shortcuts: detect the forge from the remote, token-free by default, CLI-preferred

**Context.** "Open this line / this branch's PR in the browser" is forge-specific — GitHub's URL shapes (`/blob/…#L`, `/pull/…`, `/compare/…`) don't match GitLab's (`/-/blob/…#L`, `/-/merge_requests/…`).

This existed twice: `gitlab.lua` on the work machine, `github.lua` on the personal one. Maintaining both meant maintaining a per-machine branch of the whole repo, which is the wrong axis — **the forge is a property of the remote, not of the machine.** The same laptop can hold a GitHub checkout and a GitLab checkout side by side, and a per-machine fork gets both wrong.

**Decision.** One module, `lua/tajbanana/forge.lua`, which **detects the forge per buffer from the remote host** and keeps every URL-shape difference in a single `FORGES` table. Lookup stays **token-free by default, better with the forge CLI**.

**How.**
- **Detection:** a per-repo `git config --local nvim.forge github|gitlab` override wins; otherwise the host from the normalized remote URL is matched by dot-separated **labels** (not substrings), so `gitlab.example.com` and `github.acme.internal` resolve while `notgitlab.com` does not. An ssh alias such as `work-gitlab` is first resolved to its `~/.ssh/config` `HostName` (see *URL normalization*), and that host is what is matched. A self-hosted host without the vendor in its name (`git.thalesdigital.io`) needs the override. An unrecognised host notifies "Unsupported forge" (with the override command) rather than emitting a plausible-but-wrong link — failing loudly beats a URL that loads and shows the wrong thing.
- **One table, not one module per forge:** `FORGES` holds the request path, create URL, blob path, range anchor, `ls-remote` head glob/pattern and CLI per forge. Everything else is shared. Adding Bitbucket is one entry.
- **URL normalization:** one `to_web_url` helper converts any remote form (scp-like, `ssh://`, `https://`) to a web base, stripping `.git` and embedded credentials — replacing a fragile gsub chain that leaked tokens and mishandled ports. ssh forms become https without the ssh port; http(s) remotes keep their scheme and port (2026-09-29; originally every form became https with the port dropped). An ssh host is replaced by its `~/.ssh/config` `HostName` (via `ssh -G`) **only when it is clearly an alias** — no dot, or a last label that is not a TLD (`github.com-work`, `work-gitlab`). *Later (2026-09-29):* the remote check behind the permalink's "is HEAD pushed" fallback runs ssh in BatchMode with a connect timeout, in its own process group killed after 5 s (a hanging prompt used to crash `Space gl` and leave ssh running), and a remote tip that descends from HEAD also counts. A clipboard tool that fails after the 250 ms read-back is caught by watching the message history for 3 s. Resolving every host was tried first and broke links that worked (`gitlab.example.com` with `HostName gitlab-ssh.example.com`, or an IP, became "Unsupported forge"), so real host names are kept as written. The remote is resolved from the branch's upstream, not hardcoded `origin`.
- **PR lookup, token-free fallback:** GitHub publishes PR heads as `refs/pull/<n>/head`, so matching the branch SHA against them via `git ls-remote` finds an existing PR with no `gh` and no API token. (This is the direct analogue of GitLab's `refs/merge-requests/<iid>/head`, which is why the port kept the same shape.)
- **gh preferred when present:** `gh pr view --json url --jq .url` resolves the PR by **head branch via the API**, which is robust to the local SHA drifting from the pushed PR head (the ls-remote SHA-match's blind spot). gh is the official GitHub CLI, so this isn't a third-party gamble. The `FORGES` entry for GitLab does the same with `glab mr view --output json` (reading `web_url`). A non-zero CLI exit is ambiguous: it can mean "none yet" or an auth or network error. So it falls through to the ls-remote lookup rather than opening the create page for a branch that already has one.
- **No caching:** resolving a PR is a network round-trip (~1–2s, mostly latency, not tool startup). Every `<leader>gm` resolves fresh rather than caching a per-session result, so the state is never stale: a freshly-created PR is picked up immediately, and a closed/re-created PR resolves correctly. The round-trip is async, so nvim never blocks on it.
- **Range anchors differ:** GitHub repeats the `L` in a line range (`#L10-L20`) where GitLab does not (`#L10-20`). This is the easiest thing to get subtly wrong, because it **fails soft** — the URL still loads, it just highlights the wrong lines. Both forms are asserted in `scripts/tests/forge_permalink.lua`.

- **`<leader>gl` is a permalink:** it links `blob/<commit-sha>/<path>#L…`, not `blob/<branch>/…`. A branch URL points at whatever the branch is *later*, so a link pasted into a review drifted to other code as soon as more commits landed — the reason GitHub's `y` key and GitLab's "Copy permalink" exist. It opens the link and copies it to the clipboard (it is usually for sharing). Because a SHA only resolves once pushed, it **refuses** when no remote-tracking ref of the chosen remote contains HEAD (checked locally with `git for-each-ref --contains`, no network), and likewise when the file is **not in HEAD** (`git ls-tree HEAD -- <path>` is empty — an untracked or only-staged file would 404 even with HEAD pushed). The URL names the path as `ls-tree` reports it, i.e. as committed: on macOS a decomposed (NFD) name on disk is stored composed (NFC) by git. Paths are passed with `--literal-pathspecs`, so `a[1].txt` is a file name, not a glob. It **warns** — but still opens — when the file has uncommitted changes, since the line numbers then come from the working tree. A detached HEAD (bisect, a checked-out tag) is allowed, since the link is by SHA anyway; the remote is then `origin` (as it is for a branch tracking a local branch, `branch.<b>.remote = .`). The file is resolved with `fs_realpath`, so a symlink into the repo (`~/.ideavimrc`) links its target. Non-ASCII bytes and the characters RFC 3986 never allows raw (`" < > [ ] { } ^ | \` and the backtick) are percent-encoded, so macOS `open` does not re-encode the URL. Remote URLs: a trailing `.git/` is normalised; an ssh host alias (`github.com-work`) is resolved with `ssh -G` (prints ssh's effective config, never connects) and `ssh.github.com` / `altssh.gitlab.com` map to their web hosts; http(s) remotes keep their scheme and port. "Copied" is only claimed after reading the clipboard back — `setreg("+")` succeeds even when the provider's copy command fails. With xclip / xsel / wl-copy / win32yank Neovim's selection cache answers `getreg()` while the copy job lives, so the read waits ~250 ms for the job to settle (a failed job exits and drops the cache); pbcopy has no cache. Over OSC 52 a read would query the terminal, so the message says it was sent. A failed copy is a WARN. Regression checks: `scripts/tests/forge_permalink.lua` (with a fake clipboard provider, so running it never touches the real clipboard). *Later (2026-09-29):* a single-branch or shallow clone has no remote-tracking ref for a branch it pushed, so a pushed HEAD was refused; when no local ref proves it, the remote is asked once (`git ls-remote`, every ref; the network call is capped at 5 s). *(Corrected, round 7: this said `--heads`; it lists every ref, and the "cap" did not cover the ancestry test that followed — one `merge-base` per ref froze the editor for about a minute on a remote with 2000 refs. That test is now ONE `git rev-list` over the distinct tips, a `GIT_SSH` wrapper is no longer overridden, the process group is killed until empty (a single kill could miss the ssh git forked after its `ssh -G` probe died), and `Space gm`'s ls-remote fallback shares the same bounded runner.)* Dotted aliases under the public forges (`work.github.com`) are resolved too (round 7). *(Round 8: `ssh.github.com`/`altssh.gitlab.com` are mapped before any lookup (an IP `HostName` made them "Unsupported forge"); every host is looked up with `ssh -G` (with the `-F` file from `GIT_SSH_COMMAND`/`core.sshCommand`), and its `HostName` is used when the host is an alias OR the `HostName` is a public forge host (`github.personal`, `gitlab.work`); an alias with no `HostName` is refused rather than linked as itself; a remote check that times out says so instead of "push first"; `Space gm`'s fallback uses the upstream branch name.)* *(Round 9: IP addresses, punycode TLDs and one-word names without a `HostName` are real hosts again -- an ssh alias with no `HostName` IS the host ssh connects to, so only a dotted non-domain name is refused; `Space gm` tries the branch's own name first, the upstream only when it is published under another name.)* The committed path is read byte for byte (a leading space was trimmed, a `\1` in a name cut it) and control characters are percent-encoded.

**Why not gh-only?** It would need gh installed and authenticated, losing the zero-dependency property that works out of the box. And gh has no command to open an arbitrary file+line, so `<leader>gl` is hand-rolled regardless.

**Trade-offs.** Every PR open pays the network round-trip (no caching); nothing local can shrink that. The lazygit **color theme** can't be set from Neovim (lazygit renders its own TUI), so it lives in this repo's `lazygit/config.yml`, which lazygit.nvim passes with `-ucf` on every OS. lazygit reads its *default* config from a per-OS directory (`~/Library/Application Support/lazygit` on macOS, not `~/.config/lazygit`), which is why the once-documented `~/.config` symlink did nothing on a Mac and the live file there drifted ahead of the repo copy. The repo file is now the single source; terminal lazygit is linked to it via `lazygit -cd`. Its delta diff renderer passes `--dark` (lazygit's documented delta setup: delta cannot query the terminal background from inside lazygit) plus side-by-side, line numbers and the TwoDark theme explicitly, so the diff looks the same on a machine without the `git/delta.gitconfig` include.

---

## Repo-wide diagnostics `<leader>xr`: run the real linter, because LSP can't

**Context.** LSP servers only diagnose files that are **open**, so `<leader>xx` can never show problems in files you haven't visited. "Diagnostics on the whole repo" is impossible through LSP alone.

**Decision.** `<leader>xr` runs the project's actual linter over the **nearest project** containing the current file and loads the results into the Telescope quickfix picker.

**How.**
- **Outside git, only the file's own directory counts** (it used to fall through to an unbounded upward search: a stray `pyproject.toml` anywhere above won, and the walk ran to `/`). A file in a directory that does not exist yet uses its nearest existing ancestor, not nvim's cwd. The non-git Dockerfile walk is depth-bounded.
- **Project root = nearest marker, bounded by the git root.** Markers used to be checked only at the git root, so in a monorepo (`frontend/package.json`, `backend/go.mod`) nothing was found. Each detector's markers are now resolved upward from the current file with `vim.fs.root`; the deepest root wins and detector order breaks ties. Roots above the git root are ignored, so a stray `~/package.json` cannot hijack every repo. One tool still runs per press.
- **Tool detection** by marker: `go.mod` → `golangci-lint` when installed (a superset of vet), else `go vet`; `Cargo.toml` → `cargo check`; `pyproject.toml`/`requirements.txt` → `ruff`; `package.json`/`tsconfig.json` → the **local** `node_modules/.bin/eslint` (lint), falling back to local `tsc` (types); `Chart.yaml` → `helm lint`; a `.yamllint*` config → `yamllint` (only with a config — its defaults would flood an unconfigured repo); a Dockerfile → `hadolint` over the project's Dockerfiles.
- **Workspace-hoisted JS tools:** `node_modules/.bin` is searched from the project root *up to the git root*, because npm/yarn workspaces (and pnpm, for root devDependencies) install eslint/tsc at the workspace root, not in `packages/foo`. The tool still runs with cwd = the package, so only that package is linted. *(Round 7: true for ESLint, not for tsc — tsc checks the project of the `tsconfig.json` it finds, so a package inheriting its parent's got the parent project's result, including "no issues" when that project did not include the package at all. tsc now runs `-p <that tsconfig> --listFiles`; for an inherited project only the package's entries are kept, and a project that compiles none of the package's files is reported instead of an all-clear.)* *(Round 8: that check made a clean package beside a failing one look like a tool crash, and hid a tsc that never ran. Coverage is now asked about the EDITED file, for every tsconfig (a solution-style `files: []` + `references` config or a narrow `include` also gave a false all-clear); reported diagnostics explain a non-zero exit; nothing listed plus a non-zero exit is a tool failure; a position-less config error lands on the tsconfig.)* *Later:* that made the tsc fallback reachable in packages without their own `tsconfig.json`, where tsc printed its help and "failed"; tsc now runs only with a `tsconfig.json` at or above the package (up to the git root — tsc finds an inherited one itself; requiring the package's own refused a package that inherits its parent's), otherwise a clear reason is shown.
- **golangci-lint v2 paths:** v2 prints paths relative to the directory of the *config file*, not the cwd, so with `.golangci.yml` at the repo root and `go.mod` in a subdirectory every entry resolved against the wrong base. v2 is run with `--path-mode=abs` (the flag does not exist in v1, whose paths are cwd-relative, so the major version is checked once per session).
- **helm lint output:** INFO lines (and their continuations) are dropped; `templates/x.yaml: … line N …` resolves against the chart — but that N counts lines of the **rendered** template, not the source, and the entry says so. Template errors name only the *directory* and carry the real location in the message, prefixed with the chart's **name** from `Chart.yaml` (not its directory), which is stripped: `parse error at (<chart>/templates/x.yaml:3)` (v3/v4), `<chart>/templates/x.yaml:1:13` followed by indented `executing …` lines (v4 execution errors; the continuation lines are kept in the message), `template: <chart>/templates/x.yaml:3:5: executing …` (v3). Chart-metadata errors give the chart dir as an absolute path, and a broken `Chart.yaml` puts its `yaml: line N` on a continuation line. Anything that is still a directory maps to that chart's `Chart.yaml`, so the picker never offers an unopenable entry. Checked against real helm 4.3 output. *Later (round 7):* a values-schema failure prints its detail on UNINDENTED lines up to the next blank line, and its `templates/` entry re-reports the `values.yaml` one; both are handled. Every entry now carries a severity (yamllint's `[error]`/`[warning]`, cargo's prefix, else E), tsc's chained reasons are kept, and a second `Space xr` while one runs is refused.
- **Nearest marker, all markers equal:** a detector's markers are passed to `vim.fs.root` as a *nested* list, which makes them equal priority. A flat list is a priority order: a repo-root `package.json` beat a nearer `tsconfig.json`, and a `pyproject.toml` above the git root hid `svc/requirements.txt` altogether.
- **go vet:** type errors are printed as `vet: path:line:col: msg`; the errorformat matches that prefix first, or the filename became `vet: path`. **golangci-lint**'s logfmt diagnostics (`level=error msg=…`) are ignored (`%-G`): they became a junk entry that also hid a real failure. **ruff** runs with `--color never` (an inherited `FORCE_COLOR` broke parsing).
- **More helm shapes:** file names with spaces; sub-charts named in paths by their `Chart.yaml` name, which need not be their directory; packaged `.tgz` sub-charts (labelled, on the parent `Chart.yaml`); columns kept; the header split at the first `": "` (a `:` in the chart path); and a broken `values.yaml`, which helm reports three times, becomes one entry on `values.yaml`. *Later:* a broken **sub-chart** `values.yaml` / `Chart.yaml` arrives as "error unpacking subchart <dir> in <parent>: cannot load …" (`<dir>` is the directory under `charts/`, nested once per level); following it puts the entry on the sub-chart's file instead of the parent's (checked against helm 4.3). The missing-helm hint no longer says to use `:Mason`.
- **Local tools must be executable:** a `node_modules/.bin` tool without the execute bit is reported as such instead of a raw `EACCES`.
- **hadolint file list:** tracked files, plus untracked files that are not ignored, come from `git ls-files -z --cached --others --exclude-standard` (without `-z`, non-ASCII paths are C-quoted and were lost), deduplicated (a conflicted file is listed once per stage). It still lists a Dockerfile deleted from the working tree — and one missing path aborts the whole hadolint run — so paths that no longer exist are dropped; `Dockerfile.dockerignore` (and `.md`, `.j2`, `.template`, … variants) is not a Dockerfile; the Dockerfile being edited is linted even when gitignored; `--` precedes the list. `scripts/tests/repo_diagnostics.lua` reports which tool-gated checks it skipped.
- **ESLint via JSON:** `-f unix` was removed from ESLint 9's core (moved to a separate package), so it failed to load on every current project. `-f json` exists in every version and is parsed straight into quickfix items, decoding JSON `null` as `nil` — ESLint emits `"ruleId": null` for parse errors. hadolint also uses JSON.
- **Local binaries, not `npx`:** `npx` is the nvm lazy-load stub in a non-interactive context and fails; the local `node_modules/.bin` binaries exec node, which nvim has on PATH via the fix above. (eslint, not tsc, is the default for JS/TS because "lint" means lint — tsc only catches type errors.)
- **Path resolution:** a leading `%D` "Entering dir" errorformat line makes each tool's relative paths resolve against the linted project's root (the nearest marker — the repo root only when the marker sits there), or a detector's `base` when the tool reports paths relative to somewhere else (cargo: the workspace root, found as the nearest ancestor `Cargo.toml` with `[workspace]`), regardless of nvim's cwd (the make/quickfix directory-tracking trick).
- **Phantom-entry filter:** the `%D` marker and tools' summary lines parse into quickfix entries with no buffer (`bufnr = 0`); left in, Telescope's open action fails with `E939: buffer 0`. The list is filtered to real file entries before it's shown.

**Trade-offs.** Gradle/Kotlin is deliberately **excluded** — a full `./gradlew compileKotlin` is far too slow to bind to a keystroke. So `<leader>xr` covers Go/Rust/Python/JS-TS/Helm/YAML/Dockerfiles but not Kotlin/Java. Adding a stack is one detector entry. Regression checks: `scripts/tests/repo_diagnostics.lua`.

---

## Diagnostics & undo through Telescope (not Trouble, not the undotree panel)

**Context.** Both the Trouble bottom-panel and the mbbill undotree side-panel are separate window paradigms; the rest of the nav (`ff`/`fw`/`gd`) is a Telescope list-left/preview-right picker.

**Decision.** Route diagnostics (`xx`/`xb`/`xr`) and undo history (`uu`) through Telescope for one consistent left/right picker experience. Trouble stays installed (`:Trouble` command, and a kotlin.nvim dependency); mbbill undotree was removed entirely.

**How.** `telescope.builtin.diagnostics` for xx/xb; `debugloop/telescope-undo` for uu (reads Neovim's native undo tree — no separate plugin state). The undo picker's results column is narrowed (`preview_width = 0.7`) so the diff preview dominates. `TelescopePreviewLine` is given a visible highlight so the jumped-to problem line stands out in the preview.

**Trade-offs.** `xx` shows only *analyzed* buffers (the LSP limitation `xr` exists to work around). Losing the persistent Trouble panel is deliberate — a picker fits the workflow better; the panel is one `:Trouble` away when wanted.

---

## Statusline & UI polish

- **`cmdheight = 0` + `showcmdloc = "statusline"`.** The always-present empty command-line row is reclaimed; pending keystrokes render in the lualine row via a `%S` component. (lualine drops `%S` first when a narrow window can't fit `lualine_x`; at 80 columns it is gone.)
- **No "Press ENTER" prompts.** With `cmdheight = 0`, any multi-line message — or two in a row — raised the hit-enter prompt. Two layers fix it. fidget owns `vim.notify` (`notification.override_vim_notify`, loaded at `VeryLazy` so it is up before the first notify), which covers most of this config's messages as corner toasts. Neovim 0.12's experimental **`ui2`** (`require("vim._core.ui2").enable({ msg = { targets = "msg" } })`, in a `pcall` because the module is internal) collapses everything else into its ephemeral message window; `g<` opens the pager. Verified in a real TUI: a 3-line `:echo` prompts with ui2 off and not with it on. `<Esc>`'s float-closer skips ui2's `cmd`/`dialog` windows, which ui2 owns.
- **Path shortening in the statusline.** lualine's built-in `shorting_target` is *window-relative* (only shortens when the path exceeds `winwidth − target`), so on a wide window deep paths never shortened. Replaced with an `fmt` that keeps the last two segments (`…/controller/ExerciseController.kt`) — predictable and meaningful for deep Java/Kotlin packages, unlike the built-in's single-letter initials.
- **`winborder = "rounded"`.** One global option borders all LSP floats (hover, signature help, diagnostics) consistently; nvim-cmp sets its own border so it doesn't double up.
- **nvim-tree fixed `width = 40`.** Dynamic/adaptive resizing left stale-cell redraw artifacts at the tree's right edge; a fixed width eliminates them.

---

## LSP load-status indicator in the statusline

**Context.** With slow servers (kotlin-lsp, jdtls) it's easy to lose track of whether the language server for the current file is actually up — an expired kotlin-lsp attaches *nothing* (see the readme's Troubleshooting), and even a healthy server is unusable while it indexes. A glyph beside the filetype answers "is the LSP ready?" at a glance.

**Decision.** `lua/tajbanana/lsp_status.lua` renders one icon in lualine's `lualine_x` next to the filetype: **✓** ready, **⟳** loading, **✗** expected-but-not-attached, **⏱** kotlin-lsp build expired, **○** no server for this filetype, blank for no filetype.

**How.**
- **✓ waits on work-done progress, not on attach.** The icon does *not* flip to ✓ the instant the client attaches — it withholds ✓ until every `$/progress` token the server opened has ended. So a server that indexes on open (kotlin-lsp, jdtls) shows `✗ → ⟳ → ✓`, and a dead/expired one stays ✗. A server that emits no progress is treated as ready on attach (it has no async load phase to report). An `LspProgress` autocmd tracks open tokens per client and refreshes lualine **only on `begin`/`end`** — the frequent `report` events don't change the icon, so refreshing on them would repaint the statusline dozens of times a second during indexing and steal cycles from input; `LspAttach`/`LspDetach` refresh too.
- **One primary server per filetype, keyed by filetype not client name.** A `PRIMARY` table maps each filetype to the single server that *is* that language; every other client attached to the buffer is ignored. It has to be per-filetype, not a name-based ignore list, because `graphql` is auxiliary on a `.tsx` buffer (which also draws ts_ls + eslint + graphql) but the *primary* server on a real `.graphql` file. Counting the extras made the icon flip to ✓ the moment one of them settled and back to ⟳ while the real server was still indexing — the reported bug that drove this design.
- **rust is claimed only when a toolchain is present**, mirroring the conditional `rust_analyzer` enable in `lsp.lua`, so a Rust-less machine doesn't show a red ✗ on every `.rs` file. *Later, the same for Go:* `lsp.lua` neither installs nor enables gopls without a `go` binary, so `go`/`gomod`/`gowork`/`gotmpl` are dropped from `PRIMARY` then and show ○.
- **⏱ distinguishes an expired kotlin-lsp from a generic failure.** kotlin-lsp dies before attaching when its EAP build expires (see the Kotlin self-managed sub-decision), which otherwise reads as a plain ✗. A `FileType kotlin` autocmd defers ~10s; if no `kotlin_lsp` client has attached by then it reads the tail of the LSP log (`vim.lsp.get_log_path()`, last 64 KB) and, on finding `intellij-server has expired`, shows ⏱ and pops a one-shot small floating prompt (`M._prompt_expired`; `y` to update, `n`/`q`/`<Esc>` to dismiss) offering to run `:KotlinLspUpdate`. A bespoke float is used rather than `vim.ui.select` because a full picker is oversized for a yes/no. Because the float steals window focus, it fires **only in normal mode** (it retries every 3 s, up to ~30 s, otherwise) so it can never swallow keystrokes typed mid-edit. The attached-first check means a healthy build (which attaches within seconds, well before indexing finishes) never reaches the scan, so a stale expiry line from an earlier session cannot false-positive; the flag self-heals to ✓/⟳ once a live build attaches. kotlin is the only server treated this way because it is the only one that expires.

**Trade-offs.** The `PRIMARY` table must be kept in sync with `ensure_installed` in `lsp.lua` when a language is added (except `kotlin_lsp`, which is self-managed and intentionally absent from `ensure_installed`). "Finished loading" is inferred from work-done progress, so a server that never emits progress shows ✓ on attach — correct for servers with no async index phase, but it can't distinguish "ready" from "silently still working" for one that indexes without reporting (kotlin-lsp and jdtls both report, so the headline cases are covered). The decision is a pure `_classify(ft, clients)` function, exposed so it can be unit-tested against the multi-client cases. No checked-in test in `scripts/tests/` exercises it yet. The expiry detection and popup are covered by `scripts/tests/kotlin_lsp_popup.lua`.

---

## Completion: accepting a value stays inside `()`

**Context.** `lua/tajbanana/completion.lua` wraps `cmp.confirm` so that accepting a *value* completion (variable, field, property, constant) skips one adjacent closing paren: `obj.method(value|)` → `obj.method(value)|`. The aim was smoother method chaining — accept the argument, keep typing `.next(...)`.

**Decision.** Unwired (commit `051f59d`): `<Tab>`/`<CR>` in `lsp.lua` call plain `cmp.confirm`. The jump misfires on calls with **more than one parameter** — accepting the first argument lands the cursor outside the parentheses, so every further argument means moving back in. It helped only single-argument chaining and got in the way everywhere else.

**How.** The module and its test (`scripts/tests/completion.lua`) are kept deliberately, headed with an "intentionally not wired in" note, so the behaviour can be revisited — e.g. skipping only when the active signature has a single parameter.

**Trade-offs.** The test passing says nothing about live completion; its header says so. Chaining after a one-argument call needs a manual `<Right>` / `)`.

---

## Formatters: dedicated where configured, LSP fallback everywhere else

**Context.** conform.nvim mapped dedicated formatters only for Lua (stylua), the web filetypes (prettier) and Kotlin (ktlint). Everything else relied on `lsp_format = "fallback"`, which left real gaps: pyright has no formatting (so `<leader>gf` was a no-op on Python), bashls only formats when `shfmt` happens to be installed, Markdown had nothing, and gopls formatting never adds or removes imports. And every formatter existed only on machines where it had been `:MasonInstall`-ed by hand.

**Decision.** Wire dedicated formatters — `ruff_organize_imports` + `ruff_format` (Python), `goimports` + `gofumpt` (Go), `shfmt` (sh/bash), `prettier` (Markdown, `proseWrap` left at `preserve`) — and add **mason-tool-installer** to ensure every formatter plus the `<leader>xr` linters on any machine that has the toolchain to install them. The LSP fallback stays for Rust (rustfmt via rust-analyzer) and Java (jdtls).

**How.** mason-tool-installer loads at `VeryLazy` and calls `run_on_start()` itself: its own start-up trigger is a `VimEnter` autocmd in `plugin/`, which has already fired by then, so with plain `opts` nothing would ever install. Tools that need a toolchain to install carry a `condition`: goimports/gofumpt (built with `go install`) need `go`, prettier (npm) needs `npm`, and yamllint (pypi, installed into a venv) needs a `python3` that can `import venv, ensurepip` — Debian/Ubuntu's python3 cannot until `python3-venv` is installed. Without the conditions Mason's install failed on such machines and mason-tool-installer retried and reported it on **every** start. Where a formatter is skipped, conform falls back to the LSP — except for Go without a Go toolchain, where gopls is skipped too and there is nothing to fall back to. `:MasonToolsClean` is replaced by a refusal: it uninstalls every Mason package not in mason-tool-installer's own list, which would be every LSP server.

**Trade-offs.** First launch on a new machine downloads a handful of tools in the background; quitting mid-download aborts that install until the next start. Note that ktlint is a JVM tool, so Kotlin formatting — unlike Kotlin *editing*, which kotlin-lsp serves from its own bundled runtime — needs a JDK on `PATH`.

---

## Blame annotate: blame.nvim per-line, plus a per-scroll repaint

**Context.** The gitsigns blame pane groups consecutive lines of one commit —
header on the first row, the message on a later row, brackets spanning — so
reading horizontally misattributes rows even when alignment is perfect. On top
of that, two real defects stacked: scrollbind's relative offset goes stale
after jumps (a 10-line topline divergence was captured live), and screen
pixels were observed lagging provably-correct internal state.

**Decision.** Replace the pane with blame.nvim's window mode — every line
shows its own commit/author/date, strict 1:1 — keep a WinScrolled topline
re-sync scoped to it, and force a full repaint (`redraw!`) on every window
scroll.

**How.** `<leader>gb` toggles; focus stays in the editor. The repaint (~0.9ms
each) is **throttled** to at most one per 30 ms: events inside the window
coalesce into the pending repaint, which fires after them and therefore still
paints the final state. It was originally un-debounced, but `redraw!` clears the
whole terminal, so held-key scrolling pushed a full screen per event (noticeable
over WSL/SSH). A 25-event scroll burst now yields one repaint.

*Later:* the same throttled repaint also fires when a buffer's **line count** changes, because deleting or pasting whole lines (`dd`, `p`, `o`, undo) shifts every row below and the gutter or blame pane can lag just as it does on a scroll. Line counts are tracked per buffer on `TextChanged`/`InsertLeave`, so cursor motion and in-line edits never trigger it. Both autocmds live in `set.lua` (`ScrollRepaint`, `LineCountRepaint`), and the topline re-sync lives in `lua/plugins/git.lua`. That re-sync matches the editor window by `buftype == ""`, not by `'diff'`: `gitsigns.diffthis` sets `'scrollbind'` and `'diff'` on both halves, and excluding `'diff'` windows silently disabled the re-sync while a diff was open.

**Trade-offs.** Diagnosing this took three stacked root causes; the lesson
encoded here: verify against the live session (sockets, screenpos, git blame
ground truth), not reconstructions.

---

## Editing plugins: load in new files, built-in commenting, small behaviours

**Context.** A review found several small gaps: nvim-surround, gitsigns, git-blame
and indent-blankline lazy-loaded only on `BufReadPre`, which `:e brand_new.kt`
never fires (it fires `BufNewFile`), so a new file had no `ys`/`ds`/`cs`, no
gutter and no indent guides; Comment.nvim duplicated Neovim's built-in commenting;
F2 reopened a terminal whose shell had died; searches were case-insensitive even
with capitals; and `<leader>td` used a deprecated gitsigns API.

**Decision / How.**
- Those four plugins load on `{ "BufReadPre", "BufNewFile" }`. The `lsp.lua`
  warning against `BufNewFile` applies to nvim-lspconfig only — it has to catch the
  buffer's own `FileType`; these just register keymaps/autocmds. Verified on a new
  file: filetype, treesitter and LSP attach unaffected.
- **Comment.nvim dropped** for Neovim's built-in `gc`/`gcc`/`gc{motion}` (0.10+,
  treesitter-aware for embedded languages). Its extras — `gb` block comments and
  `gco`/`gcO`/`gcA` — were not used.
- **F2** checks the terminal's job is still running (`jobwait(…, 0)`). Neovim only
  wipes a terminal whose shell exits 0, so after a non-zero exit the buffer lingered
  as `[Process exited N]`; now a fresh shell is started instead. The dead buffer is
  wiped when no window shows it; one still shown elsewhere (another tab) is only
  forgotten and set `bufhidden=wipe` — deleting it would close that tab — so it
  disappears once that window moves on. F2 finds the terminal's window in the
  current tab each time (a single remembered handle opened a second window in a
  tab that already showed it), and as a tab's only window it switches to the
  alternate buffer instead of failing with `E444`. `scripts/tests/terminal_toggle.lua`.
  *Later:* that check counted floating windows too, so with ui2's message floats
  (or fidget, a hover) open it still hit `E444`; only split windows count now.
- **`smartcase`** alongside `ignorecase`: a capital in the pattern makes that
  search case-sensitive (`*`/`#` are unaffected).
- **`<leader>td`** → `gitsigns.preview_hunk_inline` (the supported replacement for
  the deprecated `toggle_deleted`). It previews the hunk under the cursor rather
  than toggling deleted lines for the whole buffer.

**Trade-offs.** `preview_hunk_inline` is per-hunk and transient where
`toggle_deleted` was a persistent whole-buffer view. Hunk stage/reset keymaps were
considered and **not** added: under the default whole-branch gutter base, gitsigns'
`reset_hunk` would restore `main`'s version (discarding committed branch work) and
`stage_hunk` would apply a fork-point diff to the index — staging stays in lazygit.

---

## Buffer navigation replaces harpoon

**Context.** Harpoon's value is stable pinned-slot jumps (`h1`–`h4`); actual
usage was only cycling through open files — which the buffer list does
natively, without curation overhead or an extra plugin.

**Decision.** Remove harpoon. `<leader>]`/`<leader>[` cycle buffers (the same
keys harpoon used, so muscle memory carries), `<leader>fb` opens a
most-recent-first Telescope picker where `dd` (normal mode) or `Alt-d`
(while filtering) closes the highlighted buffer.

**Trade-offs.** No stable numbered jumps — the feature nobody pressed.

---

## Inline images: raster only, SVG opens as source

**Context.** snacks.nvim renders images over the kitty graphics protocol,
which WezTerm ships **disabled** (`enable_kitty_graphics = true` is set in
`.wezterm.lua`; `wezterm imgcat` working proves nothing — it uses the iTerm2
protocol). SVG rasterization stacked failures: ImageMagick's built-in MSVG
renderer (no librsvg delegate) silently produced empty output for some files
and can't parse modern CSS like drawio's `light-dark()`.

**Decision.** Keep inline viewing for png/jpeg/gif/webp; exclude SVG so
`.svg` opens as XML source — usually the more useful view anyway. (The exclusion
needs no setting: snacks' default image formats omit svg, and
`lua/plugins/snacks.lua` does not add it.)

**Trade-offs.** Visual SVG review happens in the browser. PDF would need
ghostscript; not installed.

---

## Helmfile/gotmpl support

**Context.** All Go templates in use are helmfile templates
(`*.yaml.gotmpl`); Neovim detects neither gotmpl nor helm filetypes natively.

**Decision.** Map `*.yaml.gotmpl` → `helm` (the combined yaml+gotmpl grammar)
and `*.gotmpl` → `gotmpl`; auto-install both parsers; enable helm-ls.

*Later: real Helm charts.* Chart templates do not use `.gotmpl`. They are plain
`<chart>/templates/*.yaml` (and `*.tpl` helpers) containing `{{ }}`, which is not
valid YAML. Nvim called them `yaml`, and yamlls reported every template delimiter
as an error (1393 diagnostics on one `statefulset.yaml`), while helm_ls never
attached. `*.tpl` files landed on `mustache`/`smarty`. Both patterns now map to
`helm`, and `.yml.gotmpl` joins `.yaml.gotmpl`. The rule applies only when some
`templates/` ancestor's parent holds a `Chart.yaml` (or `Chart.yml`). `templates/`
alone is not Helm-specific: matching it claimed Ansible roles, Spring
`resources/templates/`, CloudFormation and `.github/templates` as `helm`, which
lost yamlls validation and made `<leader>gf` a no-op on them.

**How.** Note the 0.11+ gotcha encoded in set.lua: `vim.filetype.add`
patterns are implicitly anchored, so they need a leading `.*` — the old
`%.ext$` style silently never matches.

**Values, compose and CI files.** helm_ls attaches to `helm` *and*
`yaml.helm-values`, but nothing assigned the latter, so a chart's `values.yaml`
only ever got yamlls. `values*.yaml` beside a `Chart.yaml` now gets
`yaml.helm-values` (same chart gate as templates); compose files and
`*.gitlab-ci.yml` get `yaml.docker-compose` / `yaml.gitlab` (exact names, so
`composer.yml` is not claimed). Every YAML-keyed consumer resolves the compound
filetype back to `yaml`: treesitter's `get_lang` uses the part before the dot,
conform tries the whole filetype then each part, and `indent_scope` and
`incremental_selection` accept `yaml` or any `yaml.*` (`indent_scope` first
listed the three explicitly). Inside a
chart's `templates/`, the template rules (priority 20) outrank the compose, CI
and values rules (priority 10): equal priorities are tried in no fixed order,
which made `templates/docker-compose.yml` compose but `templates/compose.yaml`
helm. *Later:* the values rule `values[^/]*.yaml` also claimed `valuesfoo.yaml`;
it now matches `values.yaml` and `values-`/`_`/`.<suffix>.yaml` only.

**Trade-offs.** helm-ls targets charts, so on helmfiles it provides template-
language help (hover on `.Values`, function completion) but no
helmfile-schema intelligence.

---

## Backgrounds: 30% darker, desaturated toward grey

**Context.** The stock onedark "deep" backgrounds carry a strong blue cast
and were brighter than wanted.

**Decision.** Override the palette keys (`bg0`–`bg3`, `bg_d`) once — every
highlight group derives from them, so the editor, floats, Pmenu, Telescope,
nvim-tree, and statusline all shift together, preserving the depth hierarchy.

**How.** 30% darker than stock, then ~60% of the remaining blue pulled toward
neutral (editor `#16181c`). Verified every surface resolves to the new
palette; note that probing `Normal` from inside the auto-opened nvim-tree
window reads the tree's winhighlight, not the global value — measure from a
file window.

*Later:* `transparent = true` was set when WezTerm moved to Catppuccin Mocha
(commit `77973ee`). onedark then leaves the editor, sign column and nvim-tree
backgrounds (`bg0`, `bg_d`) unpainted, so they show WezTerm's `#181825` rather
than `#16181c`. `bg1`–`bg3` still colour floats, Pmenu, the cursorline and
selections, so the overrides above still matter there. Colours pre-blended
toward `#16181c` were not re-blended for the new background: the inlay-hint
tints in `colorscheme.lua` and the diff backgrounds in `git/delta.gitconfig`.

---

## WezTerm tabs: task-aware titles

**Context.** Directory-basename titles can't distinguish "shell in repo X"
from "claude running in repo X".

**Decision.** Shell in the foreground → directory (a place); TUI in the
foreground → `[app] dir` (a task), with the `[app]` segment bold. Titles are
untruncated by choice.

**Trade-offs.** Per-segment font size is impossible in WezTerm's tab bar —
bold and colors are the only emphasis available.

**Depends on cwd tracking.** The title is derived from `pane.current_working_dir`,
so anything that breaks WezTerm's view of a pane's cwd silently degrades this
feature. On Windows that means the WSL session must be launched as a **domain**
(`wsl_domains` + `default_domain`), not via `default_prog = { 'wsl.exe', ... }` —
the latter is an opaque child process WezTerm cannot introspect. The historical
[deviations-from-main.md](deviations-from-main.md) records how this was found.

**On WSL the process name is unusable, so the shell reports it instead.** WezTerm
runs on the Windows side, so a WSL pane's `foreground_process_name` is the
Windows host process — `wslhost.exe` — not the Linux program. WezTerm cannot see
into the distro's process tree. Left alone, every WSL tab renders
`[wslhost.exe]` instead of `[claude]`.

The fix is to invert the direction: the shell *inside* WSL announces what it's
running. `.zshrc` registers zsh `preexec`/`precmd` hooks that publish the command
line as the **`WEZTERM_PROG` user var** (OSC 1337 `SetUserVar`, base64) and the
cwd via **OSC 7**; `pane_prog()` in `.wezterm.lua` prefers that user var and only
falls back to `foreground_process_name` on macOS, where it is accurate. *(More
precisely, the fallback runs on every platform whenever the user var is empty.
Windows-side WSL host names, `wslhost.exe` and `wsl.exe`, map to "no program",
so an idle WSL pane shows its directory.)*

This also gives a cleaner definition of "at a prompt" than the `shells` table:
`precmd` sets `WEZTERM_PROG` to the empty string, so an idle pane is *explicitly*
idle rather than inferred from a hardcoded list of shell names. The `shells`
table remains for the macOS (and native Linux) fallback path.

Note this install ships no `shell-integration/wezterm.sh`, so the two hooks are
hand-rolled — about ten lines, and they avoid depending on a file whose path
differs per platform and per install method.

**The OS window title is a separate hook.** `format-tab-title` labels the strip
at the top of the window — with `use_fancy_tab_bar` on (the default), that strip
is drawn *into* the titlebar region, which is why `window_frame` styles it and
why it can read as "the menu bar". What it does **not** set is the OS-level
window title: the taskbar entry, Alt-Tab, and the window list. That comes from
`format-window-title`, which by default derives from the active pane's title —
uninformative for a WSL pane. Both hooks now share `pane_dir_basename()` and
`pane_prog()`, so the two titles can't drift; the window title drops the per-tab
index and appends a tab count instead, since its job is telling *windows* apart
rather than tabs.

---

## WezTerm config: one cross-platform file, not a per-machine fork

**Context.** This config started macOS-only. The Windows machine kept a
hand-edited copy, and the two drifted **in both directions**: Windows gained the
WSL boot and `Ctrl`/`Alt` key remaps, macOS gained `enable_kitty_graphics` and
the task-aware tab titles. Each file ended up missing something the other had —
and because a missing `enable_kitty_graphics` produces *blank image buffers with
no error*, the loss went unnoticed.

**Decision.** One file, branching on `wezterm.target_triple`, copied to both
machines.

**How.** `local is_windows = wezterm.target_triple:find("windows") ~= nil` gates
the three things that genuinely differ: the modifier set (`Cmd`/`Opt` vs
`Ctrl`/`Alt`, emitting identical keys either way), font sizes, and the WSL
domain block. Everything else — fonts, colors, kitty graphics, padding, tab
titles — is shared, so a feature added once lands on both.

*Later:* native Linux (Debian, Fedora) was added (`77973ee`). An `is_linux` check
joins `is_windows` for the `Ctrl`/`Alt` key set. Font sizes (12 on Windows, 15
elsewhere) and the WSL domain block still branch on `is_windows` alone. The same
change moved the shared colours to Catppuccin Mocha.

**Why not a symlink from the repo?** WezTerm runs on the *Windows* side and
reads `C:\Users\<you>\.wezterm.lua`; a WSL symlink into `~/.config/nvim` isn't
resolvable from there. The file is copied, so the repo stays the source of
truth and the copy is the deployment step.

---

## Git gutter: whole-branch base by default, IntelliJ-style

**Context.** gitsigns diffs each file against the index, so a line loses its
gutter marker the moment it's committed. IntelliJ instead marks every line
changed anywhere on the current branch — a per-branch review view that survives
committing. The user wanted that as the default.

**Decision.** Default each buffer's gitsigns base to the branch fork point
(`git merge-base HEAD main`, falling back to `master`), so committed-on-branch
and uncommitted lines all stay marked. `<leader>gB` toggles the buffer back to
the plain index view and back. Sign colors are set explicitly — add=green,
change=blue (matching IntelliJ's "modified" marker), delete=red.

**How.** The base can't be set in `on_attach`: gitsigns' initial index-based
diff is still in flight and lands *after* — and overwrites — an early
`change_base` (verified live: the base flag was set but the effective diff
stayed at the index). So we latch on the first `User GitSignsUpdate` for the
buffer, which fires once that initial diff settles, then apply `change_base`
via `nvim_buf_call` (it acts on the current buffer, and during the event the
file often isn't current). Applied once only, so a later manual toggle to the
index view isn't clobbered. The merge-base is cached per git-toplevel **and per
HEAD**, so switching branches recomputes it — keying on the repo alone made every
branch after the first silently reuse the first branch's fork point for the rest
of the session.

**Re-applying on a branch switch.** The per-HEAD cache alone did not help buffers
that were *already open*: the latch applies the base once, so after
`git checkout other-branch` they kept diffing against the old branch's fork point
until reopened. Each buffer now records whether it *wants* the whole-branch view
(default yes; `<leader>gB` to the index view opts out) and the HEAD its base was
computed for, and every wanted buffer whose repo HEAD moved has its base
recomputed and re-applied — or reset to the index view when the file is new on
the new branch.

*When* HEAD moved is the hard part. gitsigns' own events do not say: its
data-less `GitSignsUpdate` fires only when the branch **name** changes (and only
for the repo nvim's cwd is in), and its per-buffer update only fires when that
buffer's hunks change — against a fixed fork-point base, a `git rebase main` or a
commit changes nothing, so no event arrives. So each repo's git dir and its
`logs/` are watched directly (`vim.uv` fs_event; `logs/HEAD`, the reflog, is
appended on every HEAD move), debounced into one pass; the data-less event and
`FocusGained` also trigger a pass. **Every** git call is async (`vim.system`):
an earlier version made only the first call async, and each buffer then ran
`for-each-ref`, `merge-base` and `cat-file` synchronously — 40 open files froze
the editor for 2–3 s per HEAD move. A pass is one `rev-parse --absolute-git-dir
HEAD` per repo, one fork-point lookup per repo and HEAD (shared by its buffers,
`merge-base` against that HEAD SHA so the result matches its cache key) and one
`cat-file` per buffer whose fork point changed. The repo is the one **gitsigns**
diffs the buffer against (`b:gitsigns_status_dict.root`, realpath'd): resolving
it separately gave a file opened through a symlink the wrong repo, and a
sub-directory turned into a nested repo mid-session the inner repo's sha while
gitsigns stayed on the outer one. A repo opened before its first commit is
watched from the start (rev-parse still prints the git dir), and watchers are
per path (`logs/` appears with the first commit). Buffers whose
HEAD is unchanged are skipped, and `change_base` — a full re-diff — runs only
when the fork point itself moved (two branches off the same commit of main share
it). A `<leader>gB` opt-out survives a re-attach (`:edit`). Verified in a scratch
repo with no focus events: a same-fork switch re-diffs nothing; a new-fork
switch, and a rebase onto an advanced main, re-apply; a commit that keeps the
fork re-diffs nothing; an opted-out buffer stays on the index across `:edit` and
a switch. `scripts/tests/whole_branch.lua` runs all of this against real gitsigns
and asserts no synchronous git call happens during a pass. Per-buffer autocmds
live in a per-buffer augroup, so `:edit` no longer stacks them. *Later:* the
git-dir watchers were only closed on error, so every repo opened stayed watched
for the session; wiping a repo's last buffer now closes them (counted in
`whole_branch.lua`).

The reference search is local `main` → `master` → `origin/main` → `origin/master`.
The remote-tracking fallbacks matter for a `--single-branch` clone or a
`git worktree` checkout, neither of which necessarily has a local `main` ref.

One subtlety in the latch: gitsigns emits `User GitSignsUpdate` from several
places and only the per-buffer one carries `data.buffer` — the HEAD-watcher and
setup emits pass no `data` at all. The handler must guard before indexing it, or
every data-less emit (notably every branch switch) throws once per attached
buffer.

**Trade-offs.** gitsigns keeps one base per buffer, so committed-on-branch and
still-uncommitted lines share the same sign — the color encodes the change
*type*, not its commit state; distinguishing the two would need a second sign
source. The fork point only moves when HEAD or main's history relative to it
does; the automatic pass watches HEAD, so if `main` alone moves in a way that
changes the merge-base (commits from the branch merged into it), re-open or
double-toggle to re-pin — the cache is keyed by HEAD *and* the main/master ref
SHAs, so that recomputes. Reaches into a private detail (the
`GitSignsUpdate` event + `change_base` timing) that a gitsigns rewrite could
change; the fallback is a silent no-op to the normal index view.

---

## Inlay hints: re-tinting core's extmarks per kind

**Context.** Neovim paints every inlay hint with the single `LspInlayHint`
highlight group, discarding the LSP kind (Type vs Parameter). The goal was
IntelliJ-like per-kind coloring — a type hint in the type color, a parameter
hint in the parameter color, each faded toward the background.

**Decision.** `lua/tajbanana/inlay_tint.lua` re-tints the rendered hints rather
than replacing the renderer: it reads `vim.lsp.inlay_hint.get()`, buckets hints
by `(line, character)` exactly as core does, and rewrites each hint extmark's
`virt_text` highlight to `LspInlayHintType` / `LspInlayHintParameter` (colors in
`colorscheme.lua`). Chunks are matched to hints by **label text**, not by list
position: core assembles the chunks with `pairs()` over clients, so when two
hints share a position their order is unspecified, and the original positional
pairing could paint a type hint in the parameter colour. Each chunk's text is
exactly the hint's label (a string, or its parts joined), and each hint is
consumed once. `scripts/tests/inlay_tint.lua` renders the two hints in reverse
order; it fails against the positional version.

**How.** Core renders hints via a decoration provider that sets persistent
(`ephemeral=false`) extmarks in the `nvim.lsp.inlayhint` namespace, but only on
screen redraw. So the module re-tints on the events that trigger a re-render
(`LspAttach`, `TextChanged`, `CursorHold`, `LspProgress`, `WinScrolled`, …),
debounced; core's applied-version guard means a re-tint sticks until the next
edit. This is also why it can only be verified with a screen attached — headless
Neovim never redraws, so the extmarks never exist (which made it look broken
when first tested headless).

**Trade-offs.** It rewrites extmarks owned by core's private namespace, so a
Neovim renderer change could break the tinting — hints then fall back to plain
`LspInlayHint` grey, nothing worse. The LSP hint only carries a coarse kind, so
builtin vs named types can't be told apart at this layer.

---

## Indent guides: YAML and Helm scope boundaries

**Context.** Selecting the correct syntax node did not guarantee correct guide placement. YAML nodes can end at column zero after trailing blank lines or at the next sibling. indent-blankline reads that endpoint as an inclusive line and uses the smaller indentation of the first and last lines, pulling the guide toward the left margin. Helm also exposes YAML through an injected language tree; handling only the `yaml` filetype left chart templates without the same correction.

**Decision.** `lua/tajbanana/indent_scope.lua` selects multiline mapping pairs and sequence items, then presents a trimmed endpoint to indent-blankline through a node wrapper. The syntax tree and file contents remain unchanged. In `helm` buffers, cursor lookup anchors at the first nonblank character of the line so an embedded `{{ ... }}` value does not switch lookup away from the surrounding YAML key or list marker.

**Validation and limits.** `scripts/tests/indent_scope.lua` checks both scope selection and rendered virtual-text columns, including trailing blank lines, following siblings, and cursor movement through Helm expressions. Helm's parser and YAML injection queries must be installed. These are headless overlay checks, not terminal screenshots. Template-only directives have no separate Go-template scope guide, and malformed syntax can still limit the injected tree. The wrapper depends on indent-blankline's internal scope API, so plugin updates should be checked with this test script.

**Scope of the module since.** The same `ibl.scope` override now also serves Kotlin, TypeScript/TSX, JavaScript/JSX, Lua and Python. For each it adds node types that ibl's defaults lack, such as multi-line calls, object and array literals, and Lua tables. Without them, the guide inside a multi-line `{ … }` jumped out to the enclosing function. The override skips single-line scopes, except Kotlin property declarations, so inline arguments keep the enclosing guide. Every compound `yaml.*` filetype scopes as YAML. For all of these languages, the cursor lookup uses the first nonblank character when the cursor sits in the indentation.

---

## Markdown: in-buffer rendering, browser preview declined

**Context.** `.md` files (this repo's own readme/CHANGELOG/docs, plus notes)
showed as raw text. The want was to *read* them formatted without leaving the
editor.

**Decision.** `render-markdown.nvim` (`lua/plugins/markdown.lua`) renders
headings, lists, code blocks, tables and checkboxes **in the buffer**, on the
markdown filetype, using the treesitter `markdown` + `markdown_inline` parsers.
`<leader>md` toggles it. A read-only float (glow) and a browser preview
(markdown-preview.nvim) were both declined — the point was to stay in the
keyboard-driven editor, and the hybrid render (raw source under the cursor and
in insert mode) keeps editing unaffected.

**Trade-offs.** Needs the `markdown_inline` parser alongside `markdown`. Images
referenced in markdown are **not** previewed inline: snacks' document-image
integration is disabled because WezTerm lacks kitty unicode-placeholder support,
so it fell back to a floating window that popped up on cursor-over-link.
