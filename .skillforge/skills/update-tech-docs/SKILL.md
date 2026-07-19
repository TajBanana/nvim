---
name: update-tech-docs
type: skill
tags: [documentation]
description: Use when creating or updating Markdown technical docs — architecture.md, developer.md, or troubleshooting.md — in any repository (assembly, multi-module, or single module).
version: 1.7.1
compatibility: [copilot, claude]
---

Create the required directories and documents if not already present. Use existing information from README.md or other sources to populate the documents.

Review all documents to ensure they are up to date with the latest changes, and update any outdated information. Ensure all diagrams are updated to reflect the current architecture and design.

Every Mermaid diagram must be **preceded by a 1–2 sentence description** explaining what it shows and the key insight to draw from it. The description is not a repetition of the section heading — it provides context that helps readers understand the diagram without having to decode it themselves.

Follow the correct section below based on the purpose and structure of the repository.

# Quick Reference

**Repository type:**

| Signal                                                    | Use section                                                 |
| --------------------------------------------------------- | ----------------------------------------------------------- |
| `helmfile.yaml` or `helmfile.yaml.gotmpl` present at root | [Assembly Repository](#assembly-repository)                 |
| Multiple top-level module directories                     | [Multiple Modules Repository](#multiple-modules-repository) |
| Otherwise                                                 | [Single Module Repository](#single-module-repository)       |

**Document inventory by repository type:**

| Document             | Assembly | Multi-module root | Single module / per module |
| -------------------- | :------: | :---------------: | :------------------------: |
| `architecture.md`    |    ✅    |        ✅         |             ✅             |
| `developer.md`       |    —     |        ✅         |             —              |
| `troubleshooting.md` |    —     |        ✅         |    only if real issues     |

# Assembly Repository

If unsure, use the README and the presence of `helmfile.yaml` or `helmfile.yaml.gotmpl` to determine if this is an assembly repository.

An assembly can have multiple variants (e.g. default, dev, prod) that differ in configuration and/or composition. They should be defined as helmfiles in separate directories under the `variants` directory.

Under the `docs/` directory at the root of the repository, include this document:

1. `architecture.md`: High level architecture overview that describes how the assembly composes and orchestrates its constituent services, and the service APIs exposed by the assembly as a whole.

   **DDR cross-referencing:** Before writing or updating this document, scan `docs/ddr/` for accepted DDRs. In any section whose content was shaped by a DDR — a service composition decision under `## Services`, a routing or data-flow choice under `## Data Flow`, or anything else — add a relative link to the relevant DDR so readers can trace the reasoning.

   **Reference structure** (sections may be omitted or added based on the module; order should be followed):
   - `## Overview` — one paragraph: what this assembly does and its role in the system
   - `## Key Responsibilities` _(optional)_ — bullet list of the assembly's primary responsibilities. Omit if the Overview already conveys this sufficiently.
   - `## Directory Structure` _(optional)_ — directory/file layout of the assembly; use a tree or table. Include only when the layout is non-obvious or large enough to need orientation.
   - `## Services` — a self-contained inline table of the services the assembly composes: one row per service with its name and a one-line purpose. Do not link to an external catalog file.
   - `## Data Flow` _(or `## Lifecycle`, `## Startup Sequence`)_ — how data or control moves through the assembly at runtime; Mermaid sequence or flowchart diagram. Prefer a data flow or flowchart-style diagram when the assembly mainly transforms, routes, or persists data across components. Use a sequence diagram when the main point is the time-ordered interaction between actors, services, or steps.
   - Additional sections as the assembly warrants: deployment, configuration, runtime model, key algorithms, etc.
   - If necessary provide additional notes or have dedicated sections for each variant of the assembly.

# Multiple Modules Repository

If there are multiple modules in this repository, create a separate set of documentation for each module in the module's root directory under `docs` subdirectory.

Under the `docs/` directory at the root of the repository, include these documents:

1. `architecture.md`: High level architecture overview that describes how the modules interact with each other and the overall system architecture. Include a `## Modules` section with a self-contained inline table listing each module: its name, a one-line purpose, and a relative link to that module's own `docs/architecture.md`. This document should link to the individual module `architecture.md` documents for more details on each module's internal design.
2. `developer.md`: Instructions for setting up the development environment, building the project, running tests, and any other relevant developer workflows that apply to the entire repository.
3. `troubleshooting.md`: Common issues and their solutions that apply to the entire repository, including debugging tips and known limitations.

In the `README.md` of the repository, include links to each of the above documents. Do not duplicate information in the README that is already covered in those documents. The README should serve as a high level overview and entry point to the documentation, not a detailed technical document itself.

The documentation required for each module is specified in the `Module Documents` section below and should be placed in a `docs/` directory at the root of each module's directory.

# Single Module Repository

For single module repositories, the required documents are the same as listed in the `Module Documents` section below, but they should be placed directly in the `docs/` directory at the root of the repository instead of under a module subdirectory.

# Module Documents

Technical documentation should be stored in a `docs/` directory at the module's root directory and consists of at least these documents in Markdown format with embedded Mermaid diagrams where applicable:

1. `architecture.md`: High level architecture overview with Mermaid diagrams. Use the reference structure below as a guide — sections may be omitted or added based on the nature of the module.

   **DDR cross-referencing:** Before writing or updating this document, scan `docs/ddr/` (or `<module>/docs/ddr/` in a submodule mono-repo) for accepted DDRs. In any section whose content was shaped by a DDR — whether that is a technology choice in Tech Stack, a layout decision in Directory Structure, a design pattern in Internal Design, or anything else — add a relative link to the relevant DDR so readers can trace the reasoning.

   **Reference structure** (sections may be omitted or added based on the module; order should be followed):
   - `## Overview` — one paragraph: what this module does and its role in the system
   - `## Key Responsibilities` _(optional)_ — bullet list of the module's primary responsibilities. Omit if the Overview already conveys this sufficiently.
   - `## Tech Stack` — table of key languages, frameworks, libraries, and tools (**required**)
   - `## Directory Structure` _(optional)_ — directory/file layout of the module; use a tree or table. Include only when the layout is non-obvious or large enough to need orientation.
   - `## Components` _(or `## Modules`, `## Services`)_ — a self-contained inline table listing each item with its name and a one-line purpose. Use the heading that fits the module's nature, and do not link to an external catalog file:
     - `## Components` → programmatic exports (functions, classes, types) other modules import directly
     - `## Services` → remotely accessible APIs (REST, GraphQL, WebSocket, Kafka)
     - `## Modules` → sub-modules (for multi-module/root-level docs)
   - `## Internal Design` _(or `## Design Principles`)_ — design patterns, key abstractions, how components relate; Mermaid diagram where it adds clarity
   - `## Data Flow` _(or `## Lifecycle`, `## Startup Sequence`)_ — how data or control moves through the module at runtime; Mermaid sequence or flowchart diagram. Prefer a data flow or flowchart-style diagram when the module primarily ingests, transforms, routes, or stores data. Use a sequence diagram when the key detail is the ordering of calls or events between participants.

     **For data processing pipeline modules** (Kafka Streams, Spark, Flink, and similar), include two levels of diagram within `## Data Flow`:
     1. **Overview diagram** — one `flowchart LR` covering all external sources and sinks with the major processing stages between them. Gives readers the full end-to-end picture at a glance. Precede with a 1–2 sentence description of what the end-to-end flow covers and any notable routing or filtering at the top level.

     2. **Per-pipeline detail diagrams** — one diagram per significant pipeline. Omit only for trivial single-step pass-throughs. Precede each diagram with a 1–2 sentence description identifying the pipeline by name and its primary transformation goal. For each diagram, show:
        - _Kafka Streams_: input topics → named stream/table operations (filter, map, join, aggregate) → state stores → output topics. Use `[(name)]` nodes for topics and state stores, `[/name/]` nodes for operations.
        - _Spark / PySpark_: input datasets → named transformation stages → output datasets. Mark Spark job stage boundaries where relevant.
        - _Other pipelines_: sources → named transformations → sinks; one node per significant operation.

   - Additional sections as the module warrants: deployment, configuration, runtime model, key algorithms, etc.

   **Module-type hints:**
   - _Runtime/behaviour modules_: emphasise lifecycle and data flow
   - _Interface/API packages_: emphasise module map, design principles, dependency structure
   - _Application entry points_: emphasise configuration, runtime composition, deployment
   - _UI component libraries_: emphasise component overview and design principles
   - _Test/utility libraries_: emphasise key helpers and usage patterns

2. `troubleshooting.md`: **Only create this file if there is real troubleshooting content to record.** Qualifying content is a recurring, non-trivial issue with a known fix, drawn from any of: (a) a problem **actually encountered and resolved in this codebase** (this session or memory) that is **likely to recur** and took significant reasoning effort; (b) a **known-issue or gotcha comment in existing code or config** (e.g. a `// WARNING:` / `# NOTE:` describing a failure mode and its workaround); or (c) **troubleshooting content already living in existing documentation** (a README / design-doc "Troubleshooting" or "Known issues" note) — migrate it here (see *Update Troubleshooting Information*). Do not record one-time issues caused by one-time work or a one-time situation (e.g. a migration step that will never run again, a temporary environment quirk). Do not populate it with generic tips inferred from the module's technology stack or from training knowledge. **Each entry must record its origin** (see *Update Troubleshooting Information*). If no such content exists, omit the file entirely.

In the `README.md` of the module, include links to each of the above documents (`architecture.md`, `troubleshooting.md` as applicable). Do not duplicate information in the README that is already covered in those documents. The README should serve as a high level overview and entry point to the documentation, not a detailed technical document itself.

# Review Existing Documents

When reviewing existing documentation (rather than creating from scratch), read the **full content** of every document being reviewed and check it against **both** criteria below before proposing changes:

1. **Factual accuracy** — verify against the actual codebase:
   - Topic names, class names, module names, profile names
   - Dependency versions in Tech Stack tables
   - Links to other doc files (confirm the files exist)
   - Diagram nodes/arrows accurately reflect current code

2. **Structural completeness** — verify against the required structure for this repository and module type as defined in this skill:
   - All required sections are present and populated (Overview, Tech Stack, Data Flow, etc.)
   - Diagrams meet the depth required for the module type:
     - **Data processing pipeline modules** (Kafka Streams, Spark, Flink): `## Data Flow` must contain both an overview diagram and per-pipeline detail diagrams. A single generic diagram is insufficient.
   - Each Mermaid diagram is preceded by a 1–2 sentence description (not just a section heading).
   - All required documents for this repo type are present (architecture.md; developer.md for a multi-module root; troubleshooting.md if there is real recurring troubleshooting content).

Report both categories of findings before proposing edits.

# Restructuring Existing Documents Without Losing Content

When a required document already exists but its content sits under non-standard or wrong headings — the "does not match the expected structure" case — **restructure it in place and preserve its content**. Never regenerate the document from the template and never overwrite it wholesale; content loss is not an acceptable side effect of restructuring.

1. **Inventory first.** Read the whole document and list every existing block — sections, prose, tables, diagrams, code/config examples, and links.
2. **Map each block to a target section** in the required structure and move it there, renaming the heading to the required name and re-ordering to the required order (e.g. an existing "Design" / "How it works" → `## Internal Design`; an existing "Intro" / "Summary" → `## Overview`).
3. **Preserve content as-is** where it is still accurate; rewrite only what the factual-accuracy check flagged as stale. Do not paraphrase detail away or drop tables/diagrams.
4. **Keep content that has no required section.** The structure permits extra sections — place such content under the closest appropriate heading, or add a new `##` section for it. Only remove content the factual-accuracy check found to be genuinely obsolete, and surface that as a *finding* rather than deleting it silently.
5. **Verify nothing was lost.** Every topic present before the restructure must be represented after it — relocated, renamed, or explicitly flagged obsolete.

The same rule applies when **consolidating or moving** a differently-named or differently-located legacy doc into a required one (e.g. a root `ARCHITECTURE.md`, or a `docs/design.md`, into `docs/architecture.md`): move the content into the required document — do not recreate it and discard the original.

# Ask Clarifying Questions

If there is any ambiguity or missing information that prevents you from accurately completing the documentation, ask specific clarifying questions to resolve those uncertainties before proceeding. Do not make assumptions or use generic placeholder content in the documentation. Prefer multiple choice questions when possible, but open-ended is fine too.

# Update Troubleshooting Information

Populate `troubleshooting.md` from the codebase's own real, recurring issues with known fixes — never generic or inferred advice. Add each qualifying issue to the `troubleshooting.md` of the appropriate module (or the root `docs/` directory if general to the repository). Qualifying sources are:

- **Encountered this session** — a problem you actually hit and resolved that is likely to recur and took significant reasoning effort. Skip one-time issues from one-time work or a temporary environment quirk.
- **Existing code/config comments** — a known issue, gotcha, or workaround already documented in a comment (e.g. `// WARNING: …`, `# NOTE: if X then Y`). **Derive** an entry from it and capture the issue + fix; the comment **stays at its code site** (it is contextual there), so this is not a migration — just cite it as the origin.
- **Existing documentation** — troubleshooting notes already sitting in a README, design doc, or similar. **Migrate** them into `troubleshooting.md` per *Restructuring Existing Documents Without Losing Content* — move the content, do not duplicate it: leave a pointer or remove the migrated note from the source.

Still excluded: generic or inferred advice that is not grounded in an actual codebase artifact or a real encountered problem.

**Each entry must document its origin.** End the entry with a short `_Origin: …_` note recording where the tip came from — for example `_Origin: encountered in this session_`, `_Origin: code comment at src/foo/Bar.kt:42_`, `_Origin: config comment in helm/values.yaml_`, or `_Origin: migrated from README.md "Troubleshooting" section_`. The origin makes each tip auditable and lets a later review confirm or retire it.
