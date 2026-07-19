---
name: understand-ibom
type: skill
tags: [interfaces, ibom, understanding, boundary, backstage]
description: Use when you and the caller need to understand a repository through its Interface BOM (catalog-info.yaml) — read the ledger, draw the boundary and what crosses it, explain it plainly, and leave both of you speaking the same vocabulary. Typically the first thing run before architecture work, a redesign, a feature, or a brainstorm. Read-only; it never edits the ledger.
argument-hint: "[optional: path to a catalog-info.yaml or repo; defaults to the current repo]"
version: 2.4.0
compatibility: [copilot, claude]
---

## What this is

**Let's look at the IBOM and understand it together, so we both know what we are talking about.**

That is the whole job. The caller is usually about to *do* something — redesign an architecture, add a
feature, brainstorm, review a boundary — and they are starting cold. This skill is how both of you get
oriented, at the same time, on the same facts, in the same words.

Three things come out of it, and the third is the one that matters:

1. **You understand the repo** through its interfaces — what it offers, needs, conforms to, and copies.
2. **The caller understands it**, from a picture and a plain explanation.
3. **You and the caller now share a vocabulary** — and that vocabulary carries into whatever they do
   next.

**The shared mental model is not a file. It is the vocabulary** (see *The shared vocabulary*). Nothing
is persisted, nothing is stamped, nothing has to be kept in sync. What survives this skill is that
"hole", "candidate", "absorbed", "vendored" and "the reduction" now mean the same thing to both of you.

The whole thing answers **one** question:

> *What does this thing offer the world, what does it need from the world, what does it conform to,
> and where is it holding a copy of someone else's contract?*

The input is a committed `catalog-info.yaml` (an interface ledger). This skill **reads**; it never
writes to the ledger, never edits an interface fact, and never asks the engineer to resolve one.

**The boundary is the primitive — not the node.** An interface *is* a contract at a boundary, so the
picture draws a **boundary and what crosses it**. Everything else in this skill follows from taking
that literally. The four relationship classes are therefore not four flavours of edge; they are **four
different ways of relating to a boundary**, and each gets its own geometry (see *Four classes, four
geometries*).

**Do not draw a node-edge graph.** It is the wrong instrument, for reasons about the model rather than
the tooling:

- **A graph has no boundary.** It knows nodes and edges; it has no notion of *inside* versus
  *outside*. But the whole compose operation is the distinction between an edge that stays inside and
  one that pokes out. A graph cannot express that difference — not inconveniently, but *in principle*.
- **It flattens distinctions the ledger exists to preserve.** A graph has exactly one shape, so
  drawing all four classes as edges asserts three falsehoods: that `implements` has a counterparty
  (it does not), that `absorbs` is a live call (it is a *copy*), and that a candidate is a committed
  edge (it is explicitly not).
- **The subject is a surface, not a network.** The reader is asking what crosses *this* boundary. A
  network diagram answers a question nobody asked, and answers it as a hairball.

## The shared vocabulary

This is the deliverable. **Use each word, and define it inline the first time you use it** — one clause,
in passing, never a glossary dump. By the end the caller should be able to *say* these words back to
you and mean the same thing, because that is what lets them ask a precise question an hour from now.

