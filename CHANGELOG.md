# Changelog

Notable changes to this Neovim configuration, newest first. Dates are taken
from git history; entries before 2026 are reconstructed from commit messages.

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
