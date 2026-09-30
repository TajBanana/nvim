## 2026-09-28 → 29 — feature review, fixes and verification rounds (`fix/review-findings`)

A record of one long review-and-fix effort: what was reviewed, **what the owner
decided and why**, what each verification round found, what is still open, and
the working rules that kept it safe. Per-feature rationale lives in
[`docs/design-decisions.md`](../design-decisions.md); this file is the
process log that ties the commits together and lets the work be resumed
without the original conversation.

---

## Commit history (regrouped 2026-09-29)

The ~36 fine-grained commits of this effort were squashed into **10 feature
commits** at the owner's request ("there are too many commits in this branch,
group them by feature groups"). The final tree is byte-identical; the original
commits remain on `fix/review-findings-backup-20260929`. Commit references below
point at the feature commit that now holds each change:

| Commit | Feature group |
|---|---|
| `5ed7421` | chore(tests): test runner, Run headers, `.gitignore` |
| `5b90a99` | feat(editor): options, filetypes, F2, `Space go`, ui2/fidget, plugin loading |
| `e3b58e2` | feat(treesitter): indent scopes and incremental selection |
| `692a14c` | feat(kotlin): previous build, rollback, safe update/prune |
| `ab90a72` | feat(lsp): allow-list, gated installs, tailwind root, inlay tint |
| `1f6b005` | feat(format): formatters, mason-tool-installer |
| `aee2d0a` | feat(git): whole-branch gutter, lazygit/delta config |
| `315f3c3` | feat(forge): `Space gl` permalinks |
| `c1e2d10` | feat(lint): `Space xr` repo lint |
| (last) | docs — this file included |

---

## Branches

```
main
 └─ fix/helm-scopes-and-selection   (5 commits: Helm scope highlighting, YAML/Helm selection)
     └─ fix/review-findings          (this effort; 10 feature commits on top)
```

- `fix/helm-scopes-and-selection` was rebased onto `main` first (branch =
  `main` + the Helm commits). `fix/scope-indent` was deleted as throwaway.
- **Merge order:** `fix/helm-scopes-and-selection` into `main`, then
  `fix/review-findings`. Nothing has been pushed.
- *Corrected (round 7):* `fix/helm-scopes-and-selection` WAS pushed
  (`origin/fix/helm-scopes-and-selection` at `4b57754`, reflog "update by push"
  2026-09-28 14:11), and `main` (`3b3596f`, fetched 14:12) already contains its
  five commits as equivalent patches — the trees are identical. So only
  `fix/review-findings` remains: rebase it onto `main` (the five chart-scope
  commits drop out), then merge. `fix/review-findings` itself is not pushed.
- *Done 2026-09-30:* after the squash into 10 feature commits, `fix/review-findings`
  was rebased onto `main` (`3b3596f`); it still is not pushed.

---

## Round 1 — feature review (20 items) and the owner's decisions

An agent reviewed every feature in the repo, told to assume nothing and verify
by running Neovim. The 20 items were then walked through one by one; each
decision below is the owner's, and the commit that carries it is listed.

