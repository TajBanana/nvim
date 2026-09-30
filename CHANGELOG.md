# Changelog

Notable changes to this Neovim configuration, newest first. Dates are taken
from git history; entries before 2026 are reconstructed from commit messages.

## Unreleased — Review findings

### Added

- `:KotlinLspRollback`: the updater keeps the build it replaced as `previous` (older builds pruned) and rollback swaps back after checking the previous build still starts; it refuses when that build has expired, is already current, or is gone, and a failed swap is undone. Old builds are not pruned while a server launched through a `current` path is running, without a process list, or after `current` was left dangling; a build a server was started from directly (by an absolute path, even a symlinked one) is kept. (Servers launch through the `current` symlink; a brief resolved-path launch on this branch was reverted.)
- `Space rf` (and every other `vim.ui.input` prompt) asks in a floating box at the cursor, pre-filled with the current name, instead of the command line — snacks.nvim's `input` module.
- `Space xr` detectors: `golangci-lint` (preferred over `go vet`; v2 run with `--path-mode=abs`), `helm lint` for charts (helm v3 and v4 template errors jump to the real `file:line` inside the message, v4's continuation lines are kept, a rendered-output `line N` is labelled as such, directory entries land on `Chart.yaml`), `hadolint` for Dockerfiles (tracked-but-deleted files, `Dockerfile.dockerignore` and duplicate conflict entries skipped; non-ASCII paths kept), `yamllint` when a `.yamllint` config exists.
- Formatters: Python (`ruff_organize_imports` + `ruff_format`), Go (`goimports` + `gofumpt`), sh/bash (`shfmt`), Markdown (`prettier`). mason-tool-installer now installs all formatters and `Space xr` linters automatically on every machine that can install them; the toolchain-built ones are skipped where they cannot install (`goimports`/`gofumpt` without `go`, `prettier` without `npm`, `yamllint` without a python3 that can create venvs — checked without spawning python3 once yamllint is installed). gopls is likewise skipped without `go`.
- `yaml.helm-values` (chart values files, so helm_ls attaches), `yaml.docker-compose` and `yaml.gitlab` filetypes.
- `smartcase` searching.
- `scripts/tests/run_all.sh` runs every regression check (each file's `Run:` header) with a pass/fail summary; new checks for repo lint (reporting which tool-gated checks it skipped), inlay tint, tailwind root detection and the `Space gl` permalink guards (with a fake clipboard, so the suite never overwrites yours); compound-YAML filetypes in the incremental-selection and indent-scope checks, each shown to fail against the pre-fix code; Kotlin flow checks now assert WARN vs ERROR.

### Changed

- `Space gl` opens and copies a **commit-SHA permalink** instead of a branch URL, refusing when HEAD is unpushed or the file is not in HEAD, warning on uncommitted edits, and working on a detached HEAD and through a symlink into the repo. It only claims "copied" after reading the clipboard back, once a Linux/WSL clipboard tool's copy has settled.
- The `colorcolumn` ruler moved from column 100 to 80 (now part of the editor commit, 5b90a99).
- `Space gi` and `Space vws` open Telescope pickers (implementations; live project-wide symbol search).
- `automatic_enable` is an allow-list equal to the configured servers: leftover Mason packages (emmet_ls, gradle_ls, sqlls, the stylua formatter's LSP wrapper) no longer attach. tailwindcss now actually runs, but only in Tailwind projects (upstream's root markers minus the bare `.git` fallback, checked in one upward walk: postcss configs and Phoenix/Rails lockfiles count only when they mention tailwind; Django's `theme/static_src/`, monorepo roots and `deno.json` are found).
- `Space xr` lints the nearest project containing the current file (monorepo sub-projects), bounded by the git root, with all of a tool's markers equal (a nearer `tsconfig.json` beats a root `package.json`); eslint/tsc hoisted to a workspace root are found.
- `vim.notify` messages show as fidget toasts and other messages go through Neovim 0.12's `ui2`, so `cmdheight=0` no longer raises "Press ENTER" prompts.
- Commenting uses Neovim's built-in `gc`/`gcc`; Comment.nvim removed.
- `Space td` previews the hunk under the cursor inline (`preview_hunk_inline`; `toggle_deleted` is deprecated).
- lazygit: the repo's `lazygit/config.yml` was rebuilt from the live macOS config and is always used by `Space lg` (`-ucf`); on macOS the live file is now a symlink to it. Its theme keeps the colours the repo file had on `main`, which match Neovim's git gutter (the live file's stock Material accents were reverted). Its delta command passes `--dark` (delta cannot detect the background inside lazygit) and the side-by-side layout explicitly, so it no longer depends on the gitconfig include.
- The forced repaint on scroll/line-count changes is throttled to one per 30 ms.
- Minimum Neovim is documented as 0.12 (it already was in practice).
- Documented why `lua/tajbanana/completion.lua` (skip one `)` after accepting a value) is not wired into nvim-cmp: added in 3741eea/c6962e8 to smooth method chaining, unwired in 051f59d because on multi-parameter calls accepting the first argument jumps out of the parentheses. The module and its test are kept on purpose.

### Fixed

- Round 9: `Space xr` reports a linter killed by a signal (a crash, the OOM killer, the timeout) as a failure, not "found no issues", and lists every failing chart of a Helm schema error (a sub-chart's used to vanish when the parent failed too).
- Round 9: `Space gl`/`gm` link IP-address, one-word intranet and punycode-TLD ssh remotes again (round 8 refused them); `Space gm` uses the branch's own name when the remote has it (a branch created from `origin/main` got a "create PR from main" page).
- Round 9: the Kotlin update popups wait out the `q:` command window (opening there failed and left the update holding its lock).
- Round 9: `gc`/`gcc` in Helm templates now use `{{/* */}}` on YAML lines and ranges too (round 8 only fixed lines starting with `{{`); the Flow check reads only the file's leading comments, including star-less `/* */` blocks.
- Round 8: the npm statusline gate now works for all nine servers (it missed ts_ls, jsonls, yamlls, cssls and html); the ts_ls Flow veto needs a real `@flow` pragma (an `@flowio/…` import no longer turns ts_ls off) (a pragma after code, or in a star-less block, only from round 9); tailwind's `$HOME` bound holds for new files under a symlinked home.
- Round 8, `Space xr`: a clean package beside a failing one reports "no issues" (not a tool error); a tsc that never ran reports its real failure; any tsconfig that does not compile the edited file (inherited, solution-style, a narrow `include`) is reported instead of "no issues"; a broken `extends` is an entry; an unsaved or deleted open Dockerfile no longer aborts hadolint; a sub-chart's schema failure lands on the sub-chart's `values.yaml` (when the parent failed too, only from round 9).
- Round 8, git: `Space dv` in the whole-branch view is read-only (`:w` in it staged the fork-point text, reverting the branch in the index); an A→B→A branch switch with slow git settles on A's fork point; `:saveas` out of a repo releases its watchers; `Space gc`/`gh` use the file's repo and delta outranks a user's `pager.show`/`GIT_PAGER`.
- Round 8, Kotlin: the confirmation popups wait for plain Normal mode (Insert-mode `<C-o>` and operator-pending let typed keys answer them); after an Open VSX fallback an update no longer re-downloads the expired GitHub build or asks again for the build already current; a relative `KOTLIN_LSP_HOME` is resolved at startup.
- Round 8, `Space gl`/`gm`: `ssh.github.com` with an IP `HostName` works again; dotted aliases whose `HostName` is github.com/gitlab.com resolve; `-F` in `core.sshCommand` is honoured; an alias with no `HostName` is refused (not linked as the alias); an unreachable remote says so (not "push first"); `Space gm` also tries the upstream branch name (round 9: only as a second choice after the branch's own name).
- Round 8, editor: `gc`/`gcc` work on Helm and gotmpl files.
- `Space gl`: an unpushed HEAD no longer freezes Neovim on a remote with many refs (one ancestry check for all of them, not one per ref); a `GIT_SSH` wrapper is respected; `work.github.com`-style ssh aliases resolve; `Space gm`'s fallback is time-limited too.
- `Space xr`: tsc checks the package it reports on (an inherited parent project that skips the package is reported, not "no issues" -- round 8 generalised this to the edited file, for every tsconfig); every entry has a severity; tsc's chained reasons and the chart schema details are kept; hadolint messages are one line; a second `Space xr` while one runs is refused.
- `Space gB` turned back on while a refresh overlaps it applies the fork-point base (it could stay on the index and warn "no main/master").
- `Space gc` / `Space gh` previews work without delta even when the global git pager is delta.
- The statusline no longer shows a red ✗ for npm-built servers on a machine without npm (for five of the nine only since round 8; see above).
- Kotlin: rollback accepts a `previous` build outside the install dir; an update after `current` was left dangling prunes nothing (it could delete the only working build); a relative `KOTLIN_LSP_HOME` works after `:cd` (resolved at startup since round 8; before, at the lazy plugin load).
- A treesitter parser installed mid-session now highlights buffers already open (the old listener fired when an install started, not when it finished).
- `Space gd` opens after 3 s with whatever arrived (naming servers that did not answer) instead of waiting forever, and a location returned as both definition and type keeps both tags.
- `Space gc` / `Space gh` previews show merge commits (against their first parent) and root commits correctly, work without delta, and choose side-by-side from the preview pane's width.
- Kotlin: a first install through `:KotlinLspUpdate` attaches without restarting Neovim; an old build's expiry no longer shows ⏱ for a freshly updated build.
- `Space gl`: the remote check runs non-interactively with a 5 s limit on the network call (a hanging ssh prompt no longer errors or leaves a process), a remote tip that descends from HEAD counts as pushed, and a clipboard tool that fails after the copy is reported.
- `Space xr`: cargo workspace members resolve paths against the workspace root; tsc runs in a package that inherits a parent's tsconfig.json.
- A parser installed mid-session is found on a fresh machine too; the gutter no longer applies a stale branch's base when HEAD moves twice quickly, and its watchers no longer leak after `:saveas` or a wipe during a refresh.
- Kotlin: kotlin-lsp launches through the `current` symlink (a resolved-path launch tried on this branch made updates and rollbacks relaunch the old build, and was reverted); pruning can no longer delete a build a running server uses (a SIGPIPE false negative, unresolved paths) and prunes nothing while any server runs through `current` or without a process list; an update that fails to activate no longer leaves `current` switched or a stray `previous`; an exported `KOTLIN_LSP_DIR` is respected.
- `Space gl`: real ssh host names are kept (only aliases are resolved through ssh config); pushes from single-branch/shallow clones are recognised; names with a leading space or control characters link correctly.
- `Space xr`: a broken sub-chart `values.yaml`/`Chart.yaml` is reported on the sub-chart; tsc needs the project's `tsconfig.json`; nested `node_modules`/dot-dirs are skipped outside git.
- F2 as the only split no longer fails when a floating window (ui2, fidget) is open; gutter watchers are closed when a repo's last buffer is wiped (a `:bdelete`d buffer is unlisted and unloaded, not wiped, and keeps them); LSP installs are gated on a fresh machine too; timed-out `Space gd` requests are cancelled; `valuesfoo.yaml` is no longer a helm values file.
- The whole-branch gutter refresh no longer freezes the editor (every git call is async), uses the repo gitsigns diffs against (symlinked files, nested repos), watches repos opened before their first commit, and no longer stacks autocmds on `:edit`.
- `Space gl`: the "copied" check now works with Linux/WSL clipboard tools; glob characters in file names, ssh host aliases, http(s) ports, NFD file names on macOS and characters like `[ ] { } \` are handled; a global `nvim.forge` no longer re-labels other repos.
- `Space xr`: outside git only the file's directory counts; a new file in a missing directory no longer lints nvim's cwd; more helm output shapes (spaces, sub-chart names, `.tgz`, columns, `:` in paths, broken `values.yaml`); golangci-lint log lines, `FORCE_COLOR` for ruff, `Dockerfile.md`-style files and gitignored Dockerfiles handled.
- tailwindcss no longer roots at `$HOME` because of a `~/package.json`; npm/go/pypi/cargo-built LSP servers are not retried on machines without the toolchain; `:MasonToolsClean` is disabled (it would uninstall every LSP server).
- F2: no `E444` when the terminal is the only window, no second window in a tab that already shows it, and dead terminals no longer pile up. Nested chart `templates/templates/` files are helm; any `yaml.*` filetype gets YAML indent scopes; an unknown lazygit theme key removed; `run_all.sh` shows the failing line.
- Open buffers kept the previous branch's fork point after a branch switch; the whole-branch gutter base is now re-applied whenever HEAD moves — including a rebase or commit in a terminal, which gitsigns' events never reported — by watching each repo's git dir; the check is async and re-diffs only when the fork point changed. A `Space gB` opt-out survives `:e`, and re-opening after `main` moves re-pins the base.
- nvim-surround, gitsigns, git-blame and indent-blankline did not load in brand-new files (`BufNewFile`).
- The indent-scope guide ignored `{ ... }` tables in Lua (and dicts/lists/calls in Python): inside a `vim.lsp.config("x", { ... })` spec it marked the enclosing function instead of the table.
- `:KotlinLspUpdate` did not exist until a Kotlin file was opened.
- `Space xr` failed on ESLint 9 (`-f unix` was removed); it now uses JSON output.
- F2 reopened a dead terminal after the shell exited non-zero (and no longer closes another tab that shows the dead terminal).
- `Space go` handed fake paths from special buffers to the OS opener (on WSL, a random Explorer window); it now refuses them (including scratch buffers named after a real file) and opens the node under the cursor in nvim-tree.
- Inside a chart's `templates/`, `docker-compose.yml` / `.gitlab-ci.yml` got the compose/CI filetype instead of `helm`, depending on rule order.
- Inlay hints sharing a position could get each other's colour.
- `:checkhealth lazy` reported a luarocks ERROR although no plugin needs it (`rocks.enabled = false`).
- Docs: wrong WezTerm font sizes, lazygit symlink path on macOS, stylua drift count, nvm fix location, the GitHub-only forge wording, `delta.gitconfig` header, stale module lists and the undocumented `starship.toml`.

## Unreleased — Helm highlighting and incremental selection

### Fixed

- Option/Alt-Up selection enters Helm's injected YAML tree, starts at content when the cursor is in leading whitespace, and stops at the outermost node instead of restarting. Visual selection rebuilding preserves expansion/shrink history.
- YAML/Helm entry and block selections include first-line indentation and list markers. Helm expansions include complete templated values and bridge from expressions to their enclosing YAML entries. Equivalent visible ranges are skipped, and UTF-8 selection endpoints stay on character boundaries.
- Apply YAML scope selection and endpoint trimming to Helm's injected YAML. Moving into `{{ ... }}` within a YAML value keeps the surrounding mapping or list guide highlighted.
- Anchor Helm lookup at the line's first nonblank character; standalone Go-template directives do not receive a separate template scope guide.

### Added

- Headless regression checks for actual guide columns across Helm keys, list items, and embedded expressions, plus README troubleshooting and design notes.

## 2026-09-14 — Confirmed Kotlin LSP fallback updates

### Changed

- Kotlin LSP updates prefer the latest GitHub release and validate its startup before installation. An explicitly expired GitHub build offers an Open VSX replacement in a second popup; downloading that server requires another `y`.
- Expiry prompts show failed and proposed versions and sources. Older installations without source records are labeled unknown.

### Added

- Retry/dismiss for network, checksum, timeout, and unrelated startup failures. Identical expired builds are skipped, and failed validation preserves the installation.
- In-editor and cross-process update guards, including while awaiting fallback confirmation; atomic activation after successful validation.
- Offline updater tests and headless popup/controller checks. The complete workflow is documented under Troubleshooting in `readme.md` and in `docs/design-decisions.md`.

## 2026-09-07 — Self-managed kotlin-lsp + expiry indicator

### Changed
- **kotlin-lsp is now self-managed, not Mason-installed.** Removed `kotlin_lsp`
  from `ensure_installed` in `lua/plugins/lsp.lua`. The JetBrains `intellij-server`
  is a time-bombed EAP build that expires ~monthly, and Mason's registry trails
  JetBrains by weeks — reinstalling through Mason often just re-fetches the same
  expired build. `lua/plugins/kotlin.lua` now points kotlin.nvim's `KOTLIN_LSP_DIR`
  fallback at `~/.local/share/kotlin-lsp/current` (a symlink to the versioned
  build) when that path exists; refreshing on expiry is a download plus one
  symlink repoint, no config change. See `docs/design-decisions.md` for the build-
  discovery trick (Open VSX `kotlin-server` extension → `server-bundle.json`).

### Added
- **⏱ "expired" state in the statusline LSP indicator**
  (`lua/tajbanana/lsp_status.lua`). A Kotlin buffer with no `kotlin_lsp` client
  ~10s after opening triggers a scan of the LSP log tail for `intellij-server has
  expired`; on a hit the indicator shows a red ⏱ (instead of the generic ✗) and a
  one-shot small floating prompt (`y` = update, `n`/`Esc` = dismiss) offers to
  run `:KotlinLspUpdate` right then. It self-heals to ✓/⟳ once a live build
  attaches. Unit-tested headless.
- **`:KotlinLspUpdate` command + `scripts/update-kotlin-lsp.sh`** to automate the
  refresh. The script discovers the latest build from the Open VSX `kotlin-server`
  extension's `server-bundle.json`, downloads + sha256-verifies it, extracts,
  repoints the `current` symlink, and prunes old builds; it is idempotent and
  platform-aware (darwin/linux × arm64/x64). The command runs it asynchronously,
  streams download progress (phase + live byte %) to a fidget bar, and reattaches
  the server in place. Upkeep on the ~monthly expiry is now: see ⏱ → run one
  command.

### Fixed
- **Statusline no longer repaints on every LSP progress event.** The `LspProgress`
  handler now refreshes lualine only on `begin`/`end` (the state transitions that
  change the icon), not on the frequent `report` events — which previously
  repainted the statusline dozens of times a second while a server indexed.
- **The expiry prompt no longer steals keystrokes mid-edit.** It fires only in
  normal mode (retrying briefly otherwise), so the focus-grabbing float can't
  swallow characters typed while you're in insert/visual.

## 2026-08-12 — LSP load-status indicator, forge auto-detection

### Added
- **Per-language LSP load-status indicator** in the lualine statusline
  (`lua/tajbanana/lsp_status.lua`), shown beside the filetype: ✓ green (the
  file's language server has attached *and finished loading* — it waits on LSP
  work-done `$/progress`), ⟳ yellow (attached but still indexing), ✗ red (a
  server is expected for the filetype but none has attached, e.g. an expired
  kotlin-lsp), ○ grey (no server for this filetype), blank (no filetype). Only
  each filetype's primary server counts — a `.tsx` buffer draws ts_ls, eslint
  and graphql, but the indicator tracks ts_ls — so an auxiliary client settling
  can't make it flicker.

### Changed
- **Forge shortcuts auto-detect the forge from the remote** (`github.lua` →
  `lua/tajbanana/forge.lua`). `<leader>gm` / `<leader>gl` now choose GitHub vs
  GitLab URL shapes per buffer from the remote host — including self-hosted
  instances — so one config serves a GitHub checkout and a GitLab checkout on
  the same machine with no per-machine branch. This supersedes the 2026-08-04
  `gitlab.lua` → `github.lua` port below. New `lua/tajbanana/platform.lua`
  centralises mac/wsl/linux/windows detection.
- **`<leader>go` picks the launcher per platform** and reports failures: `open`
  on macOS, `explorer.exe` (with a `wslpath -w` path) on WSL, `xdg-open` on
  Linux — chosen explicitly rather than through `vim.ui.open`, whose preference
  order silently broke `<leader>go` on WSL once `xdg-utils` landed on `PATH`. A
  non-zero exit now surfaces as an error toast (WSL exempt — `explorer.exe`
  returns 1 even on success).

### Fixed
- A batch of highest-severity code-review findings across the editor, git,
  diagnostics and filetype handling (see `docs/reviews/`).

## 2026-08-04 — GitHub port, cross-platform WezTerm, audit fixes

### Added
- **git-delta side-by-side diffs** in all three places diffs are read:
  `lazygit/config.yml` (new, symlinked to `~/.config/lazygit/`) points lazygit's
  pager at delta with `--width=variable` so the split tracks the panel
  *(2026-09-29: measured in a pty at 60 and 120 columns, the split is the same
  without it; the flag only stops delta padding line backgrounds)*;
  `git/delta.gitconfig` (new, `include`d from `~/.gitconfig`) covers terminal
  `git diff`/`show`/`add -p`; and `lua/tajbanana/git_pickers.lua` (new) adds
  `<leader>gc` (repo commits) and `<leader>gh` (current file's history), both
  previewed through delta. All three are themed to the Material Darker palette.
  The pickers drop to a unified diff below 120 columns, where a side-by-side
  split is too narrow to read. *(2026-09-29: now measured on the preview pane,
  100 columns.)*
- **`<leader>go`** — open the current file in the OS default app. Now genuinely
  cross-platform: it goes through `vim.ui.open` (was a hardcoded macOS `!open`,
  which simply errored on Linux/WSL) and translates the path with `wslpath -w`
  under WSL, where the launcher is `explorer.exe`.
- **`cmp-buffer`** — nvim-cmp listed a `buffer` fallback source but the plugin
  providing it was never installed, so word-from-buffer completion silently did
  nothing.

### Changed
- **GitLab → GitHub**: `gitlab.lua` replaced by `github.lua`; `<leader>gm` /
  `<leader>gl` now build GitHub URLs (`/pull/<n>`, `/compare/<branch>?expand=1`,
  `#L10-L20`) and prefer `gh` with a token-free `git ls-remote` fallback.
  `.ideavimrc` remapped to the IntelliJ GitHub actions to match.
- **`.wezterm.lua`** merged the macOS and Windows forks into one file branching
  on `target_triple`, with WSL domains, per-platform keys/fonts, and kitty
  graphics enabled on both (its absence was blanking inline images on Windows).
- **Whole-branch gutter** now also tries `origin/main` / `origin/master`, so a
  `--single-branch` clone or `git worktree` checkout with no local `main` gets
  the branch view instead of falling back to the index.
- **nvim-lspconfig loads eagerly** (`lazy = false`). On `BufReadPre` it never
  loaded for brand-new files, so a new buffer got no LSP, no completion and none
  of the `LspAttach` keymaps. Adding `BufNewFile` is not a fix — lazy suppresses
  events while loading, which swallows the buffer's `FileType` event entirely.

### Fixed
- **Error on every branch switch**: the whole-branch latch indexed
  `ev.data.buffer` unconditionally, but gitsigns emits `GitSignsUpdate` from
  three places and only one carries `data` — so each data-less emit threw once
  per attached buffer.
- **Stale gutter base**: the merge-base cache was keyed by repo only and never
  invalidated, so every branch after the first reused the first branch's fork
  point for the rest of the session. Now keyed by repo *and* HEAD.
- **Stray `stylua` LSP client**: `automatic_enable` turns on every installed
  server lspconfig knows about, and lspconfig ships an `lsp/stylua.lua` wrapper —
  so Mason having stylua for conform spawned `stylua --lsp` as a second
  formatting provider on every Lua buffer. Added to `exclude`.
- **Duplicate filename in the statusline**: `lualine_a` was overridden to the
  prettified filename while `lualine_c` kept lualine's default `filename`.

### Known issues
- 31 findings remain open from the same audit — 4 High (Rust files throw and
  render unhighlighted; Helm templates draw thousands of bogus diagnostics;
  `<M-Up>` errors at the treesitter root). Each is reproduced and written up in
  [`docs/reviews/audit_004_outstanding_findings.md`](docs/reviews/audit_004_outstanding_findings.md),
  with the test harness beside it.

### Docs
- Corrected the file-tree startup claim, the Kotlin/JDK prerequisite (ktlint is
  a JVM tool), the cargo PATH portability note, the nvm version-selection rule
  (it honours nvm's `default` alias, not simply "newest") and its location
  (`env.lua`, not `set.lua`), and the "Kotlin has no formatter" entry.
  Documented `<leader>go` and `<leader>e`.

## 2026-07-25 — Markdown rendering, inlay tinting, branch-review 003 fixes

### Added
- **In-buffer markdown rendering** (`markdown.lua`, render-markdown.nvim):
  headings/lists/code/tables render in the buffer on the markdown filetype;
  `<leader>md` toggles it. Added the `markdown_inline` treesitter parser.
- **Per-kind inlay-hint tinting** (`inlay_tint.lua`): type hints wear the type
  colour and parameter hints the parameter colour, each faded toward the
  background. `<leader>ti` still toggles hints on/off.
- **Untracked-file git signs**: genuinely untracked files show a distinct
  dashed `┆` in muted sage-green (the whole-branch base is scoped to
  fork-existing files so branch-new commits stay clean, not dashed).

### Changed
- **Parameters are orange in every language** (were white in TS/TSX/JS and
  Kotlin); variable declarations stay white.
- Git gutter add/change/delete colours brightened; snacks' markdown
  document-image float disabled (WezTerm can't render it inline).

### Refactored (branch-review 003)
- `set.lua` slimmed to core settings; the terminal toggle, incremental
  selection and PATH fixes moved to `terminal.lua`, `incremental_selection.lua`
  and `env.lua`. The `<leader>gd` picker moved to `definition_picker.lua`
  (`lsp.lua` 490 → 334 lines). Git-root resolution shared via `gitutil.lua`.
  Colorscheme keyword captures table-driven.

### Fixed (branch-review 003)
- Visual-mode `<leader>gl` opened the wrong GitLab line range (stale marks).
- `<leader>xr` reported "no issues" when the linter had crashed; nvm version
  sort could crash the whole config load; several buffer-state leaks
  (incremental selection, gitsigns autocmd / whole-branch flag) and unescaped
  Telescope ignore patterns. Added `stylua.toml` so formatting doesn't rewrite
  config Lua to tabs.

## 2026-07-24 — Whole-branch git gutter, hunk-nav previews

### Added
- **Whole-branch git gutter** (`<leader>gB`): the sign column now diffs each
  file against the branch fork point (`git merge-base HEAD main`) by default, so
  every line changed on the branch stays marked even after committing —
  IntelliJ's per-branch view. `<leader>gB` toggles a buffer back to the plain
  working-tree (index) view. Applied by latching on the first `GitSignsUpdate`
  so gitsigns' initial index diff doesn't overwrite it.
- **Hunk-nav diff preview**: `<leader>pp`/`<leader>oo` now pop a diff preview of
  the hunk they jump to, dismissed on cursor movement or `Esc`.

### Changed
- Git gutter sign colors set explicitly: add=green, change=blue (IntelliJ's
  "modified" marker), delete=red.

### Removed
- **MR URL session cache** (`<leader>gm`): each press now resolves the merge
  request fresh instead of caching a per-session result, so a just-created or
  re-created MR is always picked up. The lookup is async, so nvim still never
  blocks on it.

## 2026-07-23 — Per-line blame, buffer navigation, images, gotmpl

### Added
- **Per-line git blame** (`<leader>gb`, blame.nvim): every line annotated with
  its own commit/author/date, IntelliJ-style, replacing the grouped gitsigns
  pane whose layout plus scrollbind drift kept misreading as misalignment.
  Focus stays in the editor; topline re-sync plus a per-scroll repaint keep
  rows honest.
- **Buffer navigation replaces harpoon**: `<leader>]`/`<leader>[` cycle open
  files, `<leader>fb` picks from them (most-recent first, `dd`/`Alt-d` closes
  the highlighted buffer in the picker). Harpoon removed — the pinned-slot
  jumps were unused.
- **Inline raster image viewing** (snacks.nvim + WezTerm kitty graphics):
  png/jpeg/gif/webp render in the buffer; `.svg` deliberately opens as XML
  source after SVG rasterization proved unreliable on WezTerm stable.
- **Helmfile/gotmpl support**: `*.yaml.gotmpl` → helm filetype with combined
  yaml+gotmpl treesitter highlighting and helm-ls hover/completion.
- **nvim-tree**: `E` now toggles recursive expansion of the directory under
  the cursor (was: expand the entire tree).
- **WezTerm**: tabs title as `[app] dir` when a TUI runs (bold app tag);
  jar/jrt library classes decompile into the `<leader>gd` picker preview.

### Changed
- Backgrounds 30% darker and desaturated toward grey across every surface.
- vim-fugitive removed (lazygit + gitsigns.diffthis cover it).

## 2026-07-20 — Color parity round 2, completion upgrades

### Fixed
- Cross-language color audit (16-language multi-agent sweep,
  `docs/2026-07-20-color-discrepancy-audit.md`): restored 12 highlight groups
  whose treesitter captures had been renamed upstream (`@function.method.call`,
  `@variable.parameter`, `@boolean`, `@number.float`, …) — onedark defaults
  had been leaking through in most languages.
- nvim-cmp dropdown borders (newer cmp defers to the empty `winborder`
  option; the rounded style is now explicit).
- nvim-tree ragged-edge redraw artifacts: fixed width 40 instead of
  adaptive resizing.

### Added
- **Kotlin** IntelliJ Material Darker parity (pixel-sampled): purple italic
  keywords and annotations (annotation query above semantic-token priority),
  white constructor properties and constants; functions stay blue, class
  declarations yellow.
- **Plain TypeScript** parity, matching the tsx scheme (purple italic
  keywords and primitive types, green italic type aliases, yellow free
  functions, blue methods/setters, white params/props).
- Snippets: friendly-snippets collection wired into the existing LuaSnip
  setup (~2k snippets across all languages), IntelliJ-style **super-Tab** —
  Tab confirms completion, then jumps snippet placeholders (S-Tab back);
  Enter confirms an explicitly selected item.
- `<leader>gd` picker: kind tags shown first and palette-colored
  ([def] yellow, [type] green, [impl] blue, [ref] purple).
- Telescope `filename_first` path display — filenames stay visible on
  deeply nested paths.
- lazygit integration (`<leader>lg`, opens files in the host nvim).

## 2026-07-19 — Language tooling overhaul

Fixes for four silent breakages plus a feature wave. Full report:
`docs/2026-07-19-tooling-overhaul.md`.

### Fixed
- Kotlin LSP crashing on JDK 25: migrated from the unmaintained fwcd
  kotlin-language-server to JetBrains **kotlin-lsp** (+ kotlin.nvim).
- All Node-based language servers dying with exit 127: nvm is lazy-loaded in
  the shell, so `set.lua` now puts the newest nvm node on nvim's PATH.
- Treesitter completely inert: installed the missing `tree-sitter` CLI, added
  the `vim.treesitter.start()` FileType autocmd the main branch requires,
  installed all 25 parsers, and fixed a parser/query version skew that had
  disabled Kotlin highlighting.
- nvim-tree growing to full width: bounded to 25–45 columns.
- stylua configured but not installed; kotlin-lsp corrupted analyzer cache.

### Added
- Language support: Python (pyright), Go (gopls), Bash (bashls), Rust
  (rust_analyzer + rustup toolchain installed on the machine).
- Unified `<leader>gd`: one Telescope picker merging definitions, type
  definitions, implementations, and references from every attached client,
  with palette-colored `[def]/[type]/[impl]/[ref]` tags.
- Plugins: fidget.nvim, which-key.nvim, trouble.nvim, telescope-fzf-native,
  telescope-ui-select, kotlin.nvim.
- prettier formatting for web filetypes via conform; `<leader>fw` → live_grep.
- TSX highlighting matched to IntelliJ Material Darker via pixel-sampled
  screenshots (`docs/tsx-intellij-color-parity.md`), including a custom
  treesitter query for hook-setter declarations.
- Project docs: CLAUDE.md, add-neovim-plugin skill, rewritten readme.

## 2026-04-18 — Plugin manager migration

- Migrated from packer.nvim to **lazy.nvim** with auto-discovered specs in
  `lua/plugins/`, native LSP config (`vim.lsp.config`) + Mason
  `automatic_enable`, and conform.nvim replacing none-ls formatting.
  Design spec: `docs/superpowers/specs/2026-04-18-lazy-nvim-migration-design.md`.

## 2024-08 → 2024-09 — Navigation & housekeeping

- Added **harpoon** (harpoon2) quick file navigation with Telescope picker.
- Removed autosave; remapped vim-test; LSP config cleanups; WezTerm config
  added to the repo (blinking cursor, fonts, macOS keybindings).

## 2024-06 — Editing conveniences

- autoclose.nvim, vim-test, nvim-tree focus-follows-file, diagnostic jump
  remaps, format tweaks, autosave experiment (later removed), readme updates.

## 2024-01 → 2024-02 — Completion, git, formatting

- nvim-cmp + LuaSnip completion; gitsigns hunk workflow; none-ls with
  format-on-demand; surround + Comment plugins; `.ideavimrc` introduced and
  symlinked for IntelliJ parity; color refactors (colors.lua).

## 2023-12-29 → 2023-12-31 — Initial configuration

- Initial packer.nvim-based config: core settings and keymaps (leader =
  Space), onedark colorscheme with custom Material-inspired colors,
  nvim-tree + web-devicons, Telescope, treesitter, LSP with go-to-definition,
  system clipboard integration, multi-language server setup.
