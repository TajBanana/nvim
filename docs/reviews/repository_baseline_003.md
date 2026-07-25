## 2026-07-25 - feat/per-line-blame-images-gotmpl [26ff2ee]

Whole-codebase baseline review (mode: baseline, generic/Lua stack). 15 findings —
1 High, 7 Medium (1 carried-forward opt-out), 6 Low. The user chose to fix
everything except the carried-forward opt-out (M8), including the three findings
the derivation had recommended for the backlog (M2, M3, L3). 1 of 1 prior ignored
issues still relevant, carried forward (M8).

### Issues Fixed

- H1 (High, regression: low): visual-mode `<leader>gl` read stale `'<`/`'>` marks (fired while still in visual mode) and opened the wrong GitLab line range — now reads the live selection via `getpos("v")`/`getpos(".")`.
- M1 (Medium, regression: low): `set.lua` mixed 4+ concerns — the terminal toggle, treesitter incremental selection, and node/cargo PATH bootstrapping moved to `terminal.lua`, `incremental_selection.lua`, and `env.lua`.
- M2 (Medium, regression: medium): the 160-line `<leader>gd` picker moved out of `lsp.lua`'s LspAttach into `definition_picker.lua` (recommended backlog B1; user chose fix-now).
- M3 (Medium, regression: medium): `colorscheme.lua` keyword→purple-italic captures generated from one source list for base + each language scope, so the copies can't drift (recommended backlog B2; user chose fix-now; verified no existing highlight group's value changed).
- M4 (Medium, regression: low): the incremental-selection node stack is now buffer-scoped, so `<M-Up>`/`<M-Down>` can't apply another buffer's node ranges after a buffer switch.
- M5 (Medium, regression: low): `<leader>xr` no longer reports "found no issues ✓" when the linter itself crashed — a non-zero exit with zero parsed items is surfaced as a tool failure.
- M6 (Medium, regression: low): added `stylua.toml` (4-space, keep single-line guards) so on-demand formatting no longer rewrites config Lua wholesale to tabs.
- M7 (Medium, regression: low): the nvm version sort skips non-`vX.Y` dirs instead of crashing the whole config load on a nil comparison.
- L1 (Low, regression: low): docs drift fixed — CLAUDE.md/readme document the new modules + `markdown.lua`; readme gains the `<leader>md` keymap and a markdown guide; the ".ideavimrc mirrors these keymaps" overstatement corrected; CHANGELOG + design-decisions updated; new `docs/architecture.md` created.
- L2 (Low, regression: low): dead `LineNr` override moved to `colorscheme.lua` (now applies at #737373); `git_in_dir` switched to list-form args; stray blank lines and WezTerm template comments removed. (The `<leader>gf`/which-key "Git / Goto" placement was left as-is — moving an established format keymap is a muscle-memory change, not a code defect.)
- L3 (Low, regression: medium): git-toplevel resolution unified in `gitutil.lua` (was reimplemented in `gitlab.lua`, `repo_diagnostics.lua`, and `git.lua`) (recommended backlog B3; user chose fix-now).
- L4 (Low, regression: low): a `glab` failure no longer masquerades as "no MR" — `<leader>gm` falls back to the token-free ls-remote check, which reports real errors.
- L5 (Low, regression: low): the per-buffer `GitSignsUpdate` latch autocmd is dropped once it fires (was accumulating one per attached buffer for the session).
- L6 (Low, regression: low): Telescope `file_ignore_patterns` are escaped Lua patterns (`"%.git/"`), so a bare `.` no longer hides dirs like `digit/`.
- L7 (Low, regression: low): `whole_branch[bufnr]` is cleared on `BufWipeout`, so a recycled buffer number can't inherit a stale whole-branch flag.

### Issues Added to Backlog

- None.

### Issues Already Tracked

- None. (The repo has no `docs/features/backlog/` or `docs/tech-tasks/backlog/`.)

### Issues Ignored

- M8 (Medium, regression: low)
  - **Issue:** `CHANGELOG.md:64` ("fixed width 40") vs `CHANGELOG.md:99` ("bounded to 25–45 columns") read as self-contradicting against `lua/plugins/ui.lua`, which ships fixed `width = 40` for nvim-tree.
  - **Criticality:** Medium — a reader who misses the dated sections could be misinformed about the current nvim-tree width; low practical impact.
  - **Scope:** pre-existing / baseline.
  - **Regression risk:** low — documentation only.
  - **Why ignored:** False positive. Git history shows the width genuinely evolved (min/max 25–45, then fixed 40); the two lines live in separate dated CHANGELOG sections, each accurate for its date — correct chronological history, not a contradiction. Settled opt-out, not re-litigated.
  - **Carried forward:** from `docs/reviews/branch_review_002.md` (was L1 there; originally M3 in `docs/reviews/branch_review_001.md`).

### Gates

- Test verification: no automated suite by design (readme: "There is no build or test step"). Substitute smoke — headless full-config load: `LOAD_OK plugins=35`, zero errors, on the fixed + squashed tree.
- Code quality: Lua syntax clean over all files; `stylua.toml` added (M6). luacheck not installed. Category 09 (over-engineering) skipped — `ponytail-audit` not installed.
