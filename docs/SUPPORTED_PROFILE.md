# Supported Profile

MoonSPDX accepts SPDX-style expressions containing catalog identifiers,
`AND`, `OR`, `WITH`, and parentheses. `AND` binds more tightly than `OR`.
`WITH` attaches only to a single license identifier. Documented legacy `+`
forms normalize to explicit `-or-later` identifiers.

The bundled profile contains 44 common license identifiers and 10 exception
identifiers. Unknown identifiers are rejected instead of guessed.

## Boolean interpretation

Each plain license or `license WITH exception` form is an independent Boolean
atom. `AND` and `OR` use ordinary propositional semantics. This model can prove
that two expression trees select the same sets of atoms or that one formula
implies another. It does not claim that licenses are legally compatible.

Supported semantic operations:

- canonical ROBDD fingerprints;
- equivalence and implication proofs;
- four-way narrower/broader/equal/incomparable comparison;
- per-atom influence and redundant-atom witnesses;
- minimum satisfying models and failed-proof counterexamples;
- complete truth tables for up to 10 atoms;
- named batch claims for CI regression gates;
- deterministic text and JSON output.

Unsupported:

- `LicenseRef-*` and `DocumentRef-*`;
- SPDX JSON, YAML, RDF, tag-value, or SBOM documents;
- repository, manifest, dependency, source-header, or license-text scanning;
- allow/deny policy, obligations, compatibility, remediation, and legal advice;
- CycloneDX, SARIF, in-toto/SLSA provenance, package discovery, and publishing.