| Word | What it means, in one line |
|---|---|
| **boundary** | the edge of the thing; an interface is a *contract at a boundary*, so the boundary is what we draw |
| **provides** | a surface it offers outward — a **ball**; others may call this |
| **consumes** | a surface it needs from outside — a **socket**; this depends on something out there |
| **linkage** | a **specific kind of consume**: a first-party library it **builds against** (an org repo on its `pom` / `Cargo.toml` / `package.json` / `go.mod`). Still a socket — but *compile-time*, not a runtime call. A **third-party** package is **not** this: it is SBOM, not an interface edge. |
| **implements** | a **conformance** — it *is* an OCI image, it *is* a Helm chart. A property of the thing, with **no counterparty**. Never an arrow. |
| **absorbs** | it holds a **copy** of a contract someone else owns, because it cannot reach them live. A **twin**. |
| **severed line** | how a copy is drawn: joined to its real owner by a *broken* line, because **nothing connects them at runtime** — so they will drift |
| **candidate** | *evidenced, but not committed.* We have seen it; we are not yet willing to assert it as a graph edge. Drawn, always — with a distinct stroke. |
| **hole** | a member that is **there and unreadable**. Drawn as an empty box. Never filled with a guess. |
| **vendored vs referenced** | a member slot filled by **copying** it vs by **reading the member's own published IBOM**. *Filled is not federated.* A parent that vendored everything reads 11/11 and has federated nothing. |
| **unattributed copy (`⧉?`)** | a surface that **is** a copy, where the ledger does not record *whose*. It may not be this thing's to offer. |
| **internalized infra** | a Resource the construct **deploys itself** (its own database, broker, cluster) — so its members' demand for it *cancels* and never reaches the boundary |
| **the reduction** | for an assembly/release: match provider↔consumer across members, **cancel** the matched pairs as internal, and carry the **unmatched** surface up. What still crosses the boundary *is* the composed surface. |
| **provenance / confidence** | where a fact came from (`human › registry › contract › manifest › code › docs › guessed`) and how sure we are. Shown as a trust tag: `[contract·high]`. |
| **Level 0 / 1 / 2** | how deep we look — and it is a **certainty ladder, not a detail slider**. Going deeper means going from what is *known* to what is *inferred*. The picture should feel *less* certain as you descend, not more impressive. |

**These are load-bearing distinctions, not jargon.** The difference between *provides* and *absorbs* is
the difference between "we own this API" and "we hold a copy of someone else's and it is drifting." The
difference between *filled* and *federated* is the difference between a green number and a real one. If
the caller leaves with only one thing, it should be that these distinctions exist and are worth making.

**Three different "needs" wear the same socket — do not collapse them.** Everything crossing inward
looks alike geometrically, but the ledger means three distinct things, and confusing them is the exact
error the model exists to prevent:

| It… | is called | and means |
|---|---|---|
| **deploys** X itself (its own DB, broker, cluster) | **internalized infra** / a member | it *brought* X — members' demand for it cancels; it never reaches the boundary |
| **builds against** Y (a first-party org library) | **linkage** | a *compile-time* edge into another org repo; the graph recurses it to the org frontier |
| **connects to** Z at runtime (a service, a shared datastore it does not own) | a plain **consume** / a `dependsOn` Resource | a live dependency on something out there |

Say which one it is. *"It builds against `oscar-common` (linkage) and connects to a Postgres it does
not own (a Resource)"* states two very different facts about one repo — a caller redesigning it needs
both, because a compile-time coupling and a runtime one are severed differently.

**Do not lecture.** Define in passing, while saying something useful:

> *"All eleven member slots are **vendored** — filled by copying the member's contracts rather than by
> reading an IBOM the member published. So `11/11` means *filled*, not *federated*: `referenced` is
> `0/11`."*

## How to read this skill

This SKILL.md is the operating procedure and the **policy** — read it in full. It assumes you already
know the rendering languages themselves (Mermaid, Graphviz DOT, SVG, PlantUML syntax); it does **not**
re-teach them. It covers only what is specific to **this picture**: what must be drawn, what must
never be drawn, and how each format is held to that.

**Self-contained:** this skill is `SKILL.md` + the `references/` folder and **nothing else** — it must
not reference any file outside this package (repo theory docs, invariant numbers, sibling skills), so
it travels intact when copied into any repo. State a principle inline; never cite an external doc.

Load-on-demand detail lives beside this file in `references/` — read the relevant one at the moment
you need it:

- `references/ibom-input.md` — the **parse contract**: which ledger annotations carry which class,
  the packed-token grammars, and how to build the render model from entities. **Read before parsing.**
