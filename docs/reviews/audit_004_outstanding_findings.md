## 2026-08-04 — fix/audit-findings-2026-08 — outstanding findings

Two-part audit of the whole config. Part one was a static + empirical review of
every module; part two exercised the **live config against ten public
repositories** across Go, Python, TypeScript/TSX/JS, Lua, Java, Kotlin, Rust,
Helm/YAML and a cross-cutting edge-case sweep.

Everything below was **reproduced by running Neovim**, not inferred from reading
Lua. 56 findings were confirmed across both parts; 25 candidate findings were
refuted under verification and are listed in the last section so nobody spends
time on them.

**7 code fixes and the whole doc-drift set have already shipped on this branch**
(see `CHANGELOG.md`, entry 2026-08-04).

> **STATUS 2026-08-04 (second pass): all 31 findings resolved.** 27 were fixed
> and verified by running the config; 4 were reclassified as not-bugs after
> deeper investigation (L1's residual, L20, L22, and part of L7 — see the
> per-finding notes). The detail below is kept as the record of what was wrong,
> why, and how each fix was proven. Anything marked **NOT A BUG** should not be
> "fixed" later.

This document covered **31 findings — 4 High, 4 Medium, 23 Low**.

Findings are grouped by **root cause**, not by symptom, because several clusters
collapse into a single edit. Fixing the four High items is three code changes.

---

### How to reproduce anything here

A harness lives at `docs/reviews/audit_004_harness.lua` (copy of the one used).
It opens each file in `$NVTEST_FILES` with the real config, waits
`$NVTEST_SETTLE` ms, and writes one JSON line per file to `$NVTEST_OUT` with
filetype, whether a treesitter highlighter actually attached, LSP clients, the
gitsigns base and the diagnostic count — plus a final array of every error that
reached `:messages`.

```bash
export NVTEST_FILES="$(printf '%s\n' /abs/f1 /abs/f2)"
export NVTEST_OUT=/tmp/out.json NVTEST_SETTLE=8000
cd <repo>            # cwd sets the LSP root and the git repo
nvim --headless -c "luafile docs/reviews/audit_004_harness.lua"
```

Two techniques worth remembering, since most logic here is `local`:

- **Reach file-local functions** by walking `debug.getupvalue` from an exported
  closure — `dofile("lua/plugins/git.lua")` → `spec[1].opts.on_attach` →
  `enable_whole_branch` → `merge_base` → `branch_base_cache`.
- **Render the *active* statusline** with `require("lualine").statusline(true)`;
  the no-arg form renders inactive sections and hides duplicate-component bugs.

Test repos used (shallow clones): spf13/cobra, pallets/click, sindresorhus/type-fest,
facebook/react, nvim-lua/plenary.nvim, google/gson, Kotlin/kotlinx.serialization,
clap-rs/clap, prometheus-community/helm-charts, sqlite/sqlite-wasm.

---

## HIGH

### H1 — Every `.rs` buffer throws an unhandled traceback, and Rust renders with no highlighting at all

**Cluster: one root cause, three symptoms (H1, H2, M1). One guard fixes all three.**

`lua/plugins/lsp.lua` — `rust_analyzer` is in `ensure_installed` and is not in
`automatic_enable.exclude`, so `vim.lsp.enable("rust_analyzer")` installs a
`FileType` hook. Upstream `nvim-lspconfig/lsp/rust_analyzer.lua:46`
(`default_sysroot_src`) shells out to `rustc` from inside `root_dir`, **without
guarding that rustc exists**. This machine has no Rust toolchain at all
(`~/.cargo` and `~/.rustup` do not exist; `env.lua`'s `fix_cargo_path()` only
prepends directories that are absent here), so the call raises:

```
BufReadPost Autocommands for "*"..FileType Autocommands for "*":
vim/_core/system:324: ENOENT: no such file or directory (cmd): 'rustc'
  ...lazy/nvim-lspconfig/lsp/rust_analyzer.lua:46: in function 'default_sysroot_src'
  ...lazy/nvim-lspconfig/lsp/rust_analyzer.lua:74: in function 'is_library'
  ...lazy/nvim-lspconfig/lsp/rust_analyzer.lua:90: in function 'root_dir'
  ...runtime/lua/vim/lsp.lua:561: in function 'lsp_enable_callback'
```

