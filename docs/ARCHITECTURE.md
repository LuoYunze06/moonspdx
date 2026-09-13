# Architecture

MoonSPDX separates SPDX syntax from formal semantics and process adaptation.

1. `parser.mbt` tokenizes the supported SPDX expression profile and builds an
   `Expression` tree using precedence-aware recursive descent.
2. `catalog.mbt` supplies a bounded set of valid atom names and a deterministic
   catalog order. It contains no compliance classification or obligations.
3. `semantic.mbt` collects atoms, builds a shared reduced ordered binary
   decision diagram, and evaluates equivalence and implication claims.
4. `suite.mbt` parses named proof claims and aggregates individual proofs into
   a deterministic regression gate.
5. `command.mbt` is a pure argument-to-result facade. `cmd/main` only adapts
   process arguments, stdout, and exit status.

## Decision representation

Decision IDs `0` and `1` represent false and true. Every other node stores an
ordered variable index plus low and high successors. `make_node` eliminates
nodes whose branches are equal and reuses an existing identical triple. With a
stable variable order, the resulting ROBDD is canonical for a Boolean function.
An exact `(variable, low, high)` hash map indexes the node array; node IDs still
follow deterministic insertion order. No result is constructed by iterating maps.
Hash collisions are resolved by key equality, not treated as node equivalence.

`apply_decisions` recursively applies `AND`, `OR`, or `XOR` to two diagrams and
memoizes `(operation, min(left, right), max(left, right))` keys in a manager-local
hash map. All three operations commute. Terminal identities avoid descending
into an unchanged diagram. Complement uses a source-ID map; restriction uses
`(source, variable, value)` keys, so false/true cofactors cannot alias.
Equivalence fails when `left XOR right` is satisfiable. Implication fails when
`premise AND NOT conclusion` is satisfiable.

Bidirectional implication produces the four-way comparison relation. Influence
analysis restricts each atom to false and true, compares the two cofactors, and
uses their XOR to derive a context in which a relevant atom changes the result.

## Resource budgets

Every manager records distinct variables, allocated decision nodes, and counted
work. Counted work includes recursive compile/apply/complement/restriction calls
plus one logical operation per unique/memo-map lookup. Since the September 2026
maintenance, a hash lookup replaces an array scan; the counter does NOT count
runtime hash collision probes, allocation, rendering, parser work, or elapsed
time. It is an implementation-specific symbolic-work budget, not an instruction
or whole-program memory limit. Default limits remain 32 variables, 4,096 nodes,
and 50,000 operations. Exceeding a budget returns `semantic.variable.limit`,
`semantic.node.limit`, or `semantic.operation.limit`; partial diagrams are
never exposed as proof results. Failed computations are not memoized; the
manager stays failed and later calls use fresh managers. Table insertions are
bounded by counted recursive work; the unique table is also bounded by nodes.
Numeric counters and the exact point where an operation budget is exhausted can
change across versions, while successful proof semantics remain the same.

Public APIs return `Result`. The default entry points use
`SemanticLimits::default`; `*_with_limits` variants accept an explicit budget.

## Witnesses

A failed proof keeps the failure diagram. Dynamic cost calculation assigns a
cost of zero to a low edge and one to a high edge. Witness extraction follows
the lower-cost satisfiable branch, breaking ties toward false. The result has
the minimum number of true atoms and deterministic catalog-order rendering.
Tests replay every witness against the source AST to verify the claimed failure.

## Safety

Expressions are capped at 4,096 characters, suites at 128 claim records, and
complete truth tables at 10 atoms. The core performs no filesystem or network
access. JSON and text renderers are deterministic and expose stable diagnostics.

## Correctness oracle

The test suite evaluates a corpus of three-atom formulas under all eight truth
assignments, compares every ordered formula pair with ROBDD equivalence and
implication results, replays every witness against the source AST, and checks
that equivalence witnesses use the globally minimum number of true atoms.

The maintenance suite additionally checks 24 generated formulas over six atoms
(including a WITH atom): 576 ordered pairs x 64 assignments = 36,864 assignment
cases, with both equivalence and implication decisions and minimum witnesses
checked. Influence is checked against direct AST atom flips. See
[maintenance evidence](MAINTENANCE_2026_09.md) for the before/after protocol.
