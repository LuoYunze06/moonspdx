# Local Readiness Audit

Date: 2026-08-17

## Environment

- MoonBit: `moon 0.1.20260713 (75c7e1f 2026-07-13)`
- Git: `2.45.1.windows.1`
- Python: `3.8.5`; the UTF-8 submission validator passes in strict mode
- GitHub CLI: `2.96.0`; remote operations use a command-local token for `LuoYunze06`
- Native compiler: unavailable locally (`cl`, `cc`, `gcc`, and `clang` absent)

## Redesign and non-duplication

The v0.1 audit workflow was rejected for overlap with
`clbbbb/moonbit-license-audit` and `liyun/moonseal`. Their fingerprints are now
permanently registered in the hackathon Skill. The current v0.2 tree removes
policy, inventory, obligation, drift, notice, and matrix modules. It does not
scan repositories, audit release readiness, produce SBOM/SARIF/provenance, or
recommend remediation.

The new core loop compiles expression ASTs into canonical ROBDDs, proves
equivalence or implication, classifies pair relationships, analyzes atom
influence, and emits minimum replayable counterexamples. This differs from the
two prior projects in core data, algorithm, output, and acceptance workflow.

## Local evidence

- MoonBit files: 15; 2,997 physical lines and 2,548 effective lines under the
  local nonblank/non-doc-comment counter. The competition range is guidance;
  no generated padding was added after removing overlapping behavior.
- `moon fmt --check`: passed.
- strict `moon check` for wasm-gc, wasm, JavaScript, and native: passed.
- 30 tests pass on wasm-gc, wasm, and JavaScript locally.
- Native tests and native executable build require the GitHub Actions Ubuntu C
  compiler and are not claimed as local results.
- JavaScript demo, inspect, proof-suite, and expected failed-proof fixtures
  match after line-ending normalization; the failed proof exits with code 1.
- GitHub Actions YAML parses with `portable` and `native` jobs.
- Application validator: strict pass, 26 lines, no placeholders.

## Authorship and publication boundary

Repository-local identity is `LuoYunze06
<238675390+LuoYunze06@users.noreply.github.com>`. Both new redesign commits use
that identity as author and committer. All redesign commits are checked the
same way. The application and participant contact
remain outside Git. No mooncakes.io command or publication is in scope.

Remote CI, release, SHA alignment, and public contributor mapping are checked
after the final documentation commit is pushed.
