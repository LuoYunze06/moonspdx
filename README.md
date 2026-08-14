# MoonSPDX

MoonSPDX is a deterministic SPDX license expression and dependency-license
policy toolkit written in MoonBit. It parses and normalizes expressions,
selects compliant `OR` branches, audits component inventories, aggregates
obligations, detects inventory drift, generates notice checklists, and exposes
the same behavior through a portable CLI.

MoonSPDX is an engineering aid, not legal advice. Its v0.1.0 catalog is a
documented profile of 44 common SPDX identifiers and 10 exceptions rather than
the complete SPDX License List.

## Scope

Supported:

- SPDX 2.x `AND`, `OR`, `WITH`, parentheses, and documented legacy `+` mappings
- stable diagnostics for syntax, identifiers, exceptions, policies, and inventories
- line-oriented `key=value` policies with OSI, allow, deny, preference, and obligation rules
- deterministic policy selection, text/JSON reports, and exit codes
- component inventory audits, statistics, queries, canonicalization, and baseline drift
- catalog-wide policy matrices and mechanical notice-action checklists
- 64-alternative safety bound and 512-component inventory bound

Partial:

- the curated identifier profile covers common open-source and source-available licenses
- obligations are conservative metadata for automation, not compatibility judgments
- legacy `+` syntax is accepted only where an explicit `-or-later` mapping exists

Unsupported:

- `LicenseRef-*`, `DocumentRef-*`, SPDX JSON/tag-value documents, and full SBOM formats
- license-text comparison, cryptographic SBOM verification, vulnerability scanning, and package discovery
- legal conclusions, license compatibility proofs, waivers, or package publication

See [the supported profile](docs/SUPPORTED_PROFILE.md) for the exact boundary.

## Quick Start

```bash
moon update
moon test --target wasm-gc
moon run cmd/main --target js -- demo
```

Normalize an expression:

```bash
moon run cmd/main --target js -- normalize --expression '(MIT OR Apache-2.0) AND BSD-3-Clause'
```

Audit an escaped multiline inventory against a policy:

```bash
moon run cmd/main --target js -- audit \
  --inventory 'app|1.0|MIT\nengine|2.0|GPL-3.0-only OR Apache-2.0' \
  --policy 'require-osi=true\ndeny=GPL-3.0-only\nprefer=Apache-2.0,MIT'
```

On PowerShell, use single quotes as shown. CLI text options decode `\n`, `\r`,
`\t`, and `\\`.

## CLI

```text
moonspdx normalize --expression TEXT
moonspdx inspect --expression TEXT
moonspdx evaluate --expression TEXT [--policy TEXT] [--json]
moonspdx audit --inventory TEXT [--policy TEXT] [--json]
moonspdx diff --before TEXT --after TEXT [--json]
moonspdx matrix [--policy TEXT] [--json]
moonspdx summary --inventory TEXT [--json]
moonspdx notices --inventory TEXT [--policy TEXT] [--json]
moonspdx query --inventory TEXT --license ID [--json]
moonspdx canonical-inventory --inventory TEXT
moonspdx catalog
moonspdx demo
```

Exit `0` means accepted/success, `1` means policy rejection or unresolved
review, and `2` means invalid input or usage.

## Library API

```moonbit
let expression = @moonspdx.parse_expression("MIT OR Apache-2.0").unwrap()
let policy = @moonspdx.parse_policy(
  "require-osi=true\nprefer=Apache-2.0,MIT",
).unwrap()
let decision = @moonspdx.evaluate(expression, policy)

let report = @moonspdx.audit_inventory(
  "app|1.0|MIT\nengine|2.0|Apache-2.0",
  policy,
).unwrap()
let checklist = @moonspdx.notice_plan(report).unwrap()
```

The generated public interface is in `pkg.generated.mbti`.

## Examples

`examples/` contains real inventory/policy inputs and checked CLI output. Run:

```bash
moon run cmd/main --target js -- demo
moon run cmd/main --target js -- inspect --expression '(MIT OR Apache-2.0) AND BSD-3-Clause'
moon run cmd/main --target js -- audit --inventory 'app|1.0|MIT\nengine|2.0|GPL-3.0-only OR Apache-2.0' --policy 'require-osi=true\ndeny=GPL-3.0-only\nprefer=Apache-2.0,MIT'
```

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

GitHub Actions repeats these checks on a clean Ubuntu runner and compares the
CLI output with files under `examples/`.

## License

Apache-2.0. See `LICENSE`. SPDX names and factual metadata are attributed in
`THIRD_PARTY.md`.