The error propagates out of the `FileType` callback and **aborts the rest of the
`BufReadPost` / `FileType` autocmd chain for that buffer.**

- **H1 (this):** a ~20-line red traceback plus a press-ENTER prompt on *every*
  fresh `.rs` buffer — shell `nvim foo.rs`, `:edit`, Telescope, nvim-tree.
  Confirmed on 4/4 files in my own run and 13 files in the fan-out.
- **H2:** because the chain aborts, `treesitter.lua`'s `FileType` hook (which
  calls `vim.treesitter.start`) never runs. Measured directly:
  `ft='rust'`, `syntax=''`, **`treesitter highlighter attached: false`** — the
  file is completely unhighlighted plain text. This depends on autocmd
  registration order, so it varies per nvim start (observed unhighlighted in
  5 of 6 sessions), which makes it maddening to diagnose.
- **M1:** on some runs gitsigns never attaches to `.rs` buffers after the first,
  taking the whole git layer with it — no gutter, no whole-branch base, and none
  of `<leader>gB` / `pp` / `oo` / `gp` / `dv` / `td` or the `ih` text object.
  *Note: gitsigns DID attach in my own single-file reproduction, so this symptom
  is order-dependent rather than universal — verify before and after the fix.*

**Repro**
```bash
cd <clap clone> && nvim clap_lex/src/lib.rs      # traceback, every time
```

**Proposed fix.** Do not enable a server whose toolchain is absent. Either add a
guard in `lsp.lua`:
```lua
automatic_enable = {
  exclude = vim.list_extend({ "kotlin_lsp", "stylua" },
    vim.fn.executable("rustc") == 1 and {} or { "rust_analyzer" }),
}
```
or install a Rust toolchain. Belt-and-braces worth doing regardless: make
`treesitter.lua`'s `FileType` hook order-independent so an unrelated erroring
hook can never cost a buffer its highlighting.

---

### H3 — Helm chart templates are typed `yaml`, drawing thousands of bogus diagnostics; `helm_ls` can never attach

**Cluster: one missing filetype pattern, four symptoms (H3, M2, L-helm×2). One edit fixes all four.**

`lua/tajbanana/set.lua:85-93` maps `.*%.ya?ml%.gotmpl` → `helm` and
`.*%.gotmpl` → `gotmpl`. **Real Helm charts use neither extension** — their
templates are `charts/<name>/templates/*.yaml`. So nothing ever routes a Helm
template to the `helm` filetype, and `yamlls` claims it instead and reports every
Go-template delimiter as a YAML syntax error.

Measured, on the live config:

| File | ft | ts | client | diagnostics |
|---|---|---|---|---|
| `alertmanager/templates/statefulset.yaml` | `yaml` | true | `yamlls` | **1393** |
| `kube-prometheus-stack/.../prometheus.yaml` | `yaml` | true | `yamlls` | **3145** (594/594 lines) |
| `alertmanager/templates/_helpers.tpl` | `mustache`¹ | **false** | `tailwindcss` | 0 |
| `alertmanager/Chart.yaml` | `yaml` | true | `yamlls` | 0 ✓ |
| `alertmanager/values.yaml` | `yaml` | true | `yamlls` | 0 ✓ |

¹ `mustache` in my run, `smarty` in the fan-out — nvim's own guess varies by content.

Because `virtual_text = true`, all of it renders inline: every line of the file
is red. `]e`/`[e`, Trouble and the lualine error count are saturated, and any
genuine yamlls signal is buried.

Consequences that disappear with the same fix:
- **M2:** `helm_ls` is force-installed via `ensure_installed` and delivers zero
  value — no `{{ .Values.* }}` completion, no chart-aware hover. Counter-proof
  it *would* work: setting `vim.bo.filetype = "helm"` on the same file in the
  same cwd attaches `helm_ls` immediately.
