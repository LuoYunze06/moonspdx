# Security Policy

MoonSPDX processes untrusted text without network or filesystem access in the
core library. It limits expression length to 4,096 characters, parenthesis
nesting to 64 levels before recursive parsing, proof suites to
128 claim records, and complete truth tables to 10 distinct atoms. Every
symbolic operation also defaults to 32 variables, 4,096 decision nodes, and
50,000 counted operations. Callers can lower or explicitly raise these budgets.

Report security issues privately through the repository owner's GitHub security
contact when the public repository is available. Do not include secrets,
private metadata, or confidential expressions in public issues.

Semantic proofs are automation signals, not legal conclusions. Consumers should
keep human review for distribution decisions and unsupported identifiers.