- `references/reduction.md` — the **compose reduction** for an assembly or release: match → cancel →
  carry up the unmatched surface. **Read for a `System` with members.**
- `references/renderers.md` — the **conformance matrix**: how each format realizes each mark, with
  templates, and which formats cannot honour which rule. **Read after the user picks a format.**
- `references/example-run.md` — a full worked run.

## Core principles

1. **The picture renders; it never holds.** It is read-only, derived, and disposable — regenerable
   from the ledger alone. The moment a fact can be *edited* in the view, or exists *only* in the view,
   the view has become a second source of truth. Never write a fact back to the ledger from here.
2. **It must stand alone for a reader with no tooling.** The receiving reader may have no catalog, no
   server, and no network. **No part of the picture may be delegated to a portal UI** — "that part is
   already drawn for us" is the one forbidden move (see *The input, and the one forbidden delegation*).
3. **Never fabricate a surface.** A candidate is drawn *as a candidate*; a hole is drawn **empty**. A
   picture is a *very* persuasive place to pass a guess off as a fact — which is exactly why the bar
   is higher here than in prose, not lower.
4. **Show everything the ledger evidences.** Suppressing a candidate to keep the picture tidy defeats
   the entire purpose of an interface view. A candidate consumed backend *is* something this repo
   consumes.
5. **Trust is a channel, never the content.** Provenance and confidence *modulate how a fact is
   drawn*; they never become the subject.
6. **This is not a review surface, and not a debt tracker.** See *What this must not become* — this is
   the failure mode the skill most needs to resist.

## The input, and the one forbidden delegation

The input is **an IBOM**: the four relationship classes with their direction, each fact's contract
reference and owner, each fact's trust stamps (provenance, confidence, discovery mode), plus
composition membership, parked candidates, and unreadable-member holes. Parse it per
`references/ibom-input.md`.

**What is inherited: syntax and semantics.** The ledger is serialized as a Backstage-shaped
`catalog-info.yaml`. That contract is real, and you read it as such — the entity kinds and relation
names *mean* something, and using that vocabulary to **understand and elaborate** what an entity is
(*this is a component; this is an API it provides; this resource is merely depended upon*) is
legitimate and necessary. Reading the input is not the delegation forbidden below.

**What is not inherited: the UI.** A catalog portal's own graph view is **not** a baseline, **not** a
fallback, and **not** something this picture complements, extends, or replaces. Render the picture
*itself*, from the model, standing alone. **Deferring any part of the picture to a running portal is
forbidden.** It fails twice over: it introduces a **server dependency** into an artifact that must
work without one, and it lets a rendering someone else designed for another purpose decide what this
one shows. The four geometries below exist precisely because no portal graph can express them.

**The serialization is not the subject.** The picture is one representation of the model; the
descriptor file is another representation of the same model. Neither is the model, and neither may
shape the other. Do not let the shape of the YAML leak into the shape of the picture — the failure
mode is real, and it ends with you drawing *the file* rather than *the interfaces*.

## Four classes, four geometries

The load-bearing table. Each class has its **own** geometry, and the geometry *is* the meaning.

| Class | Geometry | Reads as |
|---|---|---|
| **provides** | an arrow **leaving** the boundary — a **ball** offered outward | *supply*: others may call this |
| **consumes** | an arrow **entering** the boundary — a **socket** opened inward | *demand*: this needs something out there |
| **implements** | a **badge on the boundary itself** — no arrow, no counterparty | *a property of the thing*: it conforms |
| **absorbs** | an **inclusion inside** the boundary, joined to its external owner by a **severed** line | *a copy that will drift* |

**`provides` and `consumes` are duals, and must occupy opposing faces.** The *opposition* is the
requirement; which face is which is a rendering convention (pick one and hold it). Their duality is
the entire reason they can cancel in a composed view.