- **L1:** `templates/*.tpl` (every chart's naming/label logic) gets no
  treesitter, no LSP, and Smarty regex highlighting of Go-template syntax.
- **L2:** `<leader>gf` on a Helm template pops an ERROR toast, because conform
  routes `ft=yaml` to prettier and prettier cannot parse `{{ }}`.

**Proposed fix.** Add to the `pattern` table in `set.lua`:
```lua
[".*/templates/.*%.ya?ml"] = "helm",
[".*/templates/.*%.tpl"]   = "helm",
```
Guard it on the chart actually having a `Chart.yaml` if you want to avoid
false positives on non-Helm `templates/` directories.

---

### H4 — `<M-Up>` throws `E5108: Invalid 'line': out of range` when the selection reaches the treesitter root

**Cluster: `incremental_selection.lua` has five findings total (H4, M3, L3, L4, L5). Worth one focused rewrite.**

`lua/tajbanana/incremental_selection.lua:16`. nvim's treesitter parser feeds a
trailing newline after the last line, so the ROOT node's end point is
`(line_count, 0)`. `select_node` computes the end mark as `er + 1`, which is one
past the last line, and `nvim_buf_set_mark` rejects it.

Growing the selection to the whole file is *the natural end state* of
IntelliJ-style expand-selection, and it is only 2–5 presses away. **Deterministic
and cross-language** — reproduced in Lua, Go and Python.

My own reproduction on a 2-line Lua file, calling the mapped callbacks directly:
```
press 1 (normal): ok=true
press 2 (visual): ok=true
press 3 (visual): ok=true
press 4 (visual): ok=true
press 5 (visual): ok=false
  ERR=incremental_selection.lua:16: Invalid 'line': out of range
```

The failure is **partial**, which is the nasty part: `'<` is already clobbered
when `'>` fails, and `normal! gv` never runs — so the marks and the on-screen
selection disagree afterwards.

**L5** is the same bug on its narrowest trigger: `<M-Up>` as the very first
action in an empty or brand-new buffer (`nvim newthing.py`) errors immediately.

**Proposed fix.** Clamp the exclusive end before setting the mark: when `ec == 0`,
place the mark at row `er` and the last column of that line rather than
`(er + 1, ec - 1)`; and bail out early when the node already spans the buffer.

---

## MEDIUM

### M1 — gitsigns silently absent on `.rs` buffers
Covered under **H1**. Fixed by the same guard. Re-verify after fixing H1, since
it did not reproduce universally.

### M2 — `helm_ls` never attaches to a real chart
Covered under **H3**. Fixed by the same filetype pattern.

### M3 — Incremental-selection node stack survives leaving visual mode and buffer edits

`lua/tajbanana/incremental_selection.lua:35`. The stack is buffer-scoped (fixed
in review 003) but is never cleared when visual mode ends or the buffer is
edited. After any earlier `<M-Up>` session, selecting fresh text with `v` and
pressing `<M-Up>` **jumps to the parent of the OLD node** rather than expanding
the current selection. The stale-after-edit variant is also real: the retained
`TSNode` keeps its tree alive so `:parent()` still succeeds, but `node:range()`
returns pre-edit coordinates — which after line deletions can exceed the buffer
and trigger the same E5108 as H4.

**Proposed fix.** An augroup clearing the stack on `ModeChanged` (pattern
`[vV\x16]*:*`) plus `TextChanged`/`TextChangedI`. Cheaper 90% fix: in the `x`
mapping, drop the stack when the current `'<`–`'>` span does not match
`stack[#stack]:range()`.

### M4 — Kotlin `<leader>gf` is a no-op on most real Kotlin files

`lua/plugins/formatting.lua`. ktlint exits **1** whenever a file contains a
violation it cannot auto-correct, *even though it has written correctly
formatted output to stdout*. conform treats the non-zero exit as failure and
discards the output, so the buffer is left untouched with only a
"Formatter failed. See :ConformInfo" toast.

Measured on kotlinx.serialization: `standard:no-wildcard-imports` is never
auto-correctable, and **569 of 913 `.kt` files (62%)** contain a wildcard import,
plus `build.gradle.kts`. Direct proof the output is fine:
```bash
ktlint --format --stdin --log-level=none < buildSrc/src/main/kotlin/Projects.kt
# exit 1, but 19 valid formatted lines on stdout
```

Non-destructive and clearly signalled, hence Medium — but formatting is
effectively unusable across most of a real Kotlin codebase.

**Proposed fix.** Give the ktlint formatter an explicit
`exit_codes = { 0, 1 }` in a conform `formatters` override.

---

## LOW

Grouped by file so they can be swept together.

### `lua/tajbanana/incremental_selection.lua` (see also H4, M3)
- **L3 — over-selects by one character** when a node's end column is 0 (it
  swallows a trailing newline). Same off-by-one family as H4.
