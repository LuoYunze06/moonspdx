# Changelog

## 0.2.0 - 2026-08-17

- Redesign the project around formal SPDX expression semantics after the v0.1
  license-audit workflow was rejected for overlap with maintained projects.
- Add a canonical ROBDD engine with memoized Boolean operations.
- Prove expression equivalence and implication.
- Produce deterministic minimum counterexamples and replayable models.
- Add semantic fingerprints, bounded truth tables, and named proof suites for CI.
- Add four-way semantic comparison and per-atom influence witnesses.
- Remove policy, inventory, obligation, notice, drift, remediation-adjacent, and
  catalog-matrix behavior from the current source tree.
- Replace audit examples, documentation, application evidence, and CI fixtures
  with semantic-proof acceptance flows.

## 0.1.0 - 2026-08-14

- Parse, validate, normalize, inspect, and expand bounded SPDX expressions.
- Provide a curated 44-license and 10-exception profile with obligation metadata.
- Parse deterministic policy configuration and select acceptable alternatives.
- Audit, canonicalize, query, summarize, and diff component inventories.
- Generate text/JSON reports, catalog policy matrices, and notice checklists.
- Add a portable CLI, 42 tests, multi-target checks, examples, and CI.