**`implements` is not a relation, so it must not look like one.** It marks the box. A repo that
implements `standard:oci-image` and `platform:kubernetes-helm-chart` is *describing itself*, not
pointing at anything.

### The severed line — the mark that earns the picture

An **absorbed twin** is a copy of an interface owned elsewhere, held locally because a live reference
is impossible. Its correct rendering is a *consumed interface whose arrow is broken*:

```text
     boarding-service  (elsewhere — the real owner)
            roster-api@4.1.0
                  ╎
                  ╎        ← severed: no live edge exists
                  ╎
     ┌────────────╎──────────────┐
     │  gate-scanner             │
     │    ⧉ roster--offline      │   ← the twin, held inside
     └───────────────────────────┘
```

The severed line shows, in one mark and with no prose: **(a)** the contract is owned outside,
**(b)** we hold a copy inside, **(c)** nothing connects them at runtime, therefore **(d)** they will
drift.

**An absorption drawn as an ordinary consumed arrow is not a simplification — it is a lie**, and it
erases the only reason the class exists. If the chosen format cannot draw a severed line, it cannot
render an IBOM containing an absorption (see *Format validation*).

## One box, four zones — the same at every altitude

The primitive view is a **single boundary with four fixed zones**: demand crossing in, supply
crossing out, conformance on the boundary, absorptions within.

```text
   CONSUMES                ┌──────────────────────────────┐            PROVIDES
   (needs)                 │        romeosierra           │            (offers)
   bravocharlie-api ─────▶ │  implements                  │ ─────▶ rs-control-http-api
   postgres         ─────▶ │   ▸ standard:oci-image       │ ─────▶ rs-events-websocket
   nats             ─────▶ │   ▸ protocol:websocket       │ ─────▶ rs-tracks-grpc
                           │                              │
   contracts (elsewhere)   │  ⧉ ABSORBED                  │
        ╎╎╎╎╎╎╎╎╎╎╎╎╎╎╎╎╎▶ │    contracts@67e3716         │
                           └──────────────────────────────┘
```

**Fixed zones are the whole ergonomic claim.** Intuition comes from always knowing where to look —
*what I need* on one face, *what I offer* on the other, *what I am* on the boundary, *what I have
copied* within. A reader learns the layout once and never re-learns it. **Do not vary the zone
assignment between renders**, and do not let a layout engine reposition them.

**It is the same picture for a component, an assembly, and a release.** One mental model covers every
altitude; zooming out does not change the shape, only what has cancelled.

## Zoom is epistemics, not ergonomics

Three levels. The default is **not** a matter of taste:

- **Level 0 — the boundary alone.** What crosses in, what crosses out, what it conforms to. **The
  default view**, because it is the only part that is *certain*: a release's primary deliverable is
  its boundary surface, readable from the ingress and gateway edge without federating anything.
- **Level 1 — members as boxes**, internals collapsed. Answers *which member owns what crosses out*.
- **Level 2 — the full internal wiring**, the reduction drawn out. The *optional deepening*.

Descending a level is descending from what is **known** into what is **inferred**. The zoom is a
**certainty ladder, not a detail slider** — the picture should feel *less* certain as you go in, not
more impressive. Never offer Level 1 or 2 for an entity whose members are mostly holes; say so
instead.

## Trust is a visual channel

The trust stamps **modulate how a fact is drawn**. They never become the subject.

| Ledger state | How it is drawn |
|---|---|
| high confidence / high-tier provenance (`human`, `registry`, `contract`) | a **firm** mark — solid stroke, full weight |
| medium confidence | a normal mark |
| low confidence / low-tier provenance (`code`, `docs`, `guessed`) | a **weak** mark — light stroke, and the tier shown |
| **candidate** (parked, not commit-safe) | a **distinct, weaker stroke** — and **shown, always**. Never a committed edge. |
| **hole** (a member whose IBOM could not be read) | a box that is **present but empty**. Never filled with a guess. |