| Area | Decision | Why / note | Commit |
|---|---|---|---|
| Paren-skip completion (`completion.lua`) | **Leave unwired, document why** | It was meant to smooth method chaining, but on a call with more than one parameter, accepting the first argument jumped out of the parentheses. Module + test kept for a possible single-parameter revival. | `5b90a99` |
| Whole-branch gutter after a branch switch | **Fix the refresh only** (keep the design) | Open buffers kept the old branch's fork point. | `aee2d0a` |
| LSP auto-enable | **Allow-list** = the configured `servers`; tailwind **enabled, but only in Tailwind projects** | Leftover Mason packages (emmet_ls, gradle_ls, sqlls, stylua's LSP wrapper) were attaching. | `ab90a72` |
| Plugins in brand-new files | **Add `BufNewFile`**; **drop Comment.nvim** | Built-in `gc`/`gcc` covers it. | `5b90a99 / aee2d0a` |
| Kotlin LSP | **Add a `cmd` lazy trigger**; **keep the previous build + add `:KotlinLspRollback`** | `:KotlinLspUpdate` did not exist before a `.kt` file was opened. | `692a14c` |
| Repo lint `Space xr` | **All four:** ESLint JSON, nearest-marker project root, golangci-lint + helm lint, hadolint + yamllint | ESLint 9 removed `-f unix`; monorepo sub-projects were never found. | `c1e2d10` |
| F2 terminal | **Recreate it if the shell died** | | `5b90a99` |
| Filetypes | **All three:** `yaml.helm-values`, `yaml.docker-compose`, `yaml.gitlab` | helm_ls never attached to values files. | `5b90a99 / e3b58e2` |
| luarocks health error | **`rocks.enabled = false`** | No plugin needs luarocks. | `5b90a99` |
| `Space td` | **Switch to `preview_hunk_inline`** | `toggle_deleted` is deprecated. | `315f3c3 / aee2d0a` |
| `Space go` | **Guard fake paths + open the nvim-tree node** | On WSL a bogus path opened a random Explorer window. | `5b90a99` |
| Inlay tint | **Match hints by label text**, not chunk order | Hints at one position swapped colours. | `ab90a72` |
| Search | **Add `smartcase`** | | `5b90a99` |
| Item 14 (a git workflow addition) | **Skip — use lazygit** | lazygit already covers it. | — |
| Formatters | **All four:** Python (ruff), Go (goimports + gofumpt), sh (shfmt), Markdown (prettier) + mason-tool-installer | Formatters used to exist only where hand-installed. | `1f6b005` |
| Forced repaint on scroll | **Debounce/throttle instead of removing** | | `5b90a99` |
| `Space gi` / `Space vws` | **Both to Telescope** | | `ab90a72` |
| "Press ENTER" under `cmdheight=0` | **Both:** Neovim 0.12 `ui2` + fidget owning `vim.notify` | | `5b90a99` |
| `Space gl` | **Replace it with a commit-SHA permalink** (not a new `gL`); **refuse with a warning** when HEAD is unpushed | A branch URL drifts after more commits land. | `315f3c3 / aee2d0a` |
| Housekeeping | **All three:** single lazygit config, test runner (`run_all.sh`), uniform `Run:` headers | | `5ed7421 / aee2d0a` |
| Docs | **Fix all drift** | | the final `docs` commit |
| lazygit config | **Repo file = the live macOS config, and the live file is a symlink to it** (first answer "point lazygit.nvim at it" was revised once the live Library copy turned out newer) | lazygit on macOS reads `~/Library/Application Support/lazygit`, not `~/.config`. Backup: `config.yml.bak-20260928-154952` there. | `5ed7421 / aee2d0a` |
| lazygit colours (follow-up, 2026-09-29) | **Restore the gutter-matching colours** from `main` (`#9CC2FF` / `#D5F58F` / `#FF8A91`, backgrounds `bg1`/`bg3`) | Rebuilding the repo file from the live one had silently swapped them for stock Material accents and onedark "deep" backgrounds, so lazygit no longer matched the gutter. Found when auditing which past decisions had been undone. | docs commit |
| starship | **Document the symlink** | | the final `docs` commit |
| colorcolumn | **80** (was 100) | | `5b90a99` |
| Base branch for the work | **Off `fix/helm-scopes-and-selection`** | | — |

## Round 2 — reviewer agent on the changes (F1–F13) — ✅ all fixed

Hoisted eslint/tsc in workspaces, golangci-lint v2 path mode, helm parse-error
locations, deleted Dockerfiles, mason-tool-installer toolchain gates, permalink
for untracked files / detached HEAD / clipboard, per-repo HEAD memoization,
lazygit `--dark` for delta, tailwind root markers, doc drift, test gaps.
Now inside the feature commits below.

## Round 3 — one independent verifier (32 defects) — ✅ all fixed

Owner: "sure fix them". Highlights: tailwind lookup order (Rails/Django/monorepo),
the gutter never noticing a rebase (gitsigns emits nothing for it → git-dir
watcher added), permalink symlink/case/encoding/clipboard, helm v4 output,
equal-priority lint markers, Kotlin rollback swap order, F2 closing another
tab, filetype rule priority. Now inside the feature commits below.

**Side effect to remember:** the first `forge_permalink.lua` wrote to the real
clipboard and overwrote the owner's clipboard contents once (unrecoverable). The
test now uses a fake clipboard provider; verifiers are told not to touch it.

## Owner request — indent scope inside `{ }` — ✅ fixed (`e3b58e2`)

Screenshot: cursor inside `vim.lsp.config("tailwindcss", { … })` in `lsp.lua`;
the guide marked the enclosing `config = function`. Cause: indent-blankline's
default Lua (and Python) scope nodes cover only statements and functions. Now a
multi-line Lua table/call and Python dict/list/set/tuple/call are scopes. jsonc
was left out on purpose: no jsonc parser is installed, so it would be untested.

## Round 4 — two independent verifiers (A and B) — ✅ fixed

Owner: "yes fix it". Found by both unless marked (A)/(B).

| Area | What was wrong | Commit |
|---|---|---|
| Kotlin | Other Neovims pinned to an old build (regression: `current` resolved once at load → now on every Kotlin FileType); prune in-use check lost matches to SIGPIPE + pipefail (B) and compared unresolved paths; servers launched via `current` unprotected (now: no pruning while one runs, none without a process list); update linked `current` before `previous` | `692a14c` |
| Gutter | Refresh froze the editor 2–3 s (only the first git call was async); symlinked files used the wrong repo (B); a nested repo created mid-session got the inner repo's sha (A); no watcher before the first commit (B); `BufWipeout` stacked per `:edit` (A). Now all async, repo = gitsigns' own root, new `whole_branch.lua` test | `aee2d0a` |
| Forge | Clipboard check passed on Linux/WSL (cached providers) → waits for the copy job; glob file names; ssh aliases and `ssh.github.com`; http(s) port/scheme; unencoded `[ ] { } ^ \|` (B); NFD names (B); `nvim.forge` not `--local` (B); failure at INFO | `315f3c3` |
| Repo lint | Unbounded search outside git; missing directory linted cwd (B); helm spaces / sub-chart names / `.tgz` / columns / `:` paths / `values.yaml` re-reports (B); golangci logfmt junk (B); `Dockerfile.md` etc. (B); ruff + `FORCE_COLOR` (B); gitignored Dockerfile (A); ":Mason" helm hint (A); de-dup now tested (A) | `c1e2d10` |
| LSP / tools | tailwind root walk unbounded (B); `:MasonToolsClean` would uninstall every LSP server (B); npm/go/pypi/cargo-built servers not gated (B) | `ab90a72 / 1f6b005` |
| Misc | F2 `E444` as only window (A), per-tab window (B), dead-buffer pile-up (B); nested `templates/templates/` (B); `indent_scope` any `yaml.*` (B); lazygit `selectedRangeBgColor` unknown to 0.65.1 (B); `run_all.sh` error line (A) | `5b90a99 / e3b58e2 / aee2d0a / 5ed7421` |
| Docs | stylua count 27/31, `gitutil` users, `KOTLIN_LSP_DIR`, forge override/lookup wording, clipboard wording, dead terminal, gopls gate, install gating, prune wording | the final `docs` commit |

**Deliberately not done:** the wrong-case permalink check (A) was *removed*
rather than fixed. Every route Neovim offers on macOS (`:edit`, relative edits,
`nvim_buf_set_name`) canonicalises a buffer's path case, so a miscased buffer
cannot be constructed and the check could never fail; the `fs_realpath`
normalisation stays, and the docs no longer claim it is tested.

### ⚠️ Open: the live Kotlin install was broken during round 4

At **2026-09-29 10:13:13** `~/.local/share/kotlin-lsp/current` was repointed to
`kotlin-server-263.1.0` — the updater tests' **fixture** build number, which does
not exist. The real build `kotlin-server-263.4702.0` is intact. Which process did
it was not established (verifier sub-agents were running; other Claude sessions
were open in the repo). Claude's attempt to repair it was blocked by the
auto-mode safety check, so the owner must run (**still broken when re-checked
2026-09-29 after the commit regroup** — `current` still points at
`kotlin-server-263.1.0`):

```
ln -sfn ~/.local/share/kotlin-lsp/kotlin-server-263.4702.0 ~/.local/share/kotlin-lsp/current
```

### Deferred / not reproduced (from rounds 3–4)

cargo workspace-member paths (no Rust toolchain here to test; *fixed later, c1e2d10*); `run_all.sh` has
no per-test timeout and does not fail on an error raised inside
`vim.schedule`; `?plain=1` for line anchors on Markdown files; fidget loads at
`VeryLazy`, after `UIEnter`; the yamllint venv probe repeats on machines that
cannot install it; golangci-lint v1 and helm v3 output not run for real.

Status update (end of round 4): the Linux git-dir watcher that died when a repo
was deleted and re-created is now handled — watchers are tracked per path,
dropped on error and re-added on the next pass (`aee2d0a`). The rest remain
deferred.

### Open items from the older reviews (001–005), re-checked 2026-09-29 — ✅ fixed the same day

74 findings re-checked against the code: 57 fixed, 11 open, 5 present but
accepted as not-a-bug, 1 obsolete. Each older report now carries a dated status
note. The open ones worth fixing:

- **audit_004 L12 — marked fixed there, but not:** a treesitter parser installed
  mid-session never highlights the already-open buffer (`TSUpdate` fires at the
  start of an install, and the listener is registered after `TSInstall`).
- **backlog_005 B7:** `<leader>gd` has no timeout (a silent server shows nothing)
  and loses a tag when definition and type-definition return the same location.
- **backlog_005 B8:** the `<leader>gc`/`gh` commit preview is empty for merge
  commits and wrong for root commits; no delta check; side-by-side keyed on
  `vim.o.columns` instead of the preview width.
- **backlog_005 (low):** POSIX-only path handling in `repo_diagnostics.lua` (only
  matters on native Windows).

Smaller: a stale `<leader>gd` comment in `lsp.lua` (audit_004 L23), the
misleading `stylua.toml` comment (baseline_003 M6), WezTerm's POSIX-only tab
title, GitHub-only `.ideavimrc` actions, `cli_jq` in `forge.lua`, a dead guard
in incremental selection. Stale code comments found during the docs pass: the
`Space dv` keymap text says "vs index" (it diffs against the current base), the
Kotlin rename handler comment in `lsp.lua` says "strips" the version (it
overwrites it), and `colorscheme.lua` says "~30% desaturated" (about 60%).
**Owner: "fix open bugs" — fixed:** L12 `e3b58e2` (new
`treesitter_install.lua` test); B7 and the L23 comment `ab90a72`
(`definition_picker.lua` test); B8 and the `Space dv` description `aee2d0a`
(`git_pickers.lua` test); the lows and stale comments `5b90a99, 315f3c3, c1e2d10`. Left as they
are: GitHub-only `.ideavimrc` actions, no Java/Kotlin linter (by design), the
harmless incremental-selection guard. The Windows path handling is reasoned from
the `vim.fs` docs, not run on Windows.

### Owner decision: untracked-file gutter marks (decided: leave)

Raised 2026-09-29. With `attach_to_untracked = true` gitsigns marks every line of
a never-`git add`ed file with a dim green dotted `┆`, which reads like "added
lines" although it is a file-level status (a new line in a tracked file is a
solid green `┃`). Options offered: (1) `attach_to_untracked = false` — green only
ever means "added line", untracked files show no marks until added (IntelliJ-like);
(2) keep the marks but recolour them grey; (3) leave as is. **Decision (2026-09-29): leave
them as they are.**

