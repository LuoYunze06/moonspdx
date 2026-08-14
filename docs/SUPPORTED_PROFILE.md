# Supported SPDX Profile

MoonSPDX v0.1.0 supports SPDX expression operators `AND`, `OR`, and `WITH`,
parentheses, whitespace, and the identifier characters used by the curated
catalog. Operator precedence is `WITH`, then `AND`, then `OR`.

The catalog contains 44 identifiers. Run `moonspdx catalog` for the exact list.
It includes common permissive, weak-copyleft, strong-copyleft, public-domain,
content, and source-available identifiers. Ten common SPDX exceptions are
recognized. Known exception attachment constraints are checked for Classpath,
GCC, Autoconf, Bison, Linux syscall, and LLVM exceptions.

Legacy `AGPL-3.0+`, `GPL-2.0+`, `GPL-3.0+`, `LGPL-2.0+`, `LGPL-2.1+`, and
`LGPL-3.0+` spellings normalize to explicit `-or-later` identifiers. Other plus
suffixes fail rather than guessing.

Obligation metadata is deliberately broad: notice, attribution, source
disclosure, same-license, network source offer, and patent notice. It supports
consistent automation but does not encode jurisdiction, linking mode,
modification status, distribution facts, or license compatibility.

Custom license references, complete SPDX documents, SBOM formats, license text,
copyright notices, and legal waivers are outside this release.