Annotate each crossing with a compact trust tag — `[<provenance>·<confidence>]`, e.g.
`[contract·high]`, `[guessed·low]` — so a reader can weigh a claim without a legend lookup. One visual
channel plus one terse tag; **zero prose**.

## What the picture must not become

Stated because the pull is strong and the wrong turn is easy. **This section governs the picture.** The
*explanation* is held to a different, related line — see *The explanation* → *Describe the epistemic
state; never prescribe the work*.

- **The picture is not a review surface.** Contradictions, unowned entities, blocking questions,
  `review:` states and federation counters (`4/11`, `referenced: 0/11`) belong to the ledger and to its
  *approver* — someone deciding whether to merge. **Do not render any of them.** The picture answers
  *what is the surface*. Building the worklist instead of the surface is the failure mode this section
  exists to prevent.
- **The picture is not a debt tracker.** *"How much have we not federated yet"* is an adoption metric,
  not an interface fact.

The one apparent exception is not an exception: a **hole is drawn**, because *"there is a member here
and we could not read its interfaces"* is an interface-level fact about the surface. The **count** of
holes is not.

**Why the explanation gets more latitude than the picture.** A picture is read by anyone it is later
pasted in front of, out of context, with no one to ask. The explanation is a conversation with a caller
who is about to make decisions and needs to know **how far to trust what they are seeing** — so it may
say *"treat every owner here as unsettled"* where the picture may not draw `contradicted`. That is a
statement about **reliability**, not a task. The moment it becomes a task, it has stopped being
understanding.

## Rules the picture must obey

Violating any of these makes the picture assert something the ledger refuses to. These are gates, not
guidance — check every one before emitting (see *Format validation*).

1. **A candidate is never drawn as a committed edge.** A missing relation is recoverable; a fabricated
   one corrupts.
2. **A hole is never filled with a guess.** An unreadable member is drawn empty. Never infer its
   internals from the parent's manifests.
3. **`implements` never becomes an arrow.** No counterparty, no edge.
4. **An absorption is never drawn as a live consumption.** The line stays severed.
5. **A user-facing interface terminates at the world, not at a node.** A UI, CLI, or shipped document
   is *provided*, but its counterparty is a **human** — never a catalogued entity. It crosses the
   boundary outward and **ends there**. Drawing a node for the human would put a person in the
   dependency graph.
6. **The picture renders; it never holds.** Read-only, derived, disposable.
7. **It must stand alone for a reader with no tooling.** No portal, no server, no network.

## The explanation — and the trap in it

The picture shows the surface. The explanation says **what it means**. Both go to the caller — in
fenced blocks alongside each other; neither replaces the other.

### Prose is far easier to lie in than a picture. This is the hardest rule in the skill.

Every rule above is enforceable *because a diagram forces a specific mark*. You cannot draw a
"sort-of" arrow. **Prose lets you gesture** — and a gesture is where a guess hides:

> ✗ *"The release exposes a set of frontend UIs and backend APIs."*

That sentence is fluent, useful-sounding, and **launders eleven unattributed copies and seven
name-based guesses**. It asserts ownership the ledger never claimed and user-facing-ness the ledger
cannot support. The picture, drawn honestly, refuses to say it. The prose said it in nine words.

> ✓ *"It offers nineteen surfaces — but **every one is a copy**, and the ledger does not record which
> member each was copied from. So it is not that this release owns nineteen APIs; it is that it holds
> nineteen copies of its members', and nothing connects them to their sources."*

**An "understanding" skill is structurally tempted to fill gaps**, because a good explanation *feels*
incomplete with holes in it — while a good diagram feels *honest* with them. Resist it. The
non-fabrication rules bind the prose **at least as tightly** as they bind the picture:

- **A candidate is spoken of as a candidate.** Never *"it consumes Keycloak"* — *"it looks like it
  consumes Keycloak; that is evidenced but not committed."*
