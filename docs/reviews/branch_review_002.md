## 2026-07-21 - feat/language-tooling-overhaul [2dd8f34cb907c31b278de254030e21be8a87690b]

Diff-mode review against `origin/main` (base `857039c`), cumulative over the
branch with deepest attention on the commits after review 001's recorded tip
(`7c534e7`): the GitLab module, the repo-wide lint module, the inlay-hint
enable logic, the statusline changes, and the documentation wave. Stack:
generic (Lua Neovim config). Scope: authored config code and repo docs;
vendored `.skillforge/**`, `.claude/**`, `.github/**` excluded. Independent
reviewer subagent (Opus 4.8). Prior report: `branch_review_001.md` — its one
ignored issue re-verified and carried forward (1 of 1 still relevant).

No test suite, linter, or CI exists; substitute gates: full headless load on
Neovim 0.12.4 (clean), `luajit -bl` syntax pass over changed Lua (clean), tsx
treesitter query parse (valid), tsc/`%D` errorformat parse-and-filter check
(correct). `luacheck`/`stylua` not installed — code-quality gate recorded
absent. Category 09 skipped — ponytail-review not installed; the native
redundant-implementation probe found none.

### Issues Fixed

- M1 (Medium, regression: low): the `inlay_hinted` per-buffer guard was never
  cleared, so a wiped buffer's reused number silently suppressed inlay hints
  for the next file; cleared on `BufWipeout`.
- L2 (Low, regression: low): CLAUDE.md's editor.lua inventory still listed
  undotree, removed this branch; corrected to trouble.
- L3 (Low, regression: low): GitLab URLs interpolated branch names and file
  paths without percent-encoding; added `encode_component` (encodes
  `# ? % & = +` and whitespace, keeps `/`) at both URL-building sites.

### Issues Added to Backlog

- None

### Issues Already Tracked

- None

### Issues Ignored

- L1 (Medium, regression: low)
  - **Issue:** `CHANGELOG.md:16` ("fixed width 40") vs `CHANGELOG.md:51`
    ("bounded to 25–45 columns") read as self-contradicting against
    `lua/plugins/ui.lua` shipping fixed `width = 40`.
  - **Criticality:** Medium — a reader who misses the dated sections could be
    misinformed about the current nvim-tree width.
  - **Scope:** in-scope (both doc lines and the width change are on this
    branch).
  - **Regression risk:** low — doc-only.
  - **Why ignored:** False positive. Git history shows the width genuinely
    evolved: `c1729a8` set `width = { min = 25, max = 45 }`, then `dc84635`
    changed it to fixed `width = 40`. The two changelog lines live in separate
    dated sections (2026-07-19 and 2026-07-20) and each is accurate for its
    date — correct chronological history, not a contradiction; editing it
    would make the record less accurate.
  - **Carried forward:** from branch_review_001.md (was M3 there).
