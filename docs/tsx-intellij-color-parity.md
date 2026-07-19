# TSX / TypeScript / Kotlin ↔ IntelliJ Material Darker color parity

> 2026-07-20 update: parity now also covers **plain TypeScript** (same rules
> as tsx, `.typescript`-scoped, including primitive types like `string` as
> purple italic and a `useState`-setter query for custom hooks) and
> **Kotlin** (pixel-sampled like tsx: purple italic keywords/annotations —
> annotations via `after/queries/kotlin/highlights.scm` at priority 130 over
> the blue semantic token — white constructor properties and constants;
> unlike tsx, Kotlin functions stay blue and class declarations yellow, which
> is what IntelliJ does there). JS/JSX intentionally keep the original scheme.

Date: 2026-07-19 (revised same day). Matched Neovim's TSX highlighting to
IntelliJ IDEA's Material Darker scheme via pixel-sampling side-by-side
screenshots of real project files (exploration-control-ui).

## Method

1. **Pixel-sampled screenshots** (Python/Pillow): box-sample around each
   token, discard background pixels, take the dominant text color. nvim
   samples reproduced the configured palette exactly, validating the sampler.
2. **Round 1 pitfall (important):** the first IntelliJ screenshot was taken
   while the IDE still showed *"Analyzing…"* — semantic highlighting wasn't
   applied yet, so functions/types/params sampled as plain white. Round 1
   wrongly concluded "most identifiers are white". A second screenshot after
   analysis completed (ExplorationsPage.tsx) gave the true scheme. Lesson:
   only sample IJ screenshots after the analysis spinner is gone.
3. **Scoped all overrides to tsx** (`.tsx` treesitter suffix,
   `.typescriptreact` LSP suffix) in `lua/plugins/colorscheme.lua`; other
   languages unchanged. Keyword *subtypes* need individual `.tsx` overrides
   because a more specific global capture (e.g. `@keyword.import`) beats a
   less specific language-scoped one (`@keyword.tsx`).
4. **Verified effective colors** with `vim.inspect_pos()` + `nvim_get_hl()`
   on the real files with ts_ls attached, checking the winning group per
   token after semantic tokens layer over treesitter.

## The actual IntelliJ Material Darker scheme (sampled, analysis complete)

| Token | Color | nvim group(s) |
|---|---|---|
| keywords, `true/false/null` | `#C792EA` italic | `@keyword.*.tsx`, `@boolean.tsx`, `@constant.builtin.tsx` |
| free functions — declarations and calls (`ExplorationsPage`, `useState`, `fetch`) | `#FFCB6B` | `@function[.call/.builtin].tsx`, `@lsp.type.function.typescriptreact`, `@lsp.typemod.function.declaration.typescriptreact` |
| method calls (`.then`, `.json`, `.find`) | `#82AAFF` | `@function.method[.call].tsx`, `@lsp.type.method.typescriptreact` |
| local function-typed vars (`setIsEditing` calls) | `#82AAFF` | `@lsp.typemod.function.local.typescriptreact` (ts_ls `local` modifier is what splits this from imported functions) |
| interfaces / type aliases (`ExplorationDTO`, `ReactNode`) | `#C3E88D` italic | `@type.tsx`, `@lsp.type.{interface,type}.typescriptreact` |
| classes (`Error`) | `#FFCB6B` | `@lsp.type.class.typescriptreact`, `@constructor.tsx` |
| variables, params, properties, object keys | `#EEFFFF` | `@variable/@parameter/@property` + LSP equivalents (white) |
| JSX attribute | `#FFCB6B` italic | `@tag.attribute.tsx` |
| JSX text | `#EEFFFF` | `@none.tsx` |
| JSX tags red, strings green, operators/brackets cyan | — | already matched |

## Known remaining differences (why they can't be fully matched)

- **Import-clause identifiers** (`import { useState, ExplorationDTO }`):
  IntelliJ resolves each name and colors it by kind (function yellow italic,
  interface green italic). ts_ls emits no semantic tokens for import
  specifiers, and treesitter can't know a name's kind, so they render white —
  except `type X` imports, which treesitter does mark as types (green ✓).
- **Italic-if-imported**: IJ italicizes imported symbols at use sites
  (`useState` call is italic, local calls aren't). No LSP modifier conveys
  "imported", so nvim uses plain yellow for all free functions.
- ~~Function-typed variable declarations~~ — resolved. ts_ls does classify
  `setX` in `const [x, setX] = useState(...)` as `function`+`local` even at
  the declaration; the earlier mismatch was our own
  `@lsp.typemod.function.declaration` yellow rule outranking the `local`
  blue one (removed — the base function token already supplies yellow).
  `after/queries/tsx/highlights.scm` additionally captures the setter of
  `useState`/`useReducer` destructures (`@function.setter.tsx`, priority
  130) so it renders blue immediately, before semantic tokens arrive.
- **IJ inspection rendering** (unused-symbol grey-out, severity underlines,
  inline blame) has no highlight-group equivalent.
- Plain `.ts` files deliberately unchanged (request was tsx); extend with
  `.typescript` suffixes if wanted.

## Side discovery (config-wide, not tsx-specific)

The treesitter main branch renamed several captures: `true/false` now
capture as `@boolean` (the old `@constant.builtin` rule no longer catches
them — onedark's orange default was leaking through), `@method.call` →
`@function.method.call`, `@parameter` → `@variable.parameter`. The tsx block
handles these for tsx; the global rules in `colorscheme.lua` still use some
old names and could be modernized for other languages.