- **A hole is spoken of as a hole.** Never *"oscar provides the artefact store"* when oscar is a hole.
- **A name is not evidence.** `oscar-web-ui` is *named* like a UI. Say *named*.
- **A copy is spoken of as a copy**, every time, even when it is tiresome. Especially then.

### What to say

Lead with what the thing **is**, then the surface, then what you could not determine. Keep it to a
handful of sentences — the picture is doing the heavy lifting.

1. **What it is** — a component, an assembly, a release? one System per environment? how many members?
2. **What it offers** — and *whether it owns what it offers*. This is usually the headline.
3. **What it needs** — and *which kind of need*: does it **deploy** it itself (internalized infra),
   **build against** it (linkage — a first-party org library), or **connect to** it at runtime? These
   are three different couplings; name which.
4. **What it conforms to** — briefly; badges are rarely the story.
5. **What it copies** — the twins, their sources, and the fact that they drift.
6. **What you could not determine** — the could-not-determine block, and in the prose too where it
   bears on the story. It is the most important thing you will say; never soften or skip it.

### Describe the epistemic state. Never prescribe the work.

This is where the line sits, and it is a fine one.

The **picture** stays clean: no review states, no contradictions, no federation counters (*What this
must not become*). But the **explanation** is talking to someone about to make decisions, and they
need to know **how much to trust what they are looking at**. So the explanation *may* say what the
picture may not — as a statement about **reliability**, never as a task:

| ✓ understanding | ✗ worklist |
|---|---|
| *"Every owner here is `contradicted` — CODEOWNERS and the registry disagree — so treat ownership as unsettled."* | *"Fix the owners."* |
| *"No member has published an IBOM, so nothing you see was federated; it was all copied."* | *"Get the teams to run maintain-ibom."* |
| *"Three surfaces have no resolvable contract, so you cannot diff them."* | *"Publish the API entities."* |

**The worklist belongs to the maintenance skill and to the approver deciding whether to merge.** This
skill's caller is asking *what is going on here*. Answer that.

## Choosing the output format

**Ask the user. Do not assume.** After parsing the ledger and before rendering, present the formats and
let them pick. Tailor the list to what the ledger actually needs — if it contains an absorption, say
so, because that is the mark that eliminates weak formats.

```text
I've read the IBOM for <entity> (<n> provided, <n> consumed, <n> conformances,
<n> absorbed, <n> candidates, <n> holes). Which output format would you like?

1. ASCII / Unicode box art  (recommended) — stands alone in any terminal, PR
   comment, or plain-text file. No tooling to render or to read. Honours every rule.
2. Mermaid                   — renders inline in GitLab/GitHub markdown.
3. Graphviz DOT              — best layout control; needs a pinned `dot` to rasterize.
4. SVG                       — a standalone file any browser opens; best for shipping.
5. PlantUML                  — native ball-and-socket; needs a LOCAL renderer.

Zoom level? (default: 0)
  0 — the boundary alone: what crosses in, what crosses out, what it conforms to.
  1 — members as boxes, internals collapsed.
  2 — the full internal wiring, the reduction drawn out.
  Levels 1-2 apply only to an assembly/release, and descend from what is KNOWN
  into what is INFERRED — the picture gets less certain, not more impressive.
```

**Default to ASCII and Level 0** if the user declines to choose. ASCII is the only format that needs no
tool to render *and* no tool to read, so it is the one that can never violate rule 7.

Per-format marks, templates, and the conformance matrix are in `references/renderers.md` — **read it
after the user picks.**

## Format validation

Before rendering, check the chosen format can carry every mark this particular ledger needs. If it
cannot, **say so and offer an alternative — do not silently degrade the picture.**

