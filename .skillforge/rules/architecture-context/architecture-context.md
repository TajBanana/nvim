You are working for AIR Lab, a research lab that leverage advanced and open innovation to create the next generation of ATM (Air Traffic Management) technologies.

This is our definition of system architecture terms that you should follow when writing technical documents:

- System: Encompasses everything needed to deliver a business capability end-to-end. It includes all subsystems, shared infrastructure, data stores, and external integrations. In AIR Lab, the main system is RCP (Regional Collaboration Platform).
- Sub-system: A bounded domain or capability cluster within the system. Groups microservices that share a cohesive business concern. A subsystem often maps to a bounded context in Domain-Driven Design and may have its own team ownership. Examples: TBO (Trajectory Based Operations), Live ASD (Air Situation Display).
- Application: A single microservice or a small set of tightly related services that is part of a sub-system. Examples: TBO Airline UI, RCP ASD (Air Situation Display).
- Service: A single deployable unit that exposes functionality over a network interface (HTTP, Kafka, etc.). It owns its data, has a single responsibility, and is independently deployable.
- Assembly: A logical grouping of services that are released or orchestrated as a unit. It can be a complete sub-system, an application or just part of one. In AIR Lab, assemblies are usually either Helm Charts or Helmfiles.
- Component: An internal, non-deployable unit within a service. A class, module, or package that encapsulates a specific concern. It is not independently deployable — it only exists within the service's process.

These are the two kinds of decision record we use to document significant decisions. Pick the tier by the scope the decision governs:

- ADR (Architecture Decision Record): Captures a system-wide or sub-system-wide architectural decision — one that is costly to reverse, spans multiple sub-systems or services, or constrains how the platform evolves. ADRs require consultation with and sign-off from architects before they are accepted. Reserve ADRs for these highest-impact, system-level decisions.
- DDR (Design Decision Record): Captures a component-, service-, or application-level design decision made during implementation — a storage model, a library choice, an internal pattern, or a contract shape scoped to a single service or sub-system. DDRs are authored by the implementing engineer as the work happens and do not need architect sign-off. They are the default record for decisions that are significant but local; escalate to an ADR when a decision turns out to be system-wide.

# RCP (Regional Collaborative Platform) System Architecture

RCP consists of a set of evovling sub-systems. This system was previously named REP (Regional Experimental Platform) and some of the legacy sub-systems uses this name.

REST over HTTP and Kafka are the default communication protocols used between sub-systems in RCP.

AVRO is the default serialization format for Kafka record values. AVRO schemas are registered in an Apicurio schema registry. The actual record value is a proprietary byte array with contents in this sequence: magic number, schema global id, actual data in AVRO.

- Magic number is 4 bytes: 0x41, 0x56, 0x52, 0x58
- Schema global id is a 64-bit long encoded in big endian and can be directly used to look up the schema in Apicurio schema registry

Open ATMS (OATMS) is the data model used for communication between sub-systems. When necessary, call `skillforge-repos resolve-artifact-source --type maven --coord com.thales.ams:oatms-models:<version>` (or whichever artifact type matches your build's reference) to obtain a read-only worktree of the matching version, and read the model definitions from the printed worktree path. If the artifact is not yet registered, add the producing repo to `references/repos.yaml` and retry.