- **L4 — `normal! gv` reuses the previous visual mode**, so if the last
  completed selection was linewise or blockwise, every expansion in the next
  session is rounded out to whole lines (or a rectangle), and a following `y`/`d`
  takes more than the node.
- **L5 — errors on the first `<M-Up>` in an empty/new buffer.** Duplicate
  manifestation of H4.

### `lua/plugins/lsp.lua`
- **L6 — `tailwindcss` attaches to every Markdown file in any git repo.**
  lspconfig's tailwind `root_files` ends with a bare `.git` fallback and its
  `filetypes` includes `markdown`, so opening a README in a pure Go/Java/Python
  repo spawns a **~97 MB Node process** (measured) offering meaningless class
  completion. Control that isolates it: the same `.md` outside any git repo
  attaches nothing. Fix: add `"tailwindcss"` to `automatic_enable.exclude`, or
  narrow its `filetypes`/`root_dir` via `vim.lsp.config`.
- **L7 — `ts_ls` floods Flow-annotated `.js` with bogus errors.** React's
  `ReactFiberHooks.js`: **1747 diagnostics**, 1537 of them severity-1, all from
  `ts_ls` (`TS8006: 'import type' declarations can only be used in TypeScript
  files`). The file is valid Flow; ts_ls is parsing a dialect it does not speak.
  Confined to Flow projects — ordinary JS and `.ts` are clean (0–2). Note React
  has **no checked-in `.flowconfig`** to key off, so a marker-based opt-out will
  not work on this fixture.
- **L8 — `vim.lsp.config("kotlin_lsp", ...)` is dead code** (lines 125-129, the
  comment plus the block); kotlin.nvim replaces the config wholesale. The
  comment will mislead the next edit.
- **L9 — `LspAttach` / `LspProgress` / `BufWipeout` autocmds have no augroup.**
  Config-development annoyance only: re-sourcing stacks handlers that cannot be
  cleared without restarting.
- **L10 — mason specs still point at `williamboman/*`.** Both 301-redirect to
  `mason-org/*`. No impact today; renaming means lazy re-clones, so do it
  deliberately and re-pin the lockfile.

### `lua/plugins/formatting.lua`
- **L11 — no `jsonc` mapping.** nvim assigns `ft=jsonc` to `tsconfig.json`,
  `jsconfig.json`, `.eslintrc.json`, `devcontainer.json`. Proven divergence:
  byte-identical content as `ascopy.json` (ft=json) is reformatted by prettier
  while `tsconfig.json` (ft=jsonc) is not, so `<leader>gf` produces inconsistent
  style across sibling JSON files. Fix: add `jsonc = { "prettier" }`.

### `lua/plugins/treesitter.lua`
- **L12 — parsers installed at startup do not highlight the buffer that is
  already open.** `:e` or a restart fixes it. Silent because of the `pcall`.

### `lua/plugins/telescope.lua`
- **L13 — `<C-p>` outside a git repo.** Reported as raising a raw Lua error and
  traceback instead of a notification or a `find_files` fallback.
  **⚠ I could not reproduce this headlessly** — `pcall` on the mapping callback
  returned `ok=true` with no message at all. It may be interactive-only (the
  picker needs a UI to run its job). **Verify interactively before fixing.**

### `lua/plugins/git.lua`
- **L14 — blame scroll-sync picks the wrong "editor" window** when any other
  `scrollbind` window exists (e.g. a gitsigns diff split open at the same time),
  re-introducing the exact row drift the block exists to correct.

### `lua/tajbanana/github.lua`
- **L15 — repo-relative path is blind substring arithmetic** with no containment
  check (`file:sub(#root + 2)`). `rev-parse --show-toplevel` resolves symlinks
  but `expand("%:p")` does not, so in a symlinked directory `<leader>gl` opens a
  truncated, wrong blob URL (verified: `.../blob/<branch>/ighlights.scm`) with no
  error. Fix: `vim.fn.resolve(file)` then assert `vim.startswith(file, root .. "/")`.

