## 2026-08-11 — code-review backlog (deferred findings)

From a `/code-review max` sweep of the whole repo, focused on how the code
branches across OS environments. **Seven findings were fixed in `df21bb2`** (the
four introduced on this branch plus the three most severe pre-existing ones).
This document is what was deliberately deferred.

Each entry was reproduced by running Neovim, not inferred from reading — see
[[headless-nvim-verification-recipes]] in the reviews already here. Where a
finding is marked *unverified by me*, it comes from the review and I did not
independently re-run it.

---

## High — silent or total failure

### B1. `lua/plugins/git.lua:32` — merge-base cache key is `"HEAD"` when detached

`rev-parse --abbrev-ref HEAD` returns the literal string `HEAD` on a detached
checkout, not a sha. The per-HEAD cache key added to fix stale gutter bases
therefore collapses to a constant during bisect, interactive rebase, tag checkout
or a detached worktree: open file A at commit X, cache merge-base(X); move to
commit Y, open file B, the cache hits and the gutter marks the wrong lines for
the rest of the session. `git rev-parse HEAD` is the value the comment describes.

Compounding: the probe sits *before* the cache check, so every buffer open pays
two uncached blocking git spawns on the main loop (~1.7ms + ~2.0ms measured,
~2.4x on a `/mnt/c` checkout).

### B2. `lua/plugins/git.lua:237` — the diff guard disables the whole handler

`and not vim.wo[w].diff` was added to skip the diff window, but `:diffthis` sets
**both** `diff` and `scrollbind` on the source window too. So no editor window is
ever found, the loop leaves `editor` nil, and the blame scroll-sync re-alignment
becomes a no-op for as long as a diff is open — reinstating the row drift it
exists to correct, exactly when alignment matters most.

### B3. `lua/plugins/lsp.lua:121` — the `ts_ls` root_dir override drops upstream behaviour

Written only to add the `@flow` veto, it replaces lspconfig's entire root
resolution and loses three things:
- **Deno veto** — upstream aborts when `deno.json`/`deno.lock` is closer than the
  package lock; ts_ls now attaches to Deno sources and floods them.
- **Lock-file monorepo root** — upstream roots on the lockfile, so one tsserver
  is shared; the override roots on the nearest `package.json`, spawning one per
  package.
- **cwd fallback** — upstream ends `on_dir(root or vim.fn.getcwd())`; the
  override's `if root then` means a standalone `/tmp/scratch.ts` gets no ts_ls at
  all, so no completion and no LspAttach keymaps.

Separately the veto tests `filetype == "javascript"` only, but `.jsx` maps to
`javascriptreact` — which is in ts_ls's filetype list — so Flow-typed `.jsx`
still gets the measured 1747-diagnostic storm. The pragma scan also reads only
lines 0-20.

### B4. `lua/tajbanana/env.lua:98` — PATH is joined with a hardcoded POSIX `":"`

All three PATH mutations use `":"`, and the line-117 dedup
`(":"..PATH..":"):find(":"..bin..":")` can never match on Windows, so SDKMAN bins
are re-prepended every launch. On native Windows — where `$HOME` is synthesised
and rustup really does create `.cargo\bin` — line 98 produces
`...;C:\Windows\System32:C:\Users\<u>\.cargo\bin` on a `;`-separated PATH: cargo
is still not found *and* the last real PATH entry is destroyed for every LSP
server, formatter and `:!` command.

This also falsifies CLAUDE.md's claim that "every OS test in the config goes
through platform.lua". Note the HOME guard from `df21bb2` fixed the *crash* here,
not the separator.

---

## Medium

### B5. `lua/tajbanana/terminal.lua:16` — F2 splits a second window onto the same terminal

The current-tabpage clause guards the hide path but not the show path. Reproduced
by driving `toggle()` headless and counting terminal-buftype windows: F2 in tab 1
→ 1; `:tabnew`, F2 → 2; F2 → 1 (tab 2 hidden, `term_win` nil); `:tabprevious`,
F2 → **2** — `term_win_visible()` is false, so the else branch splits a second
window beside the still-open original. From then on F2 alternates 1↔2 forever and
the first window can never be hidden. The else branch needs the symmetric check.

### B6. `lua/tajbanana/inlay_tint.lua:44` — `table.insert(t, nil)` drops hints