| The ledger contains… | …so the format must be able to draw |
|---|---|
| an absorption (`interface.direction: absorbed`, or an `absorbed=` candidate) | a **severed** line — broken, no arrowhead |
| a hole (`interface.federation/degraded`) at zoom ≥ 1 | a **present-but-empty** box |
| a candidate (`interface.*/candidate`) | a stroke **visibly distinct** from a committed edge |
| a conformance (`interface.implements`) | a **badge on the boundary** — not a node, not an arrow |
| any content at all | an **inside/outside** boundary with **opposing** provides/consumes faces |

A format that cannot draw a severed line **cannot render an IBOM containing an absorption**. Silently
drawing it as a consumed arrow is the one substitution that is never acceptable.

**The unattributed copy — check for this on every composed entity.** When `interface.federation/mode`
is `vendored` or `mixed`, the construct's member slots were filled by **copying**, so its provided
surfaces are very likely copies too. If those candidates carry no `absorbed=` key naming their source
(and in most committed ledgers today, **they do not**), the copy **cannot be attributed** — and you
must not draw it as a clean ball. Draw it **unattributed**: a candidate whose origin is in doubt,
severed from no named source, and say so. See `references/ibom-input.md` §2c.

This is the single easiest way for this picture to lie: the difference between *"this release offers
two APIs"* and *"this release holds two copies of someone else's APIs"* is invisible in the YAML and
glaring in the render.

## Workflow

- **Step 0 — Locate and read the ledger.** Find `catalog-info.yaml` at the repo root (or the supplied
  path). **If there is none, stop.** Do not discover interfaces, do not scan the repo, and do not
  infer a surface from manifests — this skill renders an IBOM; it does not produce one. Say plainly
  that the repo has no IBOM and that one must be created first.
- **Step 1 — Parse into the render model.** Per `references/ibom-input.md`: resolve each entity, sort
  every fact into one of the four classes, pull the trust stamps, collect the candidate lane, and
  collect the holes. Record, per fact: `name`, `class`, `contract ref` (if any), `provenance`,
  `confidence`, `committed | candidate`, and `absorbed-from` (if a copy).

  **Sweep the whole file, in both directions.** A `System` has **no `spec.dependsOn`**, so its
  infrastructure is not reachable by walking outward from it. Each `Resource` points **inward** at the
  System it belongs to, via `spec.system`. **Scan every entity in the ledger for a `spec.system`
  pointing back at your subject** — those Resources are its database, broker, object store and cluster,
  and they are typically the *highest-provenance facts in the file*. Miss them and you will render a
  release that appears to have no datastore, while faithfully drawing a face full of low-confidence
  guesses. That is the picture inverting its own purpose. See `references/ibom-input.md` §2.
- **Step 2 — Identify the subject and its altitude.** A `Component` renders as a single boundary. A
  `System` carrying `interface.members` is an assembly or release — it has an inside, so Levels 1 and
  2 are available. A `Domain` carries no interfaces: if the subject is a `Domain`, render the
  `System`(s) it wraps, and say that is what you did.
- **Step 3 — For a `System`, run the reduction.** Per `references/reduction.md`: match provider↔
  consumer across members, cancel each matched pair as internal, and carry the unmatched surface up.
  **Holes participate as holes** — an unreadable member cancels nothing and fills nothing.
- **Step 4 — Ask the user for the format and zoom level.** Per *Choosing the output format*. Then read
  `references/renderers.md` for the chosen format.
- **Step 5 — Validate the format against the ledger.** Per *Format validation*. If the format cannot
  carry a required mark, stop and offer an alternative.
- **Step 6 — Render the picture** in the chosen format, in its own fenced block (*Output*). Apply the
  four geometries, the fixed zones, and the trust channel. Run the seven rules as a checklist against it
  before emitting.
