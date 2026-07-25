# Changelog

Notable changes to this Neovim configuration, newest first. Dates are taken
from git history; entries before 2026 are reconstructed from commit messages.

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
