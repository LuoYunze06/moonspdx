# Changelog

## Unreleased — ROBDD maintenance

- Index unique nodes and apply/complement/restriction caches with exact keyed maps; normalize commutative apply keys and reduce terminal operations.
- Add eight test groups for six-atom exhaustive proof/witness/influence checks, table isolation and budget boundaries (49 total).
- Retain 12 baseline/optimized CLI workloads and wire counter/output verification into CI.
- Successful semantic results and the public API are preserved; numeric work/node counters and exact budget cutoffs change. No package version has been published for these changes.


## 0.3.0 - 2026-08-25

- Bound every ROBDD compilation by configurable variable, decision-node, and
  operation budgets with stable diagnostics for each exhausted resource.
- Change semantic summary, proof, comparison, and influence APIs to return
  `Result`, preventing complex input from bypassing resource failures.
- Expose deterministic operation counts beside decision-node counts in text and
  JSON results.
- Add CLI budget flags: `--max-variables`, `--max-nodes`, and
  `--max-operations`.
- Add exhaustive AST-vs-ROBDD oracle tests over pairwise three-atom formulas and
  verify that returned equivalence witnesses have globally minimum true count.
- Expand negative tests for invalid limits and each resource-exhaustion path.
- Reject more than 64 nested parentheses before recursive parsing.
- Reject unknown, duplicate, missing-value, and stray CLI arguments through
  per-command option schemas.

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