### `lua/tajbanana/terminal.lua`
- **L16 — toggle state is global**, so F2 in another tabpage hides the terminal
  window in the first tab (and closes that tabpage if it was the last window).
  Non-destructive; a second F2 behaves correctly.

### `lua/tajbanana/repo_diagnostics.lua`
- **L17 — stdout and stderr are concatenated with no separator** before
  errorformat parsing, so an unterminated final stdout line merges with the
  first stderr line and that diagnostic is dropped. Latent.

### `lua/tajbanana/inlay_tint.lua`
- **L18 — per-buffer libuv timers released only on `BufWipeout`**, not
  `BufDelete`/`BufUnload`. Monotonic growth of one idle handle per buffer
  visited; matters only in very long sessions.

### `lua/tajbanana/set.lua`
- **L19 — `guicursor+=a:blinkon500` does not enable blinking.** Verified:
  blinking needs `blinkwait`, `blinkon` *and* `blinkoff` non-zero; only
  `blinkon` is set, so the cursor has never blinked. Purely a misleading comment.

### `lua/plugins/kotlin.lua`
- **L20 — `buildSrc/` and `integration-test/` get their own `kotlin_lsp` root**,
  so one repo spawns **three concurrent `intellij-server` JVMs (~2.9 GB
  observed)** sharing a single `--system-path` workspace, each redoing its own
  Gradle import.

### Repo hygiene
- **L21 — `lua/tajbanana/github.lua` is still untracked** while the
  `gitlab.lua` deletion is already staged. **Action required before the next
  commit:** `git add lua/tajbanana/github.lua`, or the resulting commit boots
  with `module 'tajbanana.github' not found` and takes the whole lazy bootstrap
  down on a fresh clone.
- **L22 — `.gitignore` has five dead IntelliJ rules** (`/shelf/`,
  `/workspace.xml`, `/httpRequests/`, `/dataSources/`,
  `/dataSources.local.xml`) and a `/.idea` rule that conflicts with
  `.idea/.gitignore` + `.idea/nvim.iml` being tracked. Intent is ambiguous —
  confirm before changing.

### Documentation
- **L23 — `definition_picker` opens in `initial_mode = "normal"`** while its
  header comment says "type … to filter". The readme now says "opens normal
  mode", so this is down to the module comment at `definition_picker.lua:3` and
  the one above `lsp.lua:223`. Either amend the comments or drop `initial_mode`.

---

## Refuted — do not spend time on these

25 plausible-sounding candidates died under verification. Recording them so they
are not re-raised:

**From the static audit:** colorscheme overrides being wiped on `:colorscheme`
reload (they survive — verified); the nvim-tree gitignore-mirror using a wrong
API (`filters.state.git_ignored` is real and correct); `inlay_tint`'s `retint()`
rescanning the whole buffer on every scroll; insert-mode `<C-h>` shadowing
backspace; `@none` overriding the treesitter reset marker inside string
interpolations; which-key getting an unbudgeted border from `winborder`;
`<leader>e` being a pure duplicate of `<leader>vd` (they differ in scope and in
whether an LSP is required); WezTerm tab titles depending on a `.zshrc` snippet
absent from the repo.

**From the public-repo sweep:** `go.mod`/`go.sum`/`Makefile` lacking treesitter
highlighting; `<leader>xr` discarding ruff findings on ANSI colour; pyright
inlay-hint settings being inert; `<leader>gf` being a silent no-op on Python and
on Markdown; jdtls flooding gson tests with "var cannot be resolved" and
`module-info.java` syntax errors; `kotlin_lsp` never attaching at the repo root;
`intellij-server` outliving nvim; `rust_analyzer` "never spawning" (it is the
*error*, H1, that matters, not the non-spawn); `Chart.lock` getting an empty
filetype (stock nvim does the same); tailwindcss attaching to the snacks
image-viewer placeholder buffer.

One earlier claim of mine was **partially** refuted and is worth stating
precisely: the whole-branch gutter's *silent* fallback when no `main`/`master`
exists is documented intent, not a bug. The genuine gap was the missing
`origin/*` fallback — **already fixed** on this branch.

---

## Environment caveats affecting these results

