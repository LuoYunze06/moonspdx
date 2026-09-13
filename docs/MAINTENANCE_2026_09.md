# ROBDD maintenance evidence — 2026-09-13

## Existing foundation and contribution

MoonSPDX already provided SPDX parsing, canonical ROBDD proofs, minimum witnesses,
influence analysis, budgets and CLI gates. This maintenance is by
`2200732518gjy` on `LuoYunze06/moonspdx`, tracked in issue #1. It does not claim
authorship of those existing features or expand the supported license catalog.

The change replaces four linear lookup paths (unique node, apply, complement,
restriction) with exact keyed maps. Apply keys normalize commutative operands;
terminal identities avoid unnecessary recursion. Maps are local to one manager,
outputs never depend on map iteration, and exhausted computations are not cached.

## Measured comparison

Baseline: `b47f5c2ffb4256f837f3d7355d71330676b64a25`.
Optimized semantic implementation: `10001b176c6b5b066a7c043c2a0ae9a299c5dec9`.
Environment: Windows, moon 0.1.20260904 / moonc 0.10.12 (2026-09-07), JS release;
Node version and three-run process medians are retained in the JSON files.
All expressions are synthetic and included verbatim; no external corpus was copied.

| Same input workload | Baseline work units | Optimized work units |
| --- | ---: | ---: |
| 4-atom conjunction, reversed operands | 582 | 78 |
| 8-atom conjunction, reversed operands | 4,975 | 248 |
| 12-atom conjunction, reversed operands | 18,668 | 498 |
| 12-atom disjunction, reversed operands | 18,668 | 498 |
| Conjunction of six 2-atom disjunctions | 11,981 | 354 |
| 40 repeated subexpressions | 833 | 452 |
| Distributivity | 275 | 62 |
| Negative equivalence with witness | 91 | 37 |

The twelve-atom conjunction shows **97.33% fewer counted work units**. This is
not a wall-clock speedup: the old counter includes each linear-scan entry, while
the new counter includes a logical map lookup, not internal hash probes. Default
limits are unchanged. With an explicit 1,000-unit budget, the original executable
returns exit 2 / `semantic.operation.limit`; the optimized executable returns
exit 0 / holds=true. Both executables were actually run for this comparison.

All 12 workloads preserve exit codes and every proof JSON field except the
intentionally implementation-dependent `operations` and `decision_nodes` fields.
The raw files also retain process medians (including Node startup); they are not
used to claim a cross-engine or in-process performance advantage.

- [Original measurements](benchmarks/baseline.json)
- [Optimized measurements](benchmarks/optimized.json)
- [Same-budget comparison](benchmarks/budget-comparison.json)

## Correctness rather than timing alone

The baseline has 41 MoonBit test groups. Eight new groups bring the total to 49:

1. A 24-formula generated corpus, using six known atoms including `WITH`, checks
   all 576 ordered pairs under all 64 assignments. This is 36,864 assignment
   cases and 1,152 symbolic proofs (equivalence and implication per pair).
2. Direct AST enumeration independently checks both proof decisions and the
   globally minimum true-atom count of each returned counterexample. Witnesses
   are replayed against the input ASTs; the oracle does not use BDD internals.
3. Exhaustive atom flips check influence relevance and replay its contexts.
4. Focused internal regressions check unique-node reuse, commutative-cache reuse,
   operator separation, complement involution, distinct cofactor keys, sticky
   failure, fresh-manager isolation and exact operation-budget boundaries.
5. The twelve-atom reverse conjunction is a bounded-work regression.

The independent truth-table oracle is the correctness comparator here. There
is no claim of a performance win over CUDD, PyEDA, or a SAT solver: no such
head-to-head benchmark was run. Enumeration is deliberately small and complete;
12-atom workloads exercise symbolic work beyond the public 10-atom table API.
This corpus is a regression check, not a proof of correctness for every input.

## Reproduce

From either source revision, build the CLI. To measure the baseline, use a
separate checkout at the baseline SHA and run the current benchmark script
against that checkout's built CLI; do not overwrite a working checkout.

```bash
moon build cmd/main --target js --release
python3 scripts/bench_semantics.py --cli _build/js/release/build/cmd/main/main.js --output measurement.json --revision SOURCE_SHA
python3 scripts/verify_benchmarks.py --cli _build/js/release/build/cmd/main/main.js
moon fmt --check
moon check --target js --deny-warn
moon test --target js
```

CI additionally checks/tests wasm-gc, wasm and native, and compares real CLI
fixtures. Native execution is performed in Ubuntu CI, not claimed on the Windows
workstation. Formatter normalization and regenerated interface trailing-newline
changes contain no public API additions/removals. The package remains 0.3.0;
this source maintenance does not overwrite or republish a MoonCakes version.
