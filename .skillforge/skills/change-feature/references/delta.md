# US-XXX or UC-XXX: short title — delta

One delta file per affected story or use case, living under `stories/US-XXX-delta.md`
or `use-cases/UC-XXX-delta.md` inside the change folder. Both kinds share the same
two-part shape below. `reconcile-feature` reads the change log to understand intent
and promotes the "Full revised content" into the durable spec.

## Change log

Lists each acceptance criterion / use-case / flow step / business-rule **add**,
**remove**, and **change** relative to the current shipped file. Every entry carries
a one-line rationale. For a brand-new story or use case the change adds (no existing
file to diff against), state that explicitly here instead of a diff.

- Add `AC-4`: service rejects payloads larger than 5 MB — new size guard requested.
- Change `AC-2`: short code length widens from 6 to 8 chars — collision headroom.
- Remove `AC-3`: legacy redirect format dropped — superseded by `AC-4`.

## Full revised content

The complete story or use case **as it should read after the change ships** — the
_to_ state. Use the exact template structure of the matching base spec:
`../refine-feature/references/user-story.md` for a story delta, or
`../refine-feature/references/use-case.md` for a use-case delta. (Both are
co-installed via the `skills` group, so these relative paths resolve at runtime.)

Reproduce every required heading from that template at its original level and order,
filled with the revised content. Do not abbreviate to "unchanged" — the revised
content must stand alone, because `reconcile-feature` copies it verbatim into the
durable spec.
