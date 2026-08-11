# Architecture

A single-module personal Neovim configuration managed by **lazy.nvim**. This
document covers the load flow and where things live; [CLAUDE.md](../CLAUDE.md)
has the per-file guidance and [design-decisions.md](design-decisions.md) the
*why* behind the non-obvious choices.

## Load flow

```
init.lua
  ├─ require("tajbanana.set")          -- core options + global keymaps, FIRST
  │    └─ require(...).setup()          -- wires in the feature modules below
  └─ bootstrap lazy.nvim
       └─ require("lazy").setup("plugins")
            └─ auto-discovers every lua/plugins/*.lua spec
```

`set.lua` runs before any plugin so options and PATH fixes are in place when
plugin `config`/`LspAttach` code runs. Plugins lazy-load on their `keys` / `cmd`
/ `event` triggers.

## Directory map

| Path | Role |
|---|---|
| `init.lua` | Entry point — core settings, then lazy bootstrap. |
| `lua/tajbanana/set.lua` | Core Vim options and global keymaps (leader = Space). |
| `lua/tajbanana/*.lua` | Standalone feature/helper modules, one concern each (see below). |
| `lua/plugins/*.lua` | One lazy.nvim plugin spec per concern; auto-discovered. |
| `after/queries/<lang>/` | Custom Treesitter highlight queries, above default priority. |
| `.wezterm.lua`, `.ideavimrc` | Terminal + IntelliJ-IdeaVim configs living in the same repo. |
| `lazygit/config.yml` | lazygit config (symlinked to `~/.config/lazygit/`): git-delta pager + matching theme. |
| `git/delta.gitconfig` | git-delta settings for terminal git; `include`d from `~/.gitconfig`, not symlinked. |
| `docs/` | This doc, design decisions, `deviations-from-main.md` (what this machine's branch changes vs `main`, and why), dated review + colour-audit records, and `superpowers/specs/` design specs. |

### `lua/tajbanana/` modules

Each keeps a single concern out of `set.lua`; `set.lua` (or a plugin) calls its
`setup()`:

- `forge.lua` — forge shortcuts; GitHub/GitLab detected from the remote host.
- `platform.lua` — mac/wsl/linux/windows detection (distro-agnostic).
- `env.lua` — node/cargo PATH bootstrapping when missing from PATH.
- `terminal.lua` — F2 terminal-split toggle.
- `incremental_selection.lua` — treesitter `<M-Up>`/`<M-Down>` selection.
- `gitutil.lua` — shared git-toplevel resolution.
- `repo_diagnostics.lua` — repo-wide lint (`<leader>xr`).
- `definition_picker.lua` — the `<leader>gd` def/type/impl/ref picker (wired from `lsp.lua`).
- `inlay_tint.lua` — per-kind inlay-hint colouring (wired from `lsp.lua`).

## Conventions

- **Native LSP** (`vim.lsp.config`/`vim.lsp.enable`) — requires Neovim 0.11+; no null-ls.
- **Keymaps** live either in `set.lua` (global) or a plugin spec's `keys`/`config`.
- **Colors** are treesitter captures + LSP semantic tokens in `colorscheme.lua`.
- **No build/test step** — validate with `:messages`, `:checkhealth`, `:Lazy`, `:LspInfo`.
