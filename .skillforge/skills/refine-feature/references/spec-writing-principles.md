# Spec Writing Principles

Feature specs describe **intent, information exchange, and business outcomes**. They do not
describe how the system is built or how its components communicate.

## Core rule

Do not write HTTP methods, URL paths, SQL operations, gRPC method names, queue topic names,
or any other transport/protocol specifics — unless the interface is confirmed to already exist
or has been established as a design constraint.

Express instead:
- What each actor or system does
- What data flows in and out (fields, types, constraints)
- Which actor initiates an interaction and which responds

## Strip form, keep substance

The core rule strips transport **form** — it does **not** license dropping
requirement **substance**. These are different things:

- **Transport form** (strip / re-express): the HTTP verb, URL path, SQL
  operation, gRPC method, queue topic — *how* bytes move.
- **Requirement substance** (always preserve): file formats, field names and
  types, validation rules, value ranges, units, ordering, naming conventions,
  size limits, examples, and sample payloads — *what* the data is.

A file format such as "CSV with columns date, source, amount; amount in cents;
header row required" is **substance**, not transport. It is a requirement and
must be preserved — route it to the use-case `## Data and contracts`
(Inputs/Outputs), a story's acceptance criteria, or, at feature/stub granularity,
the `## Requirement details` section. Never discard it as "implementation detail."

## Confirm before dropping

Re-expressing transport form while keeping the substance is **not** a drop and
needs no confirmation. **Discarding** a user-provided detail is different: never
drop a stated detail silently. If a detail looks like noise or an arbitrary
implementation choice, ask:

> "You mentioned X — is that a hard requirement, or may I choose an alternative?"

Drop it only after the user confirms it is not a requirement (then you are free
to choose an alternative). Otherwise preserve it in the appropriate section.

## Sync/async — specify only when it has business significance

Omit the interaction pattern (sync/async) unless the timing model affects the business outcome.

**Test:** *"If we switch this from synchronous to asynchronous next year, does the core
business goal change?"*

- **Specify** when **yes** — e.g. immediate user feedback is required, ordering guarantees
  matter, eventual consistency is explicitly acceptable as a product decision.
- **Omit** when **no** — the sync/async choice is a technical implementation detail, not a
  business constraint.

## Carve-out

Transport details from user input may be preserved when any of the following is present:

- A spec for the service already exists under `docs/features/implemented/`.
- Code in the current codebase confirms the interface (e.g. a route file, handler, or schema).
- The user specifies the transport or protocol as a **pre-determined design constraint** — a
  deliberate architectural decision that is already settled, not merely a description of a
  possible implementation.

When transport detail is preserved under this carve-out, record it in the feature/stub
`## Design constraints` section (a settled HOW decision) rather than smuggling it into the
intent prose. This keeps intent transport-agnostic while preserving the constraint visibly.

## Active rewriting rule

When user input contains transport-specific language and the carve-out does not apply,
re-express before writing into the spec.

| User input (transport-specific) | Spec expression (transport-agnostic) |
|---|---|
| `GET /report?source=2024-01` | System retrieves the monthly report for the given source month |
| `POST /orders` with payload `{item, qty}` | Actor submits a new order with item and quantity; system creates the order and returns the new order ID |
| `PUBLISH orders.created` | System notifies downstream of the new order (async — ordering guarantee is a business requirement) |
| `SELECT * FROM reports WHERE month = ?` | System retrieves all reports for the given month |
| `gRPC ReportService.GetMonthly` | System retrieves the monthly report from the Report Service |

**Substance survives the rewrite.** Strip the transport form but keep every concrete detail:

| User input (transport form + substance) | Spec expression (form stripped, substance kept) |
|---|---|
| `POST /upload` a CSV with columns `date,source,amount` (amount in cents, header row required) | Actor uploads a report file; the file is CSV with columns date, source, amount — amount in cents, header row required. (Record the input format under `## Requirement details` or the use-case `## Data and contracts → Inputs`.) |
| `GET /export.xlsx` returning sheets `Summary`, `Detail` | Actor exports the report; output is an XLSX workbook with a Summary sheet and a Detail sheet. (Output format is substance — preserve it.) |
