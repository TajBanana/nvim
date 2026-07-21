## 2026-07-21 - feat/language-tooling-overhaul [7c534e7750f17868b2de720943ffc4f032f82ac1]

Diff-mode review against `origin/main` (base `857039c`). Stack: generic (Lua
Neovim config). Scope: authored config code (`init.lua`, `lua/**`,
`after/queries/**`, `.wezterm.lua`, `.ideavimrc`, repo docs); vendored
`.skillforge/**`, `.claude/**`, `.github/**` scaffolding excluded. Independent
reviewer subagent (Opus 4.8). No prior report — no carry-forward.

No automated test suite, linter, or CI exists in this repo; as a substitute
correctness gate every in-scope Lua file was loaded headlessly on Neovim 0.12.4
(all parsed and sourced clean). `luacheck`/`stylua` not installed —
code-quality gate recorded absent. Category 09 (over-engineering) skipped —
`ponytail-review` not installed.

### Issues Fixed

- M1 (Medium, regression: low): normal-mode `<M-Down>` was a byte-identical
  duplicate of `<M-Up>` (both merely start a selection); removed it so `<M-Up>`
  is the sole entry point and `<M-Down>` shrinks only in visual mode.
- M2 (Medium, regression: medium): `open_gitlab_mr` hand-rolled remote-URL
  conversion that leaked credentials and mishandled ssh ports, and hardcoded
  `origin`; replaced with a `to_web_url` normalizer (strips `.git`, userinfo,
  ssh port) and upstream-remote detection.
- L1 (Low, regression: low): `open_gitlab_mr` swallowed a failed `ls-remote`
  and silently opened the create page; now surfaces `out.code ~= 0` as an
  error notification.
- L2 (Low, regression: low): `readme.md` and `CLAUDE.md` claimed "Neovim
  v0.9+" while the config needs `vim.lsp.config` (0.11+); corrected to v0.11+.
- L3 (Low, regression: low): `select_node` set the `>` mark at `ec - 1`, which
  is negative for a node ending at column 0; clamped with `math.max(0, ec - 1)`.

### Issues Added to Backlog

- None

### Issues Already Tracked

- None

### Issues Ignored

- M3 (Medium, regression: low)
  - **Issue:** the reviewer flagged `CHANGELOG.md` as self-contradicting on the
    nvim-tree width — line 16 ("fixed width 40") versus line 51 ("bounded to
    25–45 columns"), with `docs/2026-07-19-tooling-overhaul.md:91` also saying
    "25–45" while `lua/plugins/ui.lua` ships a fixed `width = 40`.
  - **Criticality:** Medium — a self-contradicting changelog would misinform a
    reader who cannot tell which statement is current.
  - **Scope:** in-scope (both the doc lines and the width change are on this
    branch).
  - **Regression risk:** low — doc-only.
  - **Why ignored:** false positive. Git history shows the width genuinely
    evolved: commit `c1729a8` set `width = { min = 25, max = 45 }`, then
    `dc84635` changed it to fixed `width = 40`. The two changelog lines live in
    separate **dated** sections (2026-07-19 and 2026-07-20) and each is accurate
    for its date; the 07-19 report likewise records that day's state. This is
    correct chronological changelog history, not a contradiction — editing it
    would make the record less accurate.