- **No Rust toolchain** on this machine (`~/.cargo`, `~/.rustup` absent), which
  is what triggers H1. Installing one makes H1/H2/M1 disappear without any config
  change — but the config should still not hard-error when a toolchain is missing.
- JDK is SDKMAN **Temurin 21.0.12** (not the Corretto 25 named in
  `design-decisions.md` — that was the original machine; the doc now says so).
- Running the config headless completes any pending treesitter parser installs
  into `~/.local/share/nvim/site/parser`. It does **not** touch `lazy-lock.json`.
- `Lazy! sync` upgrades every plugin, not just missing ones. Use
  `Lazy! restore` to return to pinned commits if that happens by accident.

---

## Resolution log — 2026-08-04, second pass

Every item below was verified by running the config against the same public-repo
fixtures that surfaced it. Measurements are before → after.

### High

- **H1 / H2 / M1 (Rust)** — FIXED in `lsp.lua`. `rust_analyzer` is now added to
  `automatic_enable.exclude` unless *both* `rustc` and `cargo` are executable, so
  the unguarded upstream `root_dir` never runs on a toolchain-less machine.
  Verified on clap: errors **4 → 0**, and `ts` (treesitter highlighter attached)
  **false → true** on every `.rs` file. Rust now renders correctly.
- **H3 / M2 (Helm)** — FIXED in `set.lua` with two `vim.filetype.add` patterns
  (`.*/templates/.*%.ya?ml` and `.*/templates/.*%.tpl` → `helm`, priority 10).
  Verified on prometheus-community/helm-charts: `statefulset.yaml` went
  `ft=yaml, yamlls, **1393 diagnostics**` → `ft=helm, helm_ls, **1 diagnostic**`.
  `Chart.yaml` and `values.yaml` correctly stay `yaml` on `yamlls`.
- **H4 / L3 / L5 (`<M-Up>`)** — FIXED by rewriting `incremental_selection.lua`.
  A new `inclusive_end()` converts treesitter's exclusive end point into a valid
  inclusive mark, clamped to the buffer. Verified across Lua, Go and Python: the
  root node ends at `(line_count, 0)` in all of them — the exact condition that
  threw `E5108` — and `select_node` now returns cleanly with the end mark in
  range every time. Ten consecutive expansions on a 2-line file: no error.

### Medium

- **M3 (stale selection stack)** — FIXED. An `IncrementalSelectionReset` augroup
  clears the stack on `ModeChanged` out of visual and on `TextChanged`/
  `TextChangedI`, so a new `v` + `<M-Up>` can no longer expand from the previous
  session's node or use pre-edit coordinates.
- **M4 (Kotlin format no-op)** — FIXED in `formatting.lua` with
  `formatters.ktlint.exit_codes = { 0, 1 }`. ktlint exits 1 on
  non-auto-correctable violations while still emitting correct output on stdout
  (confirmed: exit 1, 19 valid lines). End-to-end: formatting `Projects.kt` now
  reports `changed=true` — previously a silent no-op.

### Low

- **L1 (`.tpl` filetype)** — FIXED, with a **correction to the original
  finding**. A `.tpl` with no modeline now resolves to `ft=helm` with `helm_ls`
  attached and treesitter on. The files that still show `mustache` do so because
  **26 of 47 `.tpl` files in that repo carry a literal
  `{{/* vim: set filetype=mustache: */}}` modeline** — the file explicitly asking
  for that filetype. Respecting it is correct; **NOT A BUG**.
- **L2 (Helm format toast)** — resolved as a consequence of H3: `ft=helm` no
  longer routes to prettier's YAML parser.
- **L4 (`gv` reuses visual mode)** — FIXED: `select_node` re-enters charwise
  explicitly when `gv` does not land in `v`.
- **L6 (tailwindcss everywhere)** — FIXED: added to `automatic_enable.exclude`.
  Verified: `go-cobra/README.md` went `clients=tailwindcss` → `clients=-`, so the
  ~97 MB Node server no longer spawns on Markdown in non-frontend repos.