---

## Round 5 — independent verifier after the doc pass and bug fixes — ✅ fixed

Owner: "fix them and verify again. most importantly, kotlin lsp is broken", then
"the link worked previously why did you suggest to change it?".

- **Kotlin (regression from round 4):** the resolved-path launch made
  `:KotlinLspUpdate`/`:KotlinLspRollback` relaunch the old build (Neovim's FileType
  handler restarts from the previous launch's command). Owner chose **"Revert to
  original"**: `KOTLIN_LSP_DIR` is the `current` symlink path again; nothing is
  pruned while a server runs through `current`; a failed activation leaves no stray
  `previous`; an exported `KOTLIN_LSP_DIR` is respected — `692a14c`, tested by
  `kotlin_launch.lua` with the real kotlin.nvim.
- **Forge (regression from round 4):** resolving every ssh `HostName` broke real
  hosts; only aliases are resolved now. Also single-branch-clone pushes, byte-exact
  names — `315f3c3`.
- F2 E444 with floats; lint sub-chart errors, nested skips, tsc without tsconfig;
  LSP gate on a fresh machine, `Space gd` cancellation; gutter watcher cleanup;
  values pattern, tailwind home, parser-install summary — one commit each.
  *(Corrected, round 7: the last three are one commit, `5b90a99, e3b58e2, ab90a72`. Its message says
  installs print "Installed N/M"; nvim-treesitter prints that summary only when two
  or more parsers are installed at once.)*
- **Correction to round 4 below:** the claim that `nvim_buf_set_name` canonicalises
  a miscased path is wrong for the *file name* component (the verifier showed it
  keeps `F.TXT`); the removed test was dropped on a wrong premise. The permalink is
  still correct (`fs_realpath`), but that case has no test.
- **Kotlin install state (2026-09-29):** `~/.local/share/kotlin-lsp/current` still
  points at the missing fixture build `263.1.0`. At 11:58 a Mason copy of
  kotlin-lsp 263.4702.0 was installed (most likely by the owner via
  `:MasonInstall kotlin-lsp`, which kotlin.nvim's error message suggests).
  kotlin.nvim prefers `$MASON` over `KOTLIN_LSP_DIR`, so Kotlin now runs from that
  Mason copy, and `:KotlinLspUpdate` would update the self-managed install it
  ignores. Owner to decide: keep Mason, or repair `current` and
  `:MasonUninstall kotlin-lsp`.

## Round 6 — independent verifier after round 5 — ✅ fixed

Owner: "Fix all, verify again". 8 code defects, 11 doc mismatches:
- **Kotlin:** the round-5 revert dropped main's "point kotlin.nvim at `current`
  after an update" step, so a first install did not attach until a restart —
  `point_at_current()`, tested through the real `restart_clients()`; an old
  build's expiry flagged a new build (the log names `current`) — filtered by the
  link's mtime.
- **Forge:** the ls-remote fallback crashed on a hanging ssh and orphaned it —
  BatchMode, process group killed at 5 s; ancestry accepted; a late-failing
  clipboard tool is caught.
- **Lint:** cargo workspace members (paths relative to the workspace root);
  inherited `tsconfig.json`.
- **Treesitter:** fresh-machine runtime-path cache after a mid-session install.
- **Gutter:** a stale pass for an older HEAD no longer wins; watchers no longer
  leak on `:saveas` or a wipe during a pass.
- Docs: stale Kotlin helper/test names, CHANGELOG contradiction, alias wording,
  values pattern, indent_scope `yaml.*`, the stylua cause (9 of 27), the
  `--width=variable` reason, "whole repo" wording.

## Round 7 — independent verifier after round 6 — ✅ fixed

Owner: "Fix all, verify again". 12 code defects (three from round-6 fixes), a weak
test, 13 doc mismatches:
- **Round-6 regressions:** the ls-remote fallback ran one `merge-base` per remote
  ref (about a minute with 2000 refs) — one `rev-list` over the distinct tips; it
  overrode a `GIT_SSH` wrapper — BatchMode is only added for OpenSSH; the
  inherited-tsconfig fix ran the PARENT project and could say "no issues" for a
  package it never checked — `-p` + `--listFiles`, entries filtered to the
  package, an uncovered package is reported.
- **Also found while testing:** the 5 s kill could leave the real ssh running
  (git forks it after its `ssh -G` probe dies, racing the group kill; about 1 run
  in 4) — the group is killed until empty. The test's fake ssh `exec`ed `sleep`, so
  the orphan check could never see it.
- **Gutter:** a FocusGained refresh racing `Space gB` left the index base and a
  false "no main/master" — a late state read continues with the newest state, and
  `applied_head` is cleared when the base is dropped. *(Corrected, round 8: it was
  cleared on re-attach and `Space gB` off only; for the no-main / not-at-fork drops
  it is (correctly) set to that HEAD. Round 8 also moved the recording to when a
  pass finishes.)*
- **Other code:** commit previews without delta (`--no-pager`); npm gate in the
  statusline; lint severities, continuation lines, chart schema detail, hadolint
  newlines, one run at a time; Kotlin `previous` outside the install dir, empty
  build name, relative `KOTLIN_LSP_HOME`, no prune after a dangling `current`
  (the state this machine is in); `work.github.com` aliases.
- **Test:** `kotlin_launch.lua`'s first-install check passed with the fix disabled
  (an earlier launch had configured kotlin_lsp); it now runs first, in a fresh
  session, and fails without the fix.
- **Docs:** the reintroduced "resolves to" Kotlin wording, `--heads`/"bounded",
  tsc "only that package", `Space e`/`Space xr`, `Space gB` outside git,
  `origin/*`, alias rule, watcher close on `:bdelete`, the 2026-08-04
  `--width=variable` entry, "nothing pushed", "one commit each", tailwind `$HOME`.
- Left as reported: Markdown line anchors possibly needing `?plain=1`, the 64 KB
  expiry-log tail, a broken same-version build folder not re-downloaded, `main`
  preferred over `master` when both exist (documented order), F2 on a terminal the
  user floated, `package.json5`/plain-text tailwind matching, a trailing `\` in
  WezTerm paths.

## Round 8 — independent verifier after round 7 — ✅ fixed

Owner: "Fix all, verify again"; also deleted the empty `p1`/`p2` folders
`kotlin_launch.lua` had left in `~/.cache/kotlin-lsp-workspaces` (the test now
sandboxes HOME). About 17 code defects (four from round-7 fixes), test gaps and
~12 doc mismatches:
- **Round-7 regressions:** the npm statusline gate took lspconfig's function `cmd`s
  as "can start" (5 of 9 servers) — checked by binary name; the tsc coverage check
  made a clean package beside a failing one a "tool crash" and hid a tsc that never
  ran — coverage of the edited file, for every tsconfig, with failures kept apart;
  `work.github.com` handling broke `ssh.github.com` with an IP `HostName` — mapped
  first.
- **Git:** `Space dv` opened gitsigns' writable index buffer on the fork point (`:w`
  staged it); `applied_head` set before the last git call left a false claim after
  A→B→A with slow git (the verifier's deterministic repro is now a test); watchers
  after `:saveas` out of a repo; the pickers took nvim's cwd; `pager.show=less`
  hung the preview.
- **Kotlin:** popups answered by keys typed after Insert-mode `<C-o>`; after an Open
  VSX fallback, updates re-downloaded the expired GitHub build and re-asked; pruning
  deleted a build run through a symlinked path; `KOTLIN_LSP_HOME` resolved at the
  lazy plugin load.
- **Lint / forge / LSP / editor:** as listed in the CHANGELOG's round-8 entries.
- **Tests:** new `set_lua.lua`, `flow_pragma.lua`; mutation-checked guards for the
  selection resets, `--ignore-missing`, `core.sshCommand`'s BatchMode, the values
  rule, Esc's keep list and the repaint throttle. `run_all.sh` shows the real
  error line.
- **Incident while fixing:** a cleanup command `pkill -f "less" -U <me>` was run to
  stop a possible stray `less`; `-f` matches whole command lines, so any process of
  the owner's with "less" in its arguments was a target. The owner's interactive
  Neovim and its Kotlin server were still running afterwards; nothing else is
  known to have been hit. Broad `pkill -f` patterns are not used any more.
- Left as reported: the `-p` flag (tsc finds the same nearest tsconfig without it,
  so it guards nothing), the kill-until-empty check (a race; 8/8 clean runs either
  way here), suspected items (release JSON with `body: null`, uppercase-hex
  `.sha256`, download timeouts, cargo `exclude`, `[ workspace ]` spacing,
  `Dockerfile.sh`, the timer repaint during `input()`, ui2 re-showing messages), and
  the Mason kotlin-lsp copy being the live one (owner's decision).

## Round 9 — independent verifier after round 8 — 7 fixed, the rest backlog

The owner asked why each round found MORE bugs (8 → 12 → ~17 code defects in
rounds 6–8). Answer given: each batch of fixes added code whose own edge cases the
next round found (3–4 defects per round were regressions from the previous
round's fixes); some tests exercised a simplified version of reality (a table
`cmd` where lspconfig uses functions; a fake ssh that `exec`ed, so an orphan check
could not see it); each fresh verifier digs deeper and also found OLDER bugs; and
"fix all" kept widening the reviewed surface. The owner then chose, after a
plain-language walk-through of what each item affects: "fix all 7 and verify
again".

Fixed (each with a test that fails on the previous code):
1. `Space xr` said "found no issues" for a linter killed by a signal (vim.system
   reports it as code 0 + signal) — now an error saying the result is incomplete.
2. IP-address, one-word and punycode ssh remotes were refused (round-8
   regression): an alias with no `HostName` is the host ssh connects to, so only a
   dotted non-domain name is refused.
3. `Space gm` built a create page for `main` for a branch created from
   `origin/main` (round-8 regression): the branch's own name wins when the remote
   has it.
4. Kotlin popups threw E11 in the `q:` window and the update then held its lock.
5. `gc` in Helm templates still used `#` on YAML lines (round 8 had set only the
   buffer option; the injected YAML's commentstring wins) — a treesitter capture
   with `bo.commentstring` on the template root. The round-8 test had passed only
   because its setup lacked `filetype plugin on`.
6. The Flow check matched comments after code and missed star-less block headers.
7. A sub-chart's schema failure vanished when the parent failed too — one entry per
   failing chart.

Also: the set.lua test had written undo files for its temp paths into the real
undodir (five removed; it now uses a temp undodir); stylua count re-measured (28
of 32, 10 from `collapse_simple_statement`).

Backlog (reported, not fixed; low severity or suspected): Flow buffers show a
permanent red ✗; with no npm, a non-Mason server binary on PATH counts as
expected; a parser failing with exit 0 or a timeout with partial output can read
as clean (the timeout is now named when killed); `Space gh` refuses a file opened
through a symlink, and its preview is blank before a rename; forge: non-URL
remotes with `nvim.forge`, `-F` parsed as a substring, `host:/abs` paths; the
expiry popup previews `stdpath("config")`'s script; relative-path manual Kotlin
launches are pruned; F2 hiding onto nvim-tree; ~20 test guards the verifier could
remove without a failure (listed in its round-9 report); Windows lint root,
ESLint coverage, synchronous `ssh -G`/`ls-files`, credential prompts during
ls-remote, `values.schema.yaml` detection.

## Round 9 verification (2026-09-30) — all logged, nothing fixed

A verifier scoped to the round-9 commits (`eb65a2f..b27d3e7` in the pre-squash history) confirmed all seven
fixes: reverting each code change makes its new test fail. It found the
following. The owner chose to log everything: "it does not matter as i will
install gh/gitlab and i don't use flow".

- **Space gm, unpushed branch based on a non-default branch** (e.g.
  `git switch -c feat origin/develop` while develop has an open PR): the token-free
  fallback opens develop's PR instead of the create page for `feat`. Round 9's fix
  excludes only main/master/the remote HEAD. It only matters without gh/glab,
  which the owner will install.
- **Flow veto after a shebang:** `#!/usr/bin/env node` then `// @flow` is no longer
  detected (round 9 treats the `#!` line as code). Whether Flow itself accepts
  that is unchecked. The owner does not use Flow.
- **Test gaps:**
  - run from a copy of the repo, set_lua.lua's Helm check reads the INSTALLED
    config's `after/queries/helm` (`-u NONE` still puts `~/.config/nvim/after`
    on runtimepath); it is fine run from the repo itself;
  - the `origin/HEAD` default-branch exclusion in `Space gm` is never exercised;
  - the lint timeout message (code 124) is untested;
  - the `q:` test stubs `getcmdwintype` (the real window was checked by hand).
- **Docs:**
  - CLAUDE.md's flow_pragma entry still says "a whole word in a comment" (now
    leading comments only);
  - forge.lua's repo_context comment still uses `work-gitlab` as the refused
    example (a no-dot alias is now kept);
  - "only a dotted non-domain name is refused" misses `work.github.com`, which
    is a real domain and still refused;
  - the readme's HostName rule omits that a HostName of `ssh.github.com` /
    `altssh.gitlab.com` also maps.
