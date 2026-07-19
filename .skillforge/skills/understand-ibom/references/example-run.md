# A worked run

End to end, on a release repo with 11 members, vendored slots, and holes — the case that exercises
every mark. Shows what the skill reads, what it asks, and what it prints.

---

## The input

`catalog-info.yaml` at the repo root (abridged to the annotations that matter):

```yaml
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: alphabet-pub
  annotations:
    interface.implements: platform:kubernetes-helm-chart,standard:oci-image
    interface.members: component:default/alphazulu,component:default/bravocharlie,component:default/romeosierra,component:default/oscar,component:default/tango
    interface.federation: 3/5
    interface.federation/referenced: 0/5
    interface.federation/stale: 0/5
    interface.federation/mode: vendored
    interface.federation/degraded: component:default/oscar@v2.1.0,component:default/tango@v0.9.4
    interface.vendored/alphazulu: source=alphazulu@a1b2c3d4;pinned=v3.2.0;provenance=contract;confidence=high;review=ok;stale=false
    interface.provides/candidate: alphabet-ui,az-api
    interface.provides/candidate/alphabet-ui: provenance=manifest;confidence=high;review=needs-review;absorbed=component:default/alphazulu@a1b2c3d4
    interface.provides/candidate/az-api: provenance=contract;confidence=high;review=needs-review;absorbed=component:default/alphazulu@a1b2c3d4
    interface.consumes/candidate: keycloak,postgres
    interface.consumes/candidate/keycloak: provenance=manifest;confidence=high;review=ok
    interface.consumes/candidate/postgres: provenance=manifest;confidence=medium;review=needs-review
    interface.discovery/checked-at: v4.1.0
    interface.review: needs-review
spec:
  owner: group:airlab
```

---

## Step 0-1 — read and parse

`catalog-info.yaml` found. Parse per `ibom-input.md`:

- **5 members**, of which **2 are holes** (`oscar@v2.1.0`, `tango@v0.9.4` — from
  `interface.federation/degraded`).
- **2 provided candidates**, and **both carry `absorbed=`** — they are **copies vendored from
  `alphazulu`**, not surfaces this release derived itself. **They get a severed line.** This is the
  detail most easily missed: they look like ordinary parked interfaces.
- **2 consumed candidates** — `keycloak` `[manifest·high]`, `postgres` `[manifest·medium]`.
- **2 conformances** — badges, never arrows.
- **`federation: 3/5`, `referenced: 0/5`, `review: needs-review`** — parsed, **never drawn.** These
  are the approver's business, not this reader's.

## Step 2 — the subject

A `System` with `interface.members` → an assembly or release. It has an inside, so Levels 1 and 2 are
available.

## Step 3 — the reduction

Per `reduction.md`. With 2 of 5 members unreadable and 3 filled only by vendored copies, no
provider↔consumer pair matches on committed names — **nothing cancels.** Everything the ledger knows
crosses the boundary. Say so rather than drawing a rich internal wiring that does not exist.

## Step 4 — ask the format and zoom

```text
I've read the IBOM for alphabet-pub (a release System, 5 members).
It has: 2 provided surfaces, 2 consumed, 2 conformances, 2 absorptions
(both provided surfaces are vendored copies from alphazulu), 4 candidates,
and 2 holes (oscar, tango — their IBOMs could not be read).

Which output format would you like?
  1. ASCII / Unicode box art  (recommended) — no tooling to render or read
  2. Mermaid    3. Graphviz DOT    4. SVG    5. PlantUML

Zoom level? (default: 0)
  0 — the boundary alone   1 — members as boxes   2 — the full internal wiring

Note on zoom: 2 of the 5 members are holes, so Level 1 will show two empty boxes
and Level 2 has almost nothing to draw. Level 0 is the honest view here.
```

> User picks **ASCII, Level 1** — they want to see the holes.

## Step 5 — validate the format

The ledger contains an absorption → a **severed line**; holes at Level 1 → a **present-but-empty box**;
candidates → a **distinct stroke**. ASCII carries all three. Proceed.

## Step 6-7 — the output, in copy-pasteable fenced blocks

The picture in its own fence:

