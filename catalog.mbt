///|
pub fn known_license_ids() -> Array[String] {
  [
    "0BSD", "AFL-3.0", "AGPL-3.0-only", "AGPL-3.0-or-later", "Apache-2.0", "Artistic-2.0",
    "BSD-2-Clause", "BSD-3-Clause", "BSD-3-Clause-Clear", "BSL-1.0", "BUSL-1.1",
    "BlueOak-1.0.0", "CC-BY-4.0", "CC-BY-SA-4.0", "CC0-1.0", "CDDL-1.0", "CDDL-1.1",
    "ECL-2.0", "EPL-1.0", "EPL-2.0", "EUPL-1.1", "EUPL-1.2", "GPL-2.0-only", "GPL-2.0-or-later",
    "GPL-3.0-only", "GPL-3.0-or-later", "ISC", "LGPL-2.0-only", "LGPL-2.0-or-later",
    "LGPL-2.1-only", "LGPL-2.1-or-later", "LGPL-3.0-only", "LGPL-3.0-or-later", "MIT",
    "MIT-0", "MPL-2.0", "MS-PL", "NCSA", "OFL-1.1", "PostgreSQL", "Python-2.0", "UPL-1.0",
    "Unlicense", "Zlib",
  ]
}

///|
pub fn known_exception_ids() -> Array[String] {
  [
    "Autoconf-exception-2.0", "Autoconf-exception-3.0", "Bison-exception-2.2", "Classpath-exception-2.0",
    "Font-exception-2.0", "GCC-exception-2.0", "GCC-exception-3.1", "LLVM-exception",
    "Linux-syscall-note", "OpenJDK-assembly-exception-1.0",
  ]
}

///|
fn is_known_license(id : String) -> Bool {
  known_license_ids().any(fn(value) { value == id })
}

///|
pub fn is_known_exception(id : String) -> Bool {
  known_exception_ids().any(fn(value) { value == id })
}

///|
fn plus_replacement(id : String) -> String? {
  match id {
    "AGPL-3.0" => Some("AGPL-3.0-or-later")
    "GPL-2.0" => Some("GPL-2.0-or-later")
    "GPL-3.0" => Some("GPL-3.0-or-later")
    "LGPL-2.0" => Some("LGPL-2.0-or-later")
    "LGPL-2.1" => Some("LGPL-2.1-or-later")
    "LGPL-3.0" => Some("LGPL-3.0-or-later")
    _ => None
  }
}

///|
fn normalize_identifier(id : String) -> Result[String, Diagnostic] {
  if id.has_suffix("+") {
    let base = id[:id.length() - 1].to_owned()
    match plus_replacement(base) {
      Some(value) => Ok(value)
      None =>
        Err(
          Diagnostic::new(
            "expression.plus.unsupported", "license", "legacy plus suffix has no supported explicit replacement",
            "an explicit SPDX -or-later identifier", id,
          ),
        )
    }
  } else {
    Ok(id)
  }
}