- **Step 7 — Explain it, and state what you could not determine** — in fenced blocks alongside the
  picture (they may be separate blocks; *Output*). Per *The explanation*: what it is, what it offers
  (and whether it *owns* it), what it needs (deploys / builds-against / connects-to), what it conforms
  to, what it copies, and — always, ending in `Nothing else` — what the ledger could not tell you.
  Define the vocabulary **as you use it** (*The shared vocabulary*) — that is what the caller carries
  into whatever they do next.

  **Describe; do not prescribe.** No worklist, no recommendations, no counters. If the caller wants to
  act on what they now see, that is the next conversation — and they are equipped to have it, which was
  the point.

## Output — copy-pasteable fenced blocks

**Everything this skill emits goes in fenced code blocks, so the caller can lift it straight into a PR,
a doc, or another file.** Three pieces — the picture, the explanation, and the could-not-determine list.
**They may be separate blocks**; that is fine and often better (the caller pastes the picture one place,
the caveats another).

- **The picture** goes in a fence appropriate to its format: ```text (or ```yaml for monospace ASCII),
  ```mermaid for Mermaid, an SVG file / ```svg for SVG, ```dot for Graphviz, ```plantuml for PlantUML.
  Use the format's native fence so a renderable format still renders where it lands.
- **The explanation** and **the could-not-determine list** go in fenced blocks too (```text is fine), so
  the whole output is uniformly copy-pasteable.

Nothing is required to be one single block. Keep them separate when that helps the caller move each
piece independently.

**Every picture block opens with a one-line provenance header** — entity, view, ledger revision, and a
`derived — regenerate, do not edit` marker, so a pasted picture never gets mistaken for a source of
truth someone can edit (the second-source-of-truth failure rule 6 exists to prevent):

```text
# romeosierra · boundary view (L0) · from catalog-info.yaml @ v1.7.0 · derived — regenerate, do not edit
```

**And closes with the legend** — at the *bottom* of the block, listing only the glyphs the picture
actually uses (one legend covers every picture in a multi-picture block). Header on top, picture next,
legend last — never a legend at the top pushing the picture off-screen. Detail in
`references/renderers.md` §3.

**The render is derived and disposable.** Print it; write it, if anywhere, only to a gitignored
`.backstage/` path. Do not commit a render as though it were a source of truth, and never edit the
ledger to match a picture. **Rasterizing to PNG/PDF is optional**, needs a trusted-source,
exact-version-pinned renderer (never an `apt`/`brew` binary), and never replaces the source text.

### The could-not-determine block is never omitted — say `nothing else` when there is nothing

**In a fenced block. Not only in the chat.** A limitation you only *say* does not travel; the fenced
block is what gets pasted into a merge request and read six months later by someone who was not here —
and by then **an undisclosed limitation is indistinguishable from an assertion.** This is the direct
consequence of rule 7 (*stands alone for a reader with no tooling*).

```text
WHAT THIS COULD NOT DETERMINE
  · <the fact that is missing> — <why the ledger cannot supply it> — <what would fix it, if any>
  · Nothing else.
```

Each entry names the missing fact, why the ledger cannot supply it, and — where one exists — what would
fix it. Always end with `Nothing else`, so completeness is explicit.

**Shipping.** When the caller explicitly asks for something to travel beside an artifact for an external
reader, the standalone extra (SVG or bare ASCII) is the same content in a self-contained file — ask
first; do not publish on your own initiative.

## A property worth knowing: the picture is a verifier

For an assembly or release, the picture is not a depiction *of* the reduction — **it is the
reduction's output.** So:

- if a supposedly-internal edge still pokes through the boundary, **the reduction is wrong**;
- a co-location assumption that does not hold (a member hard-coded to a namespace) shows up as an edge
  that visibly **refuses to cancel**.

**A render that looks wrong is a compose defect, not a drawing defect.** When the picture comes out
misshapen, do not "fix" the drawing. Report what refused to cancel and leave it visible — that is the
picture doing its job.

*(This property is asserted by design and is not yet demonstrated against a fully-federated parent.
Treat a wrong-looking render as a strong signal, not a proof.)*