- **Suspected:** a linter that catches SIGTERM on timeout and exits normally is not
  reported as timed out; `per_chart` only collects unindented detail lines (real
  helm 4.3 output is unindented).

Also this session, at the owner's request: `.gitignore` additions (now in 5ed7421; the
verifier attributed it to the owner because of the git author, but Claude made it
after the owner's "yes"), and the `Space rf` rename prompt as a popup (now in 5b90a99).

## Commit history squashed (2026-09-30)

At the owner's request ("commit grouped by features, there are too many commits,
squash them") the branch's 59 commits were regrouped into 10 feature commits with
an identical final tree, and the branch was then rebased onto `main` (which already
held the five `fix/helm-scopes-and-selection` commits). The owner then asked "why
not just update the hashes": the commit hashes quoted in this log, the CHANGELOG
and the older reviews were rewritten to the new commits. A hash now names the
feature commit that contains the change; the old, finer-grained commits are kept on
`fix/review-findings-backup-20260930` (pre-squash), `fix/review-findings-prerebase-20260930`
(squashed, before the rebase) and `fix/review-findings-backup-20260929` (the first
regroup). Hashes that belong to other history (`26ff2ee`, `cc0b281`, `df21bb2`, and
`4b57754`, the pushed helm-branch tip) were left as they are; the round-9 range
`eb65a2f..b27d3e7` above is from the pre-squash history.

