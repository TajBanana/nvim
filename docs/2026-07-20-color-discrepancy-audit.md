# 2026-07-20 — Cross-language color discrepancy audit

Multi-agent audit (16 parallel language probes + synthesis) of two discrepancy
classes across every language in use: (1) colors that differ between a real
buffer and the Telescope preview pane, (2) treesitter captures rendering
outside the Material Darker palette. Probes opened real project files headless
with LSP attached and compared, per screen position, the effective color with
and without the semantic-token layer, plus a full inventory of capture groups
and their colors.

## Finding 1 — one systemic bug caused most mismatches (FIXED)

The nvim-treesitter main branch renamed several capture groups. The
colorscheme still styled the old names, so the renamed captures fell through
to onedark's own defaults — visibly wrong colors in every language outside
the tsx/kotlin parity blocks (which had already been given scoped rules):

| Renamed capture | Leaked onedark color | Now restored to |
|---|---|---|
| `@function.method(.call)` (was `@method.call`) | `#41A7FC` | blue `#82AAFF` |
| `@variable.parameter` (was `@parameter`) | `#F65866` red! | orange `#F78C6C` |
| `@variable.member` (was `@property`/`@field`) | `#34BFD0` | grey-blue `#B2CCD6` |
| `@boolean` (was `@constant.builtin`) | `#DD9046` | cyan `#89DDFF` |
| `@number.float` (was `@float`) | `#DD9046` | orange |
| `@module.builtin` (new subtype; lua `vim`) | `#DD9046` | yellow |
| `@string.documentation` (python docstrings) | `#8BCD5B` | green |
| `@keyword.type`, `@keyword.conditional.ternary` | `#C75AE8` | cyan (purple italic in tsx) |
| `@character.special`, `@string.special.url` | `#F65866`/`#34BFD0` | cyan |
| `@attribute` (java annotations et al.) | `#34BFD0` | purple; java scoped red |
| `@lsp.typemod.variable.static` (go) | `#DD9046` | grey-blue italic |
| `@lsp.typemod.variable.defaultLibrary` (go) | `#F65866` | cyan |

All added as global rules in `colorscheme.lua` (old names kept for compat).
Verified post-fix: lua and java capture scans show zero off-palette colors.
Affected languages before the fix: lua, python, go, java, bash, yaml, json,
css, sql, rust, typescript.

## Finding 2 — Telescope preview vs buffer differences (INHERENT, now small)

Telescope preview buffers get treesitter highlighting only — **no LSP client
attaches to a preview, so semantic-token colors never appear there**. This is
by design in Telescope and applies to every LSP-colored token. After Finding 1's
fixes, the remaining deltas are small because treesitter base colors now agree
with the semantic layer in most cases. What remains:

- clean (0 diffs): python, bash, yaml, json, html, css, sql, markdown
- cosmetic: lua (property grey-blue vs member), rust (a few semantic mods)
- noticeable but rare: tsx local-setter *calls* show yellow in preview vs blue
  in buffer (ts_ls `local` modifier has no treesitter equivalent); go package
  names yellow in buffer (semantic namespace) vs plain in preview
- dockerfile: largest gap (16 tokens) — dockerls semantic tokens vs the
  bash-injection highlighting previews use for RUN lines; cosmetic in practice
- kotlin: constructor-property declarations are white in buffer (semantic),
  orange in preview (treesitter parameter capture)

There is no supported way to attach LSP to preview buffers; closing this gap
further would mean duplicating each remaining semantic rule as a treesitter
approximation. Not recommended — current deltas are minor.

## Finding 3 — items noted, deliberately not changed

- **markdown** renders with onedark's own heading/list/code colors
  (`#F65866`, `#C75AE8`, `#8BCD5B`) — onedark styles markdown deliberately;
  left as-is. Restyle to palette on request.
- **plain .ts files** still use the pre-parity scheme (cyan keywords, blue
  calls) by prior decision — the IJ parity block is tsx-scoped. Extending to
  `.typescript` suffixes is a copy-paste when wanted.
- **html** tags render onedark purple `#C75AE8` rather than the red used for
  tsx builtin tags; left pending a preference call.

## Probe notes

- kotlin was probed treesitter-only (the live session held the kotlin-lsp
  workspace lock); its captures are fully on-palette post-parity.
- The synthesis agent's input payload was lost to a workflow templating bug;
  it re-derived findings for four languages live. Conclusions were verified
  against the raw probe outputs, which all 16 agents returned successfully.
