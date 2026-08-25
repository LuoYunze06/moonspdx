# MoonSPDX

MoonSPDX is a MoonBit library and CLI for proving Boolean relationships between
SPDX license expressions. It compiles expressions into reduced ordered binary
decision diagrams (ROBDDs), proves equivalence and implication, and returns a
minimum, replayable truth assignment when a claim is false.

The project answers questions such as:

- Did a metadata rewrite preserve the exact expression semantics?
- Does every choice allowed by one expression also satisfy another expression?
- Which smallest assignment disproves an incorrect equivalence or implication?
- Is the left expression narrower, broader, equal, or incomparable?
- Which source atoms can actually influence the decision function?
- Can a set of semantic invariants be enforced as a deterministic CI gate?

Each license identifier, including an identifier with `WITH`, is treated as an
independent Boolean atom. These are formal expression semantics, not legal
compatibility or compliance conclusions.

## Why v0.2 is different

MoonSPDX v0.1.0 was a license inventory and policy auditor. It failed the
hackathon initial review because that workflow overlapped the maintained
MoonCakes projects
[`clbbbb/moonbit-license-audit`](https://github.com/clbbbb/moonbit-license-audit)
and [`liyun/moonseal`](https://github.com/liyun6666/moonseal). v0.2 is a real
redesign, not a wording change: the policy, inventory, obligation, drift,
notice, and compatibility-matrix modules were removed from the current tree.

| Project | Its central workflow | MoonSPDX v0.2 boundary |
| --- | --- | --- |
| `clbbbb/moonbit-license-audit` | Scan project evidence and inventories, apply policies and obligations, compare findings, suggest remediation | MoonSPDX does not scan files or decide compliance; it proves Boolean expression claims and produces counterexamples |
| `liyun/moonseal` | Audit MoonBit release readiness and dependencies, generate CycloneDX/SARIF/provenance outputs | MoonSPDX does not parse manifests, audit releases, generate SBOMs, detect license text, or emit provenance |

MoonSPDX can serve as a lower-level proof layer for any metadata tool that wants
to verify a rewrite, but it does not depend on or replace either auditor.

## Quick start

```bash
moon update
moon test --target wasm-gc
moon run cmd/main --target js -- demo
```

Prove distributivity across two differently written SPDX expressions:

```bash
moon run cmd/main --target js -- equivalent \
  --left 'MIT AND (Apache-2.0 OR BSD-3-Clause)' \
  --right 'MIT AND Apache-2.0 OR MIT AND BSD-3-Clause'
```

Disprove an invalid implication and receive a minimum witness:

```bash
moon run cmd/main --target js -- implies \
  --premise 'MIT' \
  --conclusion 'MIT AND Apache-2.0'
```

Output includes:

```text
COUNTEREXAMPLE Apache-2.0=false, MIT=true
```

## Semantic regression suites

A suite uses one pipe-separated claim per line:

```text
commute|equivalent|MIT OR Apache-2.0|Apache-2.0 OR MIT
distribute|equivalent|MIT AND (Apache-2.0 OR BSD-3-Clause)|MIT AND Apache-2.0 OR MIT AND BSD-3-Clause
subset|implies|MIT AND Apache-2.0|MIT
```

Run the checked example as one escaped CLI value:

```bash
moon run cmd/main --target js -- verify \
  --claims 'commute|equivalent|MIT OR Apache-2.0|Apache-2.0 OR MIT\ndistribute|equivalent|MIT AND (Apache-2.0 OR BSD-3-Clause)|MIT AND Apache-2.0 OR MIT AND BSD-3-Clause\nsubset|implies|MIT AND Apache-2.0|MIT'
```

Exit `0` means every claim was proven. Exit `1` means at least one claim was
disproven and its witness is present. Exit `2` means invalid input or usage.

## CLI

```text
moonspdx equivalent  --left TEXT --right TEXT [--json]
moonspdx implies     --premise TEXT --conclusion TEXT [--json]
moonspdx fingerprint --expression TEXT [--json]
moonspdx model       --expression TEXT [--json]
moonspdx truth-table --expression TEXT [--json]
moonspdx verify      --claims TEXT [--json]
moonspdx compare     --left TEXT --right TEXT [--json]
moonspdx influence   --expression TEXT [--json]
moonspdx normalize   --expression TEXT
moonspdx inspect     --expression TEXT
moonspdx demo
```

## Library API

```moonbit
let left = @moonspdx.parse_expression(
  "MIT AND (Apache-2.0 OR BSD-3-Clause)",
).unwrap()
let right = @moonspdx.parse_expression(
  "MIT AND Apache-2.0 OR MIT AND BSD-3-Clause",
).unwrap()
let proof = @moonspdx.prove_equivalent(left, right)
  .unwrap()
assert_true(proof.holds())

let suite = @moonspdx.verify_claims(
  "subset|implies|MIT AND Apache-2.0|MIT",
).unwrap()
assert_true(suite.all_proven())
```

The generated public interface is in `pkg.generated.mbti`.

All APIs that build a decision diagram return `Result` in v0.3. To customize
the safety budget, construct `SemanticLimits` and call the corresponding
`*_with_limits` function:

```moonbit
let limits = @moonspdx.SemanticLimits::new(16, 2048, 25000).unwrap()
let proof = @moonspdx.prove_implication_with_limits(
  left,
  right,
  limits,
).unwrap()
```

## Algorithm and limits

MoonSPDX uses catalog-stable atom ordering, a unique table, memoized Boolean
`AND`/`OR`/`XOR`, complement construction, and ROBDD reduction (`low == high`)
to produce canonical decision functions. Failed relations are represented as
`left XOR right` or `premise AND NOT conclusion`; a dynamic path search chooses
a satisfying witness with the minimum number of `true` atoms.

Bidirectional implication classifies expression pairs as equivalent,
left-narrower, left-broader, or incomparable. Cofactor comparison checks each
atom's semantic influence; relevant atoms include assignments before and after
the atom is flipped, while absorbed atoms are reported as redundant.

- Source expression limit: 4,096 characters.
- Parser nesting limit: 64 parenthesis levels.
- Claim suite limit: 128 records.
- Complete truth tables: at most 10 distinct atoms.
- Default semantic budget: 32 variables, 4,096 decision nodes, and 50,000
  counted recursive/table-probe operations per proof or compilation.
- CLI overrides: `--max-variables`, `--max-nodes`, and `--max-operations`.
- Supported input profile: 44 common SPDX identifiers and 10 exceptions.
- `LicenseRef-*`, `DocumentRef-*`, SPDX documents, and legal compatibility are unsupported.

See [architecture](docs/ARCHITECTURE.md), [support profile](docs/SUPPORTED_PROFILE.md),
and [direction record](docs/IDEATION.md).

## Verification

```bash
moon fmt --check
moon check --target wasm-gc --deny-warn
moon check --target wasm --deny-warn
moon check --target js --deny-warn
moon check --target native --deny-warn
moon test --target wasm-gc
moon test --target wasm
moon test --target js
moon test --target native
```

GitHub Actions repeats all targets and compares real JavaScript/native CLI
output with fixtures under `examples/`. Tests also exhaustively compare ROBDD
proofs against direct AST truth evaluation for a pairwise formula corpus and
verify global minimum-counterexample cardinality.

## License

Apache-2.0. See `LICENSE` and `THIRD_PARTY.md`.
