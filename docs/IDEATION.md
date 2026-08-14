# Direction and Non-Duplication Record

Date: 2026-08-14

## Candidate comparison

| Candidate | Domain and core loop | Registry comparison | Decision |
| --- | --- | --- | --- |
| MoonSPDX | SPDX expressions and component inventories -> policy decisions and obligations | No registered project uses license expressions, dependency license inventories, policy choices, or compliance obligations as core data or output | Selected: useful offline workflow, deterministic acceptance, and strong reusable-library scope |
| MoonState | Protocol state machines and event traces -> conformance and reachability reports | Different from the registry at the user-workflow level, but graph traversal and reachability create avoidable implementation overlap with MoonDag | Not selected |
| MoonCache | HTTP cache directives and request/response metadata -> freshness and revalidation decisions | Different from MoonContract because it does not use OpenAPI or validate API schemas, but shares HTTP interaction data and has narrower initial scope | Not selected |

MoonLex was screened out before candidacy because `moonbitlang/moonlex` is an
existing mature MoonBit project. An IPv4/CIDR policy analyzer was also screened
out after finding an existing MoonBit implementation.

## Selected fingerprint

- Problem domain: software license expression and dependency policy auditing.
- Primary users: package authors, release engineers, open-source program
  offices, and CI maintainers.
- Primary workflow: parse expressions and inventory, validate identifiers,
  normalize, evaluate policy, select acceptable alternatives, aggregate
  obligations, and report.
- Core data: SPDX identifiers and exceptions, expression trees, components,
  policies, decisions, obligations, and diagnostics.
- Central algorithms: precedence-aware parsing, canonical rendering,
  expression evaluation, deterministic OR-branch selection, rule matching,
  and obligation aggregation.
- Outputs: normalized expressions, decisions, selected alternatives,
  obligation summaries, reports, diagnostics, and process status.
- Acceptance demonstration: compound expression normalization, deterministic
  choice under policy, multi-component audit, obligation aggregation, and
  stable failures for malformed or unsupported inputs.
- Explicit non-goals: legal advice, license-text comparison, cryptographic
  SBOM verification, network package discovery, vulnerability scanning, and
  package publication.

## Support boundary

Supported in v0.1.0: SPDX 2.x expression operators (`AND`, `OR`, `WITH`), a
documented curated identifier catalog, deterministic policy evaluation,
line-oriented component inventories, obligation aggregation, library APIs, and
a CLI.

Partially supported: deprecated SPDX `+` suffixes are parsed and normalized to
their explicit `-or-later` identifiers when a documented mapping exists.

Unsupported: custom `LicenseRef-*` identifiers, SPDX JSON/tag-value documents,
full SBOM formats, license compatibility proofs, and legal conclusions.

## Acceptance flows

1. Normalize a nested SPDX expression while preserving operator semantics.
2. Evaluate an `OR` expression and choose the first deterministic policy-safe
   alternative.
3. Audit a multi-component inventory and aggregate notice, attribution, and
   source-disclosure obligations.
4. Reject an unknown license, malformed parentheses, invalid `WITH` use, a
   duplicate component, and an invalid policy rule with stable diagnostics.
5. Run the same library tests on wasm-gc, wasm, JavaScript, and native CI; run
   real CLI examples on JavaScript locally and native in CI.

## Licensing and dependencies

MoonSPDX uses the OSI-approved Apache License 2.0. The core has no third-party
runtime dependency. SPDX names and semantics are factual interoperability
references; attribution and links will be recorded in `THIRD_PARTY.md`.