The 10 commits:

| Commit | Feature |
|---|---|
| `5ed7421` | chore: test runner, `.gitignore`, stylua notes |
| `5b90a99` | feat(editor) |
| `e3b58e2` | feat(treesitter) |
| `692a14c` | feat(kotlin) |
| `ab90a72` | feat(lsp) |
| `1f6b005` | feat(format) |
| `aee2d0a` | feat(git) |
| `315f3c3` | feat(forge) |
| `c1e2d10` | feat(lint) |
| (last) | docs |

Old hash -> new (mixed commits were split by file and list each commit they went to):

| Old | New |
|---|---|
| `07eb885` | `ab90a72` |
| `11b586d` | `aee2d0a` |
| `16f216c` | `5b90a99` |
| `2d31d8e` | `692a14c` |
| `2ee4596` | `692a14c` |
| `35a221b` | `ab90a72` |
| `3f6ee9d` | `315f3c3` |
| `509e6ac` | `5ed7421` |
| `54328bc` | `c1e2d10` |
| `7b3fc44` | `aee2d0a` |
| `aae30af` | `5b90a99`, `315f3c3`, `c1e2d10` |
| `b2f3d81` | `5b90a99` |
| `b30e6ba` | `e3b58e2` |
| `b57e1aa` | `5b90a99` |
| `c6507f1` | `c1e2d10` |
| `cf0e816` | `e3b58e2` |
| `d155bb4` | `5b90a99`, `e3b58e2`, `ab90a72` |
| `df8c50b` | `1f6b005` |
| `e2fc4ff` | `5ed7421` |
| `fef5941` | `315f3c3` |

