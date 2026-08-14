# Contributing

Open an issue before changing the supported SPDX profile or obligation model.
Changes must include focused positive, negative, and boundary tests; stable
diagnostic codes; documentation of support boundaries; and compatible source
attribution.

Run before submitting:

```bash
moon fmt --check
moon check --target wasm-gc --deny-warn
moon check --target wasm --deny-warn
moon check --target js --deny-warn
moon check --target native --deny-warn
moon test --target wasm-gc
moon test --target wasm
moon test --target js
```

Do not add legal conclusions, unknown-source license metadata, secrets, or
generated padding intended only to increase line count.
