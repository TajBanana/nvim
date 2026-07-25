# 2026-07-26 — Cross-language color audit (20 languages)

Multi-agent audit: one read-only sub-agent per language (20 parallel), each
opening real `~/Documents` project files in headless nvim under a pty (to force
decoration-provider rendering) with the language's LSP attached where one
exists. Each agent walked every word-token position, computed the *effective*
(highest-priority colored) highlight group + fg per role, and checked it against
the one-consistent-scheme role→colour map. This audit followed the
[2026-07-20 audit](2026-07-20-color-discrepancy-audit.md) and the switch to the
single consistent scheme (see `design-decisions.md`, "Colors").

## Headline

The consistent scheme is **correct in every language for every group it
defines** — zero cases of a defined role rendering the wrong colour. Every
defect was the same class as the earlier `console`→red bug: **captures the
scheme never mapped, so onedark's stock defaults leaked through off-palette.**

- **Clean (11):** yaml, tsx, html, groovy, toml, properties, json, css,
  typescript, sql, graphql
- **Leaks found (7 classes) — all fixed** in this commit
- **LSP/grammar quirks (noted, not scheme bugs):** left as-is

## Finding 1 — unmapped captures leaking onedark defaults (FIXED)

All additive overrides in `colorscheme.lua`; no existing role colour changed.

| Unmapped capture | Leaked color | Now | Confirmed in |
|---|---|---|---|
| `@comment.documentation` | `#455574` | comment grey `#546E7A` | rust `///`, kotlin KDoc, java Javadoc, js JSDoc |
| `@string.special` / `.path` | teal `#1b6a73` / `#8bcd5b` | string green `#C3E88D` | xml prolog encoding, bash `/dev/null` |
| `@function.macro` + `@lsp.type.macro` | teal `#34BFD0` | function blue `#5B8EFF` | rust macros, python raw-string `r"…"` prefix |
| `@lsp.typemod.property.static` / `.readonly` | grey-blue `#B2CCD6` | constant white `#EEFFFF` | java static-final constants (jdtls emits them as generic `property`) |
| `@none` | slate `#93A4C3` | white `#EEFFFF` | scala, bash, kotlin, python (unclassified idents) |
| `@label` | red `#F65866` | cyan `#89DDFF` | bash heredoc markers |
| `@markup.*` (heading/strong/italic/raw/link/list/quote) | onedark reds/greens/teals | palette | markdown (all of it), xml CDATA (`@markup.raw`) |

The Java case reuses the pattern already present for `@lsp.typemod.variable.static`
(colorscheme.lua) — jdtls has no distinct semantic token for static-final
constants, so they arrive as `property`; the new static/readonly property rules
pin them back to constant white. The `@markup.*` block also closes the markdown
item that the 2026-07-20 audit's Finding 3 had deliberately left pending;
render-markdown.nvim styles the *rendered* view separately, these cover the raw
buffer text.

## Finding 2 — LSP/grammar quirks, deliberately not changed

Not scheme bugs — the target groups are correctly coloured; the server or
grammar buckets the token wrong, and there is no clean scheme-level fix.

- **sql** `NULL` → cyan: tree-sitter-sql grammar quirk.
- **rust** `Some`/`Ok` → function blue, some locals → namespace yellow:
  rust_analyzer mis-classifies these semantic tokens.
- **typescript** interfaces → yellow (not green italic): ts_ls does not emit the
  `interface` semantic token for the sampled declarations, so only treesitter's
  generic `@type` fires.
- **js/ts** `this` occasionally white: ts_ls sometimes stamps `this` with the
  `defaultLibrary` modifier, colliding with the deliberate console/Math→white
  rule (`@lsp.typemod.variable.defaultLibrary`). Same token type+modifier as a
  genuine global — can't disambiguate without breaking the globals rule.
- **js** `Math` flips cyan/white across files: treesitter `@type.builtin` vs
  ts_ls `defaultLibrary` semantic token, decided by which layer wins the render
  race per file. Cosmetic.

## Probe notes

- `string.regexp` is intentionally orange (a deliberate literal-pattern accent,
  not prose green) — surfaced by several agents as a deviation from the blanket
  "strings are green" expectation, but it is a scheme choice, not a leak.
- Harness limitation: the probe samples only `[%w_]` word-char positions, so it
  cannot empirically confirm operators/brackets/delimiters — those were verified
  by static inspection of the query + colorscheme instead (all on-palette).
- kotlin/java carried the longest cold-start LSP waits (~150s); treesitter-only
  languages (scala/groovy/sql/xml/toml/properties/markdown) needed only ~8s.
