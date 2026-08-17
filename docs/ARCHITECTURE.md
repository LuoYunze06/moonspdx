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

`apply_decisions` recursively applies `AND`, `OR`, or `XOR` to two diagrams and
memoizes operand pairs. Complement is built recursively with its own memo.
Equivalence fails when `left XOR right` is satisfiable. Implication fails when
`premise AND NOT conclusion` is satisfiable.

Bidirectional implication produces the four-way comparison relation. Influence
analysis restricts each atom to false and true, compares the two cofactors, and
uses their XOR to derive a context in which a relevant atom changes the result.

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