```text
# alphabet-pub · members view (L1) · from catalog-info.yaml @ v4.1.0 · derived — regenerate, do not edit

  alphazulu (elsewhere — the real owner of both surfaces below)
       ╎  [contract·high]
       ╎  ╎  severed: these are COPIES, vendored @ a1b2c3d4. Nothing connects them at runtime.
       ╎  ╎
  ┌────╎──╎──────────────────────────────────────────────────────────────┐
  │    ▼  ▼          alphabet-pub  ·  release  ·  5 members              │
  │  ▸ platform:kubernetes-helm-chart    ▸ standard:oci-image            │
  │                                                                      │
  │   ┌ alphazulu ┐   ┌ bravocharlie ┐   ┌ romeosierra ┐                 │
  │   │  vendored │   │   vendored   │   │   vendored  │                 │
  │   └───────────┘   └──────────────┘   └─────────────┘                 │
  │        nothing mated — no pair cancelled                             │
  │                                                                      │
  │   ▢ oscar          ▢ tango           ← present but empty: holes      │
  │     @v2.1.0          @v0.9.4           (their IBOMs could not be read)│
  └──────┬───────────────────────────────────────────────┬───────────────┘
         │                                               │
    CONSUMES (needs)                              PROVIDES (offers)
    ╌╌▷ keycloak   [manifest·high]                ⧉?╌╌▷ alphabet-ui   [manifest·high]
    ╌╌▷ postgres   [manifest·medium]              ⧉?╌╌▷ az-api        [contract·high]

  ╌╌▷ candidate   ⧉? copy of unknown origin (see below)   ▢ hole
```

The explanation, alongside:

```text
alphabet-pub is a release System — one per environment — composing 5 members. Two (oscar,
tango) are HOLES: present, but their IBOMs could not be read, so they are drawn empty and
contribute nothing.

It looks like it offers two surfaces (alphabet-ui, az-api) and needs two (keycloak, postgres)
— but read the offer side carefully. All five member slots were filled by VENDORING (copying
the member's contracts), not by REFERENCING a member's own published IBOM. So 5/5 means
FILLED, not FEDERATED. And because every slot is a copy, nothing cancelled — a fully-federated
release would show internal edges here; this one shows none.
```

And what could not be determined, in its own block:

```text
WHAT THIS COULD NOT DETERMINE
  · Whether alphabet-pub owns what it offers — both provided surfaces are copies vendored from
    alphazulu@a1b2c3d4, severed from their source, so they will drift. It does not so much offer
    two APIs as hold two copies of a member's. To fix: the members publish their own IBOMs, so
    these graduate from vendored to referenced.
  · The internal wiring, and a trustworthy Level 2 — the reduction's inputs (the members' own
    interfaces) are not in this file; only their vendored copies are.
  · Nothing else.
```

Three blocks, each copy-pasteable on its own. Nothing was written to the ledger.

---

---

## The variant you will actually meet — no `absorbed=`

The run above assumes each vendored surface declares its origin (`absorbed=…`). **Most committed
ledgers do not** — the key is newer than they are. What you will typically find instead:

```yaml
    interface.federation/mode: vendored
    interface.vendored/alphazulu-backend: source=alphazulu-backend@e505023;pinned=v1.12.0;provenance=guessed;confidence=medium;review=needs-review;stale=false
    interface.provides/candidate/alphazulu-backend-http-api: "provenance=contract;confidence=high;review=needs-review"
```

The member slots were **filled by vendoring**, so that provided surface is almost certainly a **copy** —
but nothing says which member it came from. **This is the moment the picture can most easily lie.**

Draw it **unattributed** (`ibom-input.md` §2c) — a candidate whose origin is in doubt, severed from *no
named source*:

```text
    PROVIDES (offers)
    ⧉?╌╌▷ alphabet-ui  ⌾   [contract·high · origin unattributed — may be a vendored copy]
    ⧉?╌╌▷ az-api           [contract·high · origin unattributed — may be a vendored copy]

  ⧉?  origin unattributed: this construct's members were filled by vendoring, and the ledger does
      not record which member this surface was copied from. It may not be ours.
```

And say so plainly in the closing note:

```text
Two of the provided surfaces cannot be attributed. This release filled all its member
slots by vendoring, so these are very likely copies of contracts owned by the members —
but the ledger does not record which member each came from, so I cannot draw the severed
line to a source. I have NOT drawn them as owned surfaces, because that would assert
ownership the ledger does not support.

To resolve: the ledger needs an `absorbed=<ref>@<sha>` key on each vendored candidate.
```

**Never quietly draw an unattributed surface as a clean ball.** It is the difference between *"this
release offers two APIs"* and *"this release holds two copies of someone else's APIs, and nothing
connects them to their source."* Those are different pictures of different systems.

---

## What this run demonstrates

- **The `absorbed=` key in the candidate lane is easy to miss, and missing it is the worst available
  error.** Both provided surfaces looked like ordinary candidates. Drawing them as ordinary candidates
  would have shown `alphabet-pub` *offering two interfaces it owns* — when in truth it holds two copies
  of someone else's, with nothing connecting them. That is the exact lie the severed line exists to
  prevent.
- **The counters were read and not drawn.** `federation: 3/5` and `referenced: 0/5` told the parser
  which members were holes. Neither number reached the picture. *"How much have we not federated"* is
  an adoption metric, not an interface fact.
- **The zoom warning was given before the user chose.** Level 2 would have been an impressive-looking
  diagram of a surface nobody could read.
- **"Nothing cancelled" is a finding, not a rendering failure.** The picture is the reduction's output;
  an empty internal region is it reporting, correctly, that this release has not federated its members.
