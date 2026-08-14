# Architecture

MoonSPDX keeps domain behavior independent of filesystems and process APIs.

1. `parser.mbt` tokenizes SPDX text and uses precedence-aware recursive descent
   to build `Expression` values. Catalog validation happens at the atom boundary.
2. `catalog.mbt` and `catalog_stats.mbt` define the curated identifier profile,
   broad families, conservative obligations, exception names, and profile metrics.
3. `policy_parser.mbt` compiles line-oriented configuration into `Policy`.
   `policy.mbt` evaluates atoms and expression trees, considers `OR` branches
   deterministically, combines `AND` obligations, and records reasons.
4. `inventory.mbt` validates component records and audits each expression.
   `inventory_stats.mbt`, `inventory_query.mbt`, and `drift.mbt` provide
   analysis without changing the original inventory.
5. `notice.mbt` turns a fully accepted audit into explicit component actions.
   It refuses rejected or review-state reports so a checklist cannot hide policy debt.
6. `report.mbt` and domain-specific exporters produce stable text and compact
   JSON without requiring a JSON runtime dependency.
7. `command.mbt` is a pure argument-to-result facade. `cmd/main` only adapts
   environment arguments, stdout, and process exit status.

All safety limits are checked before combinatorial work. Expression expansion
is capped at 64 alternatives, source expressions at 4,096 characters, and
inventories at 512 component lines. Diagnostics expose stable codes separately
from human-readable context.
