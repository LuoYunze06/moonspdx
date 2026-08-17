# Direction and Non-Duplication Record

Date: 2026-08-17

## Review trigger

MoonSPDX v0.1.0 was rejected because its license auditing overlapped
`clbbbb/moonbit-license-audit` and `liyun/moonseal`. Both projects were
inspected before selecting a redesign. Their workflows are permanently
reserved in the hackathon Skill registry.

## Candidate comparison

| Candidate | Core data and workflow | Collision analysis | Decision |
| --- | --- | --- | --- |
| License migration planner | dependency graph, replacement catalog, costs -> remediation plan | Rejected: `moonbit-license-audit` already contains remediation and release-check workflows; changing the plan format would not change the problem loop | Not selected |
| Provenance chain verifier | manifests, digests, attestations -> verify transitions and trust | Rejected: MoonSeal already generates in-toto/SLSA provenance and owns MoonBit supply-chain evidence; a verifier would still overlap provenance as central data/output | Not selected |
| SPDX semantic proof engine | Boolean expression functions -> canonical ROBDD -> equivalence/implication verdict -> minimum counterexample | Different core algorithm, data, output, and acceptance demonstration from scanning/auditing/SBOM/provenance projects | Selected |

## Selected fingerprint

- Problem domain: formal Boolean semantics and regression proofs for SPDX expressions.
- Primary users: metadata tool authors, policy-language implementers, reviewers
  of automated rewrites, and CI maintainers.
- Primary workflow: parse expressions, compile a canonical ROBDD, prove
  equivalence or implication, and extract a minimum counterexample on failure.
- Core data: expression ASTs, ordered Boolean atoms, reduced decision nodes,
  proof claims, assignments, and witnesses.
- Central algorithms: catalog-stable ordering, unique-node reduction, memoized
  Boolean apply/complement, semantic comparison, and minimum-model search.
- Outputs: proof verdicts, semantic fingerprints, models, counterexamples,
  bounded truth tables, batch-suite reports, and process status.
- Acceptance demonstration: algebraic laws, valid implications, invalid claims
  with replayable witnesses, source-order-independent fingerprints, and CI gates.
- Explicit non-goals: repository scanning, dependency inventories, allow/deny
  policy, obligation aggregation, compatibility judgment, remediation, SBOM,
  SARIF, provenance, license-text detection, vulnerability checks, and legal advice.

## Extension relationship

The two established packages remain the appropriate tools for project and
release auditing. MoonSPDX supplies a separate lower-level proof primitive they
could optionally call when validating an expression rewrite. It neither forks
their source nor reproduces their acceptance workflows. The implementation is
original and has no runtime dependency on either project.