## Past decisions reversed by this effort (audit 2026-09-29)

Asked "did we undo any past decisions, or are there conflicts?", `main` was
compared with this branch. Every reversal below was the owner's choice unless
marked; the two unintended ones were fixed.

| Earlier decision (on `main`) | Now | Why / who decided |
|---|---|---|
| tailwindcss **excluded** from auto-enable (`9fac953`: it spawned for every README in every git repo) | Enabled only inside Tailwind projects (`tailwind_root.lua`) | Round 1 "Enable on tailwind projects"; the root gate removes the original reason |
| mason-lspconfig **exclude list** | **Allow-list** = `servers` | Round 1 "Allow-list" |
| Kotlin: one build, older pruned; `KOTLIN_LSP_DIR` = the `current` symlink path | `previous` kept + `:KotlinLspRollback`; still the `current` symlink path (a per-launch resolved path was tried in round 4 and reverted in round 5) | Round 1; the revert per the owner, round 5 |
| `Space gl` = branch URL | Commit-SHA permalink | Round 1 |
| `Space xr` markers at the git root | Nearest project | Round 1 |
| Comment.nvim | Built-in `gc` | Round 1 |
| colorcolumn 100 | 80 | Owner request |
| Formatters installed by hand via `:Mason` | mason-tool-installer, toolchain-gated | Round 1 |
| `gitutil.lua` = single source of repo roots, incl. the gutter | Gutter uses gitsigns' own root | Round-4 fix: gitutil gave the wrong repo for symlinks / nested repos |
| Indent scope: "other filetypes keep the plugin's default lookup" | Lua and Python use the custom lookup | Owner request |
| **Unintended:** lazygit colours matched the Neovim gutter | Stock Material accents (from the live file) | Rebuilding the repo file from the live one swapped them; **restored** 2026-09-29 |
| **Unintended:** historical docs are annotated, never rewritten (`8b48993`) | Round 2 rewrote a line in `deviations-from-main.md` (0.11+ → 0.12+), and the 2026-09-29 docs pass added inline notes | **Restored** the original text; corrections now live only in dated header notes |