- **L7 (ts_ls on Flow)** — FIXED via a `root_dir` **veto** in
  `vim.lsp.config("ts_ls", ...)`: if a `javascript` buffer's first 20 lines carry
  an `@flow` pragma, `on_dir()` is never called and no client starts. Verified:
  `ReactFiberHooks.js` went `clients=eslint+ts_ls, 1747 diags` →
  `clients=eslint, 0 diags`, while plain `dangerfile.js` keeps `ts_ls` and
  TypeScript in type-fest is unaffected (`ts_ls`, 0 diags).
  **Worth recording:** the first attempt — detaching from `LspAttach` — *looked*
  like it worked (diags hit 0) but was wrong. `vim.lsp.buf_detach_client` left
  the client attached and only the overly broad `vim.diagnostic.reset(nil, buf)`
  was hiding the diagnostics until the next publish. `root_dir` is the only hook
  nvim calls per-buffer before starting a client.
- **L8 (dead kotlin_lsp config)** — FIXED: block removed. Safe because upstream
  `nvim-lspconfig/lsp/kotlin_lsp.lua` already defaults to
  `cmd = { 'intellij-server', '--stdio' }` — the identical value.
- **L9 (no augroup)** — FIXED: all three autocmds now use a single
  `TajbananaLsp` augroup with `clear = true`.
- **L10 (mason repo rename)** — FIXED: specs point at `mason-org/*` and the
  installed clones were re-pointed. The lockfile keys are basenames, so the
  pinned commits carried over unchanged (`2a6940af8037`, `916c29ee6269`) — no
  version drift.
- **L11 (no `jsonc` formatter)** — FIXED: `jsonc = { "prettier" }`. Verified
  end-to-end: `tsconfig.json` (`ft=jsonc`) now reports `changed=true`.
- **L12 (parsers don't retro-highlight)** — FIXED: a `User TSUpdate` autocmd
  re-runs `vim.treesitter.start` over every loaded buffer after an install.
- **L13 (`<C-p>` outside a repo)** — FIXED defensively. The original error was
  never reproducible headlessly, but `<C-p>` now checks `gitutil.toplevel()` and
  falls back to `find_files`. Verified in a non-git directory: `ok=true`.
- **L14 (blame scroll-sync)** — FIXED: the editor-window search now skips
  `diff` windows, so a `gitsigns.diffthis` split can no longer be mistaken for
  the source window.
- **L15 (blind relpath arithmetic)** — FIXED: `github.lua` resolves both paths
  and asserts containment before slicing, notifying instead of building a
  truncated URL. In-repo URLs verified unchanged.
- **L16 (global terminal state)** — FIXED: `term_win_visible()` also requires the
  window to still show the terminal buffer *and* live in the current tabpage.
- **L17 (stream concatenation)** — FIXED: explicit `"\n"` between stdout and
  stderr before errorformat parsing.
- **L18 (leaked timers)** — FIXED: cleanup now also fires on `BufDelete` and
  `BufUnload`.
- **L19 (cursor never blinked)** — FIXED: `a:blinkwait700-blinkon500-blinkoff400`.
  Verified present in `guicursor`.
- **L20 (multiple kotlin_lsp roots)** — **NOT A BUG.** `buildSrc/` and
  `integration-test/` each ship their own `settings.gradle.kts`, so they *are*
  independent Gradle builds; one language server per build is correct. kotlin.nvim's
  default `root_markers` are already priority-grouped with `settings.gradle*`
  above `build.gradle*`. The RAM cost is inherent to three Gradle builds.
- **L21 (untracked `github.lua`)** — acknowledged and deliberately left as-is at
  the maintainer's direction.
- **L22 (`.gitignore`)** — **left alone.** `/.idea` co-existing with tracked
  `.idea/nvim.iml` is a deliberate "track the module file, ignore the churn"
  pattern; the five IntelliJ rules are inert. Changing them needs an intent call,
  not a bug fix.
- **L23 (picker mode comment)** — FIXED: the module header now states the picker
  opens in normal mode and that `i` starts filtering.

### Regression check

After all of the above: **23 Lua files, 0 syntax errors**; a clean start emits
**no messages at all**; the seven fixes from the first pass all still hold
(new-file LSP attaches, no `stylua` client, whole-branch base matches the
merge-base, one filename in the statusline, `<leader>go` resolves the WSL path,
0 errors on branch switch). Go, Python, Lua and TypeScript fixtures all report
`ERRORS: 0`.
