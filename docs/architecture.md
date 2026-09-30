# Architecture

A single-module personal Neovim configuration managed by **lazy.nvim**. This
document covers the load flow and where things live; [CLAUDE.md](../CLAUDE.md)
has the per-file guidance and [design-decisions.md](design-decisions.md) the
*why* behind the non-obvious choices.

## Load flow

```
init.lua
  ├─ require("tajbanana.set")          -- core options, global keymaps, filetypes, ui2, FIRST
  │    └─ require(...).setup()          -- env, terminal, incremental_selection, forge
  └─ bootstrap lazy.nvim                -- fresh clone checked out at lazy-lock.json's commit
       └─ require("lazy").setup("plugins", { rocks = { enabled = false } })
            └─ auto-discovers every lua/plugins/*.lua spec
```

`set.lua` runs before any plugin so options and PATH fixes are in place when
plugin `config`/`LspAttach` code runs. Most plugins lazy-load on their `keys` /
`cmd` / `event` / `ft` triggers; nvim-lspconfig (with Mason), treesitter,
nvim-tree, snacks and the colorscheme load at startup (`lazy = false`). The
remaining helper modules are set up from their plugin specs (`indent_scope` from
`ui.lua`, `inlay_tint` and `definition_picker` from `lsp.lua`) or required on
demand.

## Directory map

| Path | Role |
|---|---|
| `init.lua` | Entry point — core settings, then lazy bootstrap. |
| `lazy-lock.json` | Plugin commits, lazy.nvim included (pinned by `lua/plugins/lazy.lua`). |
| `lua/tajbanana/set.lua` | Core Vim options, global keymaps (leader = Space), custom filetype detection, the `ui2` message UI. |
| `lua/tajbanana/*.lua` | Standalone feature/helper modules, one concern each (see below). |
| `lua/plugins/*.lua` | One lazy.nvim plugin spec per concern; auto-discovered. |
| `after/queries/<lang>/` | Custom Treesitter highlight queries (`;; extends`) for kotlin, typescript and tsx, at priority 130 so they win over LSP semantic tokens (125). |
| `.wezterm.lua`, `.ideavimrc` | Terminal + IntelliJ-IdeaVim configs living in the same repo. |
| `lazygit/config.yml` | lazygit config (theme, delta diff renderer, `nvim-remote` editing): passed by lazygit.nvim with `-ucf`; linked into `$(lazygit -cd)` only for terminal lazygit. |
| `git/delta.gitconfig` | git-delta settings for terminal git; `include`d from `~/.gitconfig`, not symlinked. |
| `starship.toml` | starship shell prompt (not Neovim); symlinked to `~/.config/starship.toml`. |
| `scripts/` | `update-kotlin-lsp.sh` + `kotlin-lsp-release.py` (Kotlin LSP update/rollback). |
| `scripts/tests/` | Regression checks (headless Lua + an offline Python suite); `run_all.sh` runs them all. |
| `docs/` | This doc and [design decisions](design-decisions.md) (current). Historical records: [`deviations-from-main.md`](deviations-from-main.md) (the 2026-08 Windows/WSL2 Debian setup and the branch-specific changes made then; see its status note), the dated tooling-overhaul and colour-audit write-ups, `reviews/`, and the `superpowers/specs/` design specs. |

### `lua/tajbanana/` modules

Each keeps a single concern out of `set.lua`; `set.lua` or a plugin spec calls
its `setup()`, or it is required on demand by a keymap or another module:

- `forge.lua` — forge shortcuts (PR/MR, commit-SHA permalinks); GitHub/GitLab detected from the remote host.
- `platform.lua` — mac/wsl/linux/windows detection (distro-agnostic).
- `system_open.lua` — OS launcher for `<leader>go` and the forge links.
- `env.lua` — node/cargo PATH bootstrapping when missing from PATH, plus the SDKMAN JDK override.
- `terminal.lua` — F2 terminal-split toggle.
- `incremental_selection.lua` — treesitter `<M-Up>`/`<M-Down>` selection.
- `indent_scope.lua` — cursor-based indent-blankline scope lookup (wired from `ui.lua`).
- `kotlin_update.lua` / `kotlin_update_prompt.lua` — `:KotlinLspUpdate` / `:KotlinLspRollback` controller and its confirmation float.
- `completion.lua` — intentionally unwired paren-skip experiment (see its header).
- `gitutil.lua` — shared git-toplevel resolution.
- `git_pickers.lua` — the `<leader>gc` / `<leader>gh` commit-history pickers (delta preview).
- `repo_diagnostics.lua` — repo-wide lint (`<leader>xr`).
- `definition_picker.lua` — the `<leader>gd` def/type/impl/ref picker (wired from `lsp.lua`).
- `flow_pragma.lua` — whether a JS/JSX buffer has a Flow `@flow` pragma in its leading comments (ts_ls's `root_dir` in `lsp.lua` vetoes those).
- `inlay_tint.lua` — per-kind inlay-hint colouring (wired from `lsp.lua`).
- `tailwind_root.lua` — when the tailwindcss server starts (its `root_dir`, wired from `lsp.lua`).
- `lsp_status.lua` — per-filetype LSP load-status icon in the lualine statusline (wired from `ui.lua`); includes a kotlin-only ⏱ state that detects an expired kotlin-lsp build from the LSP log.

## Conventions

- **Requires Neovim 0.12+** (treesitter `main`, 0.12-only APIs such as `ui2`); **native LSP** (`vim.lsp.config`/`vim.lsp.enable`), no null-ls. Enabled servers are an allow-list (`lsp.lua`'s `servers`).
- **Keymaps** live either in `set.lua` (global) or a plugin spec's `keys`/`config`.
- **Colors** are treesitter captures + LSP semantic tokens in `colorscheme.lua`.
- **No build step.** Regression checks: `bash scripts/tests/run_all.sh`; interactively validate with `:messages`, `:checkhealth`, `:Lazy`, `:LspInfo`.