From the old lazygit file, delta's `--width=variable` (dropped in round 2 when
the pager moved to `diffRenderers`) was **restored** 2026-09-29 at the owner's
request (round 6 measured that it does not change the side-by-side split, only
background padding -- the stated reason, inherited from main, was wrong; it is
harmless); `mainBranches: [main, master]` stays dropped (lazygit's default already
covers both). The owner chose to **leave** the untracked-file gutter marks as
they are.

## Working rules learned (read before continuing)

- **Tests:** `bash scripts/tests/run_all.sh` (each `*.lua`/`*.py` file's line-1
  `Run:` header). Show every new check fails on the old code (copy the old
  module into a temp dir prepended to `rtp`, or `git stash` just that file).
- **Never** let a test or probe touch real state: `~/.local/share/kotlin-lsp`
  (set `KOTLIN_LSP_HOME`), `~/Library/Application Support/lazygit`, Mason's
  install dir, or the system clipboard (use a fake `g:clipboard`).
- **Headless gotchas:** `VeryLazy` never fires with `--headless` (fire it with
  `nvim_exec_autocmds("User", { pattern = "VeryLazy" })`); ibl scope lookups need
  an explicit `get_parser():parse(true)`; full-config headless probes sometimes
  hang — prefer the `-u NONE` harnesses in `scripts/tests/`. macOS has no
  `timeout`; `cat`/`ls` are aliased (use `command cat`).
- **Real-TUI check:** a headless nvim can run `jobstart({"nvim", ...}, { term = true })`
  and read the terminal buffer; set `vim.o.columns = 160` for the statusline.
- **Commits:** per-area Conventional Commits via the `git-commit` skill, body
  wrapped at 90, owner prompts listed, `Co-Authored-By` trailer.
- **Secrets:** `~/.zshrc` holds plaintext tokens — refer to variables by name only.