`InlayHint.kind` is optional and routinely omitted by jdtls and kotlin-lsp.
`table.insert(list, nil)` is a silent no-op, so a kindless hint is dropped and
every later kind shifts down one slot — painting the wrong hint the wrong colour.
Second defect in the same function: the bucket key uses the raw LSP
`p.character` (UTF-16 code units) but is looked up with the extmark's `col`
(bytes), so on any line with non-ASCII before the hint the lookup misses and the
hint is never re-tinted.

### B7. `lua/tajbanana/definition_picker.lua:140` — `<leader>gd` can hang mute forever

The picker opens only when `remaining` hits exactly 0. There is no timeout and no
partial-results path, so a client that accepts a request and never answers —
jdtls mid-import, or the expired-EAP kotlin-lsp documented in the readme — leaves
`remaining` at 1: no picker, no error, no notification. It is the only mute
failure path in a module where every other one notifies.

Separately, `seen` is keyed `filename:lnum:col` with no `kind` component while
all four requests are in flight, so for a class symbol whichever of
`definition`/`typeDefinition` lands first stamps the tag. Typing `def` to filter —
the documented workflow and the whole point of a flat tagged picker — can show
nothing, and which kind wins varies per invocation.

### B8. `lua/tajbanana/git_pickers.lua:53` — `git diff <sha>^!` is blank for merge commits

Verified in scratch repos: `git diff <merge>^! | wc -l` returns **0**, so
selecting any merge commit in `<leader>gc` shows a completely blank preview. For a
root commit it degenerates to commit-vs-working-tree, leaking uncommitted edits.
The inline comment asserts the opposite. `git show` is the intended command.

Two more in the same previewer: `core.pager=delta` is passed with no
`executable("delta")` check — delta is not a Mason package — and since
`delta_previewer` fully replaces telescope's stock previewers there is nothing to
cycle to, so on a machine without delta every preview reads `fatal: unable to
execute pager 'delta'`. And `SIDE_BY_SIDE_MIN_COLS` is compared against
`vim.o.columns` while telescope sizes the pane at `floor(0.4 * 0.8 * columns)`,
so at 120 columns delta splits a ~38-column pane into two ~17-column slivers;
`--width=variable` (already used in this branch's `lazygit/config.yml` for this
exact reason) removes the heuristic.

---

## Low / cleanup

- **`lua/plugins/lsp.lua:22,42`** — `tailwindcss` and `rust_analyzer` are
  installed via `ensure_installed` and then permanently excluded from
  `automatic_enable`, so Tailwind LSP never attaches anywhere. `readme.md:162`
  and `design-decisions.md:128` still claim it does.
- **`lua/tajbanana/repo_diagnostics.lua:38`** — no JVM detector, so `<leader>xr`
  is a verified no-op on Maven/Java/Kotlin repos — this config's primary stack.
- **`lua/tajbanana/repo_diagnostics.lua:59,75`** — same POSIX-only path
  assumption that was fixed in `forge.lua`; `vim.fs.relpath` applies here too.
- **`.wezterm.lua:132`** — POSIX-only basename, while the sibling `pane_prog` was
  explicitly fixed for backslashes.
- **`.ideavimrc:23`** — hardcodes GitHub-only IntelliJ actions, contradicting
  `forge.lua`'s per-remote detection.
- **`lua/tajbanana/forge.lua:103`** — `cli_jq` is decorative; the glab branch
  decodes JSON in Lua instead.
- **`lua/tajbanana/incremental_selection.lua:106`** — the `stack_buf` guard is
  unreachable.
- **`docs/deviations-from-main.md:332`** — a duplicated line breaks a paragraph
  mid-sentence.
- **`docs/deviations-from-main.md` A1** — still names `github.lua`, which no
  longer exists. (Historical narrative in `design-decisions.md` naming it
  deliberately is fine; this one reads as current.)

---

## Measured, not a defect

`vim.fn.executable()` costs ~6.4ms per call on this WSL box because of the seven
`/mnt/c` entries in PATH — roughly 20ms of a 63ms startup across `env.lua:13`,
`env.lua:93` and `lsp.lua:31`. `vim.uv.fs_stat` is ~650x cheaper where a specific
path is being tested. Recorded because it is real and measured; deferred because
correctness outranks it, and because `df21bb2` deliberately *added* an
`executable()` call to fix a raw-traceback bug.
