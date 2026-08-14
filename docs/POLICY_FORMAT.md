# Policy Format

Policies use one `key=value` rule per line. Blank lines and lines starting with
`#` are ignored. Keys cannot repeat.

```text
require-osi=true
allow=MIT,Apache-2.0,BSD-3-Clause
deny=GPL-3.0-only,BUSL-1.1
prefer=Apache-2.0,MIT
require-obligations=preserve-notices
```

- `require-osi`: `true` places non-OSI catalog entries into review.
- `allow`: when non-empty, all atoms must appear in the allow-list.
- `deny`: rejects matching atoms and overrides preference.
- `prefer`: ranks otherwise acceptable `OR` alternatives from left to right.
- `require-obligations`: places choices missing named obligations into review.

Supported obligation names are `preserve-notices`, `preserve-attribution`,
`disclose-source`, `same-license`, `network-source-offer`, and `patent-notice`.
Allow/deny conflicts, denied preferences, unknown identifiers, and unknown
obligations are configuration errors.
