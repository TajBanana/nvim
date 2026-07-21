# Design decisions

The *why* behind this config — the non-obvious decisions, what drove them, how they work, and what they cost. The [readme](../readme.md) covers *how to use* the config; this covers *why it is the way it is*. Read it when a choice here looks surprising, before changing it.

Each entry is **Context → Decision → How → Trade-offs**.

---

## Plugin manager: lazy.nvim (migrated from packer)

**Context.** The config originally used packer.nvim. Packer is unmaintained, compiles a `packer_compiled.lua` that drifts out of sync, and has no built-in lazy-loading ergonomics.

**Decision.** Migrate to [lazy.nvim](https://github.com/folke/lazy.nvim). Every file in `lua/plugins/` returns a spec table; lazy auto-discovers them.

**How.** `init.lua` loads core settings (`lua/tajbanana/set.lua`) first, then bootstraps lazy and calls `require("lazy").setup("plugins")`. Plugins lazy-load on `keys`/`cmd`/`event` triggers, so startup only pays for what a session actually uses.

**Trade-offs.** One concern per file means more files, but each is small and independently reasoned about. The old `packer.lua` and all `after/plugin/*.lua` were deleted — no dual system.

---

## LSP: the native `vim.lsp.config` API (not null-ls, not the old lspconfig setup)

**Context.** Neovim 0.11 introduced a first-class LSP configuration API (`vim.lsp.config` / `vim.lsp.enable`). The older pattern was `require('lspconfig').<server>.setup{}`; null-ls (now archived) was the common way to bolt formatters/linters onto the LSP client.

**Decision.** Use native `vim.lsp.config` with Mason + mason-lspconfig for install/enable, and conform.nvim for formatting (not null-ls). This is why the config **requires Neovim 0.11+**.

**How.** `lua/plugins/lsp.lua` sets a wildcard `vim.lsp.config("*", { capabilities })` for cmp capabilities, then per-server overrides. Servers are auto-enabled by `mason-lspconfig` except where a plugin manages one itself (Kotlin — see below).

**Trade-offs.** Ties the config to 0.11+. In exchange: no archived dependencies, less indirection, and server settings live in one obvious place.

---

## The nvm PATH fix (why node-based tooling would otherwise be dead)

**Context.** nvm is *lazy-loaded* in the user's `.zshrc`: `node`/`npm`/`npx` are defined as **shell functions** that source nvm on first call. This keeps shell startup fast — but it means node is **not on `PATH`** when a GUI/terminal launches nvim.

**Decision.** In `set.lua`, if `node` isn't executable, find the newest `~/.nvm/versions/node/*/bin` and prepend it to `vim.env.PATH`.

**How & why it's necessary.** Shell **functions are not inherited by child processes** — only exported env vars and real `PATH` entries cross the process boundary. When nvim spawns an LSP server (or `eslint`/`tsc` via `vim.system`), it execs the real binary or a non-interactive shell that never sourced the `.zshrc` function. So the lazy-load stub is invisible, and without the fix node-based Mason servers die with exit 127. The fix puts a **real** node directory on nvim's `PATH`, inherited by every subprocess. This is also why `<leader>xr`'s eslint/tsc and node-based formatters work.

**Trade-offs.** Picks the *newest* installed node, not a project's `.nvmrc` version — virtually always fine for LSP/lint, only a problem for a project pinned to an old node. A sibling fix appends rustup's proxy dir for cargo/rust-analyzer.

---

## Kotlin: JetBrains kotlin-lsp via kotlin.nvim (not fwcd kotlin-language-server)

**Context.** The default JDK on this machine is Corretto **25**. The long-standing `fwcd/kotlin-language-server` crashes on JDK 25.

**Decision.** Migrate to JetBrains' official **kotlin-lsp** (Mason package `kotlin-lsp`, binary `intellij-server`, lspconfig name `kotlin_lsp`), managed by [kotlin.nvim](https://github.com/AlexandrosAlexiou/kotlin.nvim) rather than mason-lspconfig's auto-enable (hence `automatic_enable = { exclude = { "kotlin_lsp" } }`).

**How.** `lua/plugins/kotlin.lua` calls `require("kotlin").setup{...}`. The Mason binary is `intellij-server`, so `lsp.lua` overrides the cmd to `{ "intellij-server", "--stdio" }`.

**Trade-offs.** kotlin-lsp is powerful (it's the IntelliJ engine) but young, so several LSP features are incomplete or behave unusually — which drove the three sub-decisions below. It also imports the whole Gradle project on open (slow first attach), because it's the IDEA project model, not a lightweight indexer. kapt/MapStruct-generated symbols show "unresolved" because kotlin-lsp doesn't register kapt source roots.

### Kotlin sub-decision: the rename handler override
kotlin-lsp stamps **stale document versions** on rename edits (e.g. version 27 while the buffer is at 35), so Neovim 0.12 rejects the workspace edit with "Buffer newer than edits" and the rename silently fails. The fix overrides the client's `textDocument/rename` handler to rewrite each edit's version with the live buffer version (`vim.lsp.util.buf_versions[buf]`) before applying. An earlier version set the version to `nil`, which crashed nvim 0.12 (`compare number with nil`) — the current version overwrites with the real number.

### Kotlin sub-decision: the `@` completion trigger
kotlin-lsp only declares `.` as a completion trigger, so typing `@` never opens annotation completion. On attach, `@` is appended to the client's `completionProvider.triggerCharacters`.

### Kotlin sub-decision: inlay hints need explicit config
kotlin-lsp (v261+; this machine runs v262) **advertises** the inlayHint capability but returns **zero hints** unless told which hint types to emit — and it requests that configuration *dynamically* via a `workspace/configuration` handshake that kotlin.nvim serves. With a bare `setup({})` the settings block is skipped and no hints appear (this was initially — and wrongly — diagnosed as a server stub). The fix passes `inlay_hints = { enabled = true }`, which populates the `jetbrains.kotlin.hints.*` settings. Verified live: 21 hints on a real controller file.

---

## Treesitter: the `main` branch + the `tree-sitter` CLI

**Context.** nvim-treesitter's `main` branch changed the activation model and requires the `tree-sitter` CLI for `:TSInstall`. Without both, highlighting is inert.

**Decision.** Use the `main` branch, install the CLI via `brew install tree-sitter-cli` (the plain `tree-sitter` formula is lib-only), and start highlighting explicitly.

**How.** A `FileType` autocmd calls `vim.treesitter.start()` (the main branch does not auto-start). Custom captures live in `after/queries/<lang>/highlights.scm` at a priority above the defaults.

**Trade-offs.** Capture names were renamed upstream (`@method.call` → `@function.method.call`, `@parameter` → `@variable.parameter`, `@constant.builtin` booleans → `@boolean`, `@float` → `@number.float`); the colorscheme restores all of these, or onedark defaults leak through.

---

## Colors: onedark + a Material Darker palette, tuned to IntelliJ parity

**Context.** The goal is pixel-level parity with IntelliJ's Material Darker scheme across TSX/TS/Kotlin (and every other installed language), so switching editors isn't jarring.

**Decision.** Base is onedark.nvim (`deep` style) with a custom Material Darker palette and extensive per-capture overrides in `lua/plugins/colorscheme.lua`.

**How.** Three layers stack: Treesitter captures (`@keyword`, `@type`, …), then LSP semantic tokens (`@lsp.type.*`) at higher priority for language-accurate coloring, and language-scoped overrides (`@type.builtin.tsx`, etc.) for per-language differences. Parity was established by pixel-sampling IntelliJ screenshots and matching hex values; `:Inspect` finds the group under any token. Key IntelliJ rules encoded: keywords/booleans/null/this purple italic; interfaces green italic; primitive types purple italic; free functions yellow (TS) or blue (Kotlin); methods blue; classes/types yellow; annotations purple italic.

**Trade-offs.** It's a large declarative table, but flat and single-concern. Per-language scoping (`.tsx` vs `.typescript`) is verbose but necessary — the same capture legitimately differs by language in IntelliJ.

---

## `<leader>gd`: one picker that queries every attached client

**Context.** A buffer often has several LSP clients (a `.tsx` may have ts_ls + eslint + tailwind + graphql). Querying only the first client returns empty results when a *different* client owns the answer. Separate `gd`/`gtd`/`gi`/`gr` keys also fragment muscle memory.

**Decision.** A single `<leader>gd` that merges definition, type-definition, implementation, and references into one Telescope picker, tagged and color-coded by kind.

**How.** It enumerates every client that supports each method, fires all requests, dedups by `file:line:col`, sorts by kind then location, and renders a `[kind]` tag column. Type `def`/`type`/`impl`/`ref` in the prompt to filter.

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

## GitLab shortcuts: isolated module, token-free by default, glab-preferred with a cache

**Context.** "Open this line / this branch's MR in the browser" is forge-specific — GitLab's URL shapes (`/-/blob/…#L`, `/-/merge_requests/…`) don't match GitHub/Bitbucket.

**Decision.** Keep all of it in one module, `lua/tajbanana/gitlab.lua`, and make the MR lookup **token-free by default, better with glab**.

**How.**
- **Isolation:** the module documents the GitLab assumption in one place; disabling is deleting one `require(...).setup()` line.
- **URL normalization:** one `to_web_url` helper converts any remote form (scp-like, `ssh://`, `https://`) to an https web base, stripping `.git`, embedded credentials, and ssh ports — replacing a fragile gsub chain that leaked tokens and mishandled ports. The remote is resolved from the branch's upstream, not hardcoded `origin`.
- **MR lookup, token-free fallback:** GitLab publishes MR heads as `refs/merge-requests/<iid>/head`, so matching the branch SHA against them via `git ls-remote` finds an existing MR with no `glab` and no API token.
- **glab preferred when present:** `glab mr view --output json --jq .web_url` resolves the MR by **source branch via the API**, which is robust to the local SHA drifting from the pushed MR head (the ls-remote SHA-match's blind spot). glab is the official GitLab CLI, so this isn't a third-party gamble.
- **Session cache:** resolving an MR is a ~2s network round-trip (measured: glab ~2.0s, ls-remote ~2.5s, glab process startup only 0.15s — the cost is network latency, not the tool). A branch's MR URL is stable once it exists, so positive hits are cached for the session; repeat opens are instant. "No MR yet" is **not** cached, so a freshly-created MR is picked up next press.

**Why not glab-only?** It would need a PAT (`api` scope) and lose the zero-dependency property that works out of the box. And glab has no command to open an arbitrary file+line, so `<leader>gl` is hand-rolled regardless.

**Trade-offs.** The first MR open on a branch pays the network round-trip; nothing local can shrink that. The lazygit **color theme** lives in lazygit's own `config.yml` (outside this repo), themed to the same Material Darker palette — it can't live in the nvim config because lazygit renders its own TUI.

---

## Repo-wide diagnostics `<leader>xr`: run the real linter, because LSP can't

**Context.** LSP servers only diagnose files that are **open**, so `<leader>xx` can never show problems in files you haven't visited. "Diagnostics on the whole repo" is impossible through LSP alone.

**Decision.** `<leader>xr` runs the project's actual linter over the whole repo and loads the results into the Telescope quickfix picker.

**How.**
- **Tool detection** by project marker (first match wins): `go.mod` → `go vet`; `Cargo.toml` → `cargo check`; `pyproject.toml`/`requirements.txt` → `ruff`; `package.json`/`tsconfig.json` → the **local** `node_modules/.bin/eslint` (lint), falling back to local `tsc` (types).
- **Local binaries, not `npx`:** `npx` is the nvm lazy-load stub in a non-interactive context and fails; the local `node_modules/.bin` binaries exec node, which nvim has on PATH via the fix above. (eslint, not tsc, is the default for JS/TS because "lint" means lint — tsc only catches type errors.)
- **Path resolution:** a leading `%D` "Entering dir" errorformat line makes each tool's relative paths resolve against the repo root regardless of nvim's cwd (the make/quickfix directory-tracking trick).
- **Phantom-entry filter:** the `%D` marker and tools' summary lines parse into quickfix entries with no buffer (`bufnr = 0`); left in, Telescope's open action fails with `E939: buffer 0`. The list is filtered to real file entries before it's shown.

**Trade-offs.** Gradle/Kotlin is deliberately **excluded** — a full `./gradlew compileKotlin` is far too slow to bind to a keystroke. So `<leader>xr` covers Go/Rust/Python/JS-TS but not Kotlin/Java. Adding a stack is a one-line detector.

---

## Diagnostics & undo through Telescope (not Trouble, not the undotree panel)

**Context.** Both the Trouble bottom-panel and the mbbill undotree side-panel are separate window paradigms; the rest of the nav (`ff`/`fw`/`gd`) is a Telescope list-left/preview-right picker.

**Decision.** Route diagnostics (`xx`/`xb`/`xr`) and undo history (`uu`) through Telescope for one consistent left/right picker experience. Trouble stays installed (`:Trouble` command, and a kotlin.nvim dependency); mbbill undotree was removed entirely.

**How.** `telescope.builtin.diagnostics` for xx/xb; `debugloop/telescope-undo` for uu (reads Neovim's native undo tree — no separate plugin state). The undo picker's results column is narrowed (`preview_width = 0.7`) so the diff preview dominates. `TelescopePreviewLine` is given a visible highlight so the jumped-to problem line stands out in the preview.

**Trade-offs.** `xx` shows only *analyzed* buffers (the LSP limitation `xr` exists to work around). Losing the persistent Trouble panel is deliberate — a picker fits the workflow better; the panel is one `:Trouble` away when wanted.

---

## Statusline & UI polish

- **`cmdheight = 0` + `showcmdloc = "statusline"`.** The always-present empty command-line row is reclaimed; pending keystrokes render in the lualine row via a `%S` component. Trade-off: messages flash briefly (recall with `:messages`).
- **Path shortening in the statusline.** lualine's built-in `shorting_target` is *window-relative* (only shortens when the path exceeds `winwidth − target`), so on a wide window deep paths never shortened. Replaced with an `fmt` that keeps the last two segments (`…/controller/ExerciseController.kt`) — predictable and meaningful for deep Java/Kotlin packages, unlike the built-in's single-letter initials.
- **`winborder = "rounded"`.** One global option borders all LSP floats (hover, signature help, diagnostics) consistently; nvim-cmp sets its own border so it doesn't double up.
- **nvim-tree fixed `width = 40`.** Dynamic/adaptive resizing left stale-cell redraw artifacts at the tree's right edge; a fixed width eliminates them.

---

## Formatters: dedicated where configured, LSP fallback everywhere else

**Context.** conform.nvim maps dedicated formatters only for Lua (stylua) and the web filetypes (prettier). Go/Python/Rust/Kotlin/Java/Bash have no dedicated formatter wired up.

**Decision (current state).** `<leader>gf` uses `lsp_format = "fallback"`, so those languages still format — via the language server's own formatting — even without a conform formatter.

**Trade-offs.** LSP formatting is less configurable than dedicated tools (gofmt/goimports, ruff/black, rustfmt, ktlint, shfmt, google-java-format). Wiring those in (conform `formatters_by_ft` + Mason) is the obvious next improvement; until then formatting works, just not through the dedicated tools.
