# The reduction — drawing an assembly or a release

Read this when the subject is a `System` carrying `interface.members`. For a plain `Component` there is
nothing to reduce: draw the boundary and stop.

**The reduction *is* the picture.** For a composed construct, the members nest inside the boundary and
the match → cancel → carry-up operation becomes *visual* rather than described. You are not drawing a
depiction *of* the reduction; you are drawing **its output**.

---

## 1. The operation

Over the member set:

1. **Match** — a member's **ball** (a provided interface) against a sibling's **socket** (a consumed
   one). Match on the committed entity name; a candidate may match too, but see §3.
2. **Cancel** — a matched pair is **internal**. It recedes: drawn faint, inside the box, *not* on the
   surface. It does not cross the boundary, so it is not part of what this construct offers or needs.
3. **Carry up the unmatched surface — both sides:**
   - an unmated **socket** → crosses the boundary **inward**: a **foreign dependency**;
   - an unmated **ball** → crosses the boundary **outward**: the **external provided surface**.
4. **Internalized infra** — infrastructure the parent deploys *for* its members (an in-namespace
   message bus, a secrets release) is drawn **inside**, and the members' former external dependency on
   it **cancels**.

What remains crossing the boundary *is* the composed surface. That is the whole picture.

```text
┌─ alphabet-pub · release · 11 members ─────────────────────────────────┐
│  implements: platform:kubernetes-helm-chart                           │
│                                                                       │
│   ┌ alphazulu ┐        ┌ bravocharlie ┐        ┌ romeosierra ┐        │
│   │           │───────▶│              │◀───────│             │        │
│   └───────────┘        └──────────────┘        └─────────────┘        │
│         mated pairs cancel — drawn faint, internal, not surface       │
│                                                                       │
│   ┌ oscar ┐   ┌ tango ┐      ← present but empty: holes               │
└────────┬──────────────────────────────────────────┬───────────────────┘
         │                                          │
   foreign dependency                        external surface
   ▸ keycloak (oidc)                         ▸ alphabet-ui
   ▸ postgres                                ▸ az-api (via the gateway)
```

---

## 2. Holes participate as holes

A **hole** is a member whose IBOM could not be read (`interface.federation/degraded`). It has no known
interfaces, so:

- it **cancels nothing** — a hole cannot mate with anything;
- it **contributes nothing** to the external surface;
- it is drawn as a **box that is present but empty** (rule 2).

**Never infer a hole's internals from the parent's manifests.** The parent's chart sees ingress hosts
and proxy targets, not the member's contract set, and the names it invents are names the member's real
IBOM will later contradict. A guess must then be *retracted*; a hole is retract-free — recovery is pure
fill-in. And a picture is a *very* persuasive place to pass a guess off as a fact.

An empty box is not a failure of the picture. It is the picture correctly saying: *there is a member
here, and we could not read its interfaces.* That is an interface-level fact, and the reader needs it.

---

## 3. What a match may and may not assume

**Cancellation assumes co-location.** A matched pair cancels only because the members share the
parent's namespace and network. That assumption can be false:

> A member endpoint **hard-coded to a namespace or a host** can make a supposedly-internal edge
> actually cross a boundary.

When you see one, the edge **must not cancel**. Draw it crossing the boundary, and say why. This is not
a cosmetic note — a hard-coded endpoint is the thing that breaks deployment onto someone else's
infrastructure, and the picture is where it becomes visible.

**A candidate may match, but the result is still a candidate.** If a member's candidate provider mates
a sibling's candidate consumer, the pair cancels *as candidates* — drawn faint and internal, but with
the candidate stroke intact. Cancelling a candidate into a firm internal edge would assert a wiring
nobody committed.

**Match on real committed entity names.** The surfaces you carry up must reference the members' own
committed names, read from their IBOMs — not names re-derived from the parent's manifests. A surface
named from the parent's chart is a surface the member will not recognize.

---

## 4. For a release, additionally

A **release** is a `System` **per environment**. Two things are added:

- **The cluster edge** — the actual ingress and egress of the deployed environment. This is the part
  the theory calls *certain*: readable from the ingress/gateway/mesh **without federating anything**.
  It is why Level 0 is the default view.
- **The portability check** — flag any endpoint **hard-coded to our own infrastructure**. It must be
  configurable to be deployable on foreign infrastructure. Draw it crossing the boundary, marked.

---

## 5. The picture is a verifier

This is the property that makes the reduction worth drawing:

- if a supposedly-internal edge **still pokes through the boundary**, the reduction is wrong;
- a co-location assumption that does not hold shows up as an edge that visibly **refuses to cancel**;
- a member that mates with nothing at all is either genuinely standalone, or wired by something the
  ledger does not know about.

**A render that looks wrong is a compose defect, not a drawing defect.** Do not tidy the picture into
looking right. Report what refused to cancel, and leave it visible.

*(Asserted by design. This has not been demonstrated against a fully-federated parent — no member has
yet published its own IBOM, so every reduction to date has run over vendored copies and holes. Treat a
wrong-looking render as a strong signal, not a proof.)*

---

## 6. Zoom, and when to refuse it

- **Level 0** — the boundary alone. Members are not drawn. **The default**, and the only level whose
  content is *certain*.
- **Level 1** — members as boxes, internals collapsed. Answers *which member owns what crosses out*.
- **Level 2** — the full internal wiring, the reduction drawn out.

Descending is descending from what is **known** into what is **inferred**.

**Refuse to descend when the descent would be theatre.** If most members are holes, Level 1 is a row of
empty boxes and Level 2 is nothing at all. Say that, and offer Level 0 — do not draw an impressive
diagram of a surface you could not read.
