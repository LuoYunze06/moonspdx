///|
fn permissive(
  id : String,
  osi? : Bool = true,
  patent? : Bool = false,
) -> LicenseInfo {
  {
    id,
    family: Permissive,
    osi_approved: osi,
    deprecated: false,
    obligations: Obligations::make(
      notice=true,
      attribution=true,
      patent_notice=patent,
    ),
  }
}

///|
fn public_domain(id : String) -> LicenseInfo {
  {
    id,
    family: PublicDomain,
    osi_approved: true,
    deprecated: false,
    obligations: Obligations::none(),
  }
}

///|
fn weak_copyleft(id : String, osi? : Bool = true) -> LicenseInfo {
  {
    id,
    family: WeakCopyleft,
    osi_approved: osi,
    deprecated: false,
    obligations: Obligations::make(
      notice=true,
      attribution=true,
      source_disclosure=true,
      same_license=true,
    ),
  }
}

///|
fn strong_copyleft(
  id : String,
  network? : Bool = false,
  osi? : Bool = true,
) -> LicenseInfo {
  {
    id,
    family: StrongCopyleft,
    osi_approved: osi,
    deprecated: false,
    obligations: Obligations::make(
      notice=true,
      attribution=true,
      source_disclosure=true,
      same_license=true,
      network_source=network,
    ),
  }
}

///|
fn other_license(id : String, osi? : Bool = false) -> LicenseInfo {
  {
    id,
    family: Other,
    osi_approved: osi,
    deprecated: false,
    obligations: Obligations::make(notice=true, attribution=true),
  }
}

///|
/// Look up the curated SPDX identifier profile supported by MoonSPDX v0.1.0.
pub fn lookup_license(id : String) -> LicenseInfo? {
  match id {
    "0BSD" => Some(permissive(id))
    "AFL-3.0" => Some(permissive(id))
    "Apache-2.0" => Some(permissive(id, patent=true))
    "Artistic-2.0" => Some(permissive(id))
    "BSD-2-Clause" => Some(permissive(id))
    "BSD-3-Clause" => Some(permissive(id))
    "BSD-3-Clause-Clear" => Some(permissive(id))
    "BSL-1.0" => Some(permissive(id))
    "CC0-1.0" => Some(public_domain(id))
    "CDDL-1.0" => Some(weak_copyleft(id))
    "CDDL-1.1" => Some(weak_copyleft(id))
    "ECL-2.0" => Some(permissive(id, patent=true))
    "EPL-1.0" => Some(weak_copyleft(id))
    "EPL-2.0" => Some(weak_copyleft(id))
    "EUPL-1.1" => Some(strong_copyleft(id))
    "EUPL-1.2" => Some(strong_copyleft(id))
    "GPL-2.0-only" => Some(strong_copyleft(id))
    "GPL-2.0-or-later" => Some(strong_copyleft(id))
    "GPL-3.0-only" => Some(strong_copyleft(id))
    "GPL-3.0-or-later" => Some(strong_copyleft(id))
    "ISC" => Some(permissive(id))
    "LGPL-2.0-only" => Some(weak_copyleft(id))
    "LGPL-2.0-or-later" => Some(weak_copyleft(id))
    "LGPL-2.1-only" => Some(weak_copyleft(id))
    "LGPL-2.1-or-later" => Some(weak_copyleft(id))
    "LGPL-3.0-only" => Some(weak_copyleft(id))
    "LGPL-3.0-or-later" => Some(weak_copyleft(id))
    "MIT" => Some(permissive(id))
    "MIT-0" => Some(permissive(id))
    "MPL-2.0" => Some(weak_copyleft(id))
    "MS-PL" => Some(permissive(id))
    "NCSA" => Some(permissive(id))
    "OFL-1.1" => Some(other_license(id, osi=true))
    "PostgreSQL" => Some(permissive(id))
    "Python-2.0" => Some(permissive(id))
    "Unlicense" => Some(public_domain(id))
    "UPL-1.0" => Some(permissive(id, patent=true))
    "Zlib" => Some(permissive(id))
    "AGPL-3.0-only" => Some(strong_copyleft(id, network=true))
    "AGPL-3.0-or-later" => Some(strong_copyleft(id, network=true))
    "BlueOak-1.0.0" => Some(permissive(id, osi=false, patent=true))
    "BUSL-1.1" => Some(other_license(id))
    "CC-BY-4.0" => Some(other_license(id))
    "CC-BY-SA-4.0" => Some(strong_copyleft(id, osi=false))
    _ => None
  }
}

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
pub fn is_known_exception(id : String) -> Bool {
  match id {
    "Autoconf-exception-2.0"
    | "Autoconf-exception-3.0"
    | "Bison-exception-2.2"
    | "Classpath-exception-2.0"
    | "Font-exception-2.0"
    | "GCC-exception-2.0"
    | "GCC-exception-3.1"
    | "LLVM-exception"
    | "Linux-syscall-note"
    | "OpenJDK-assembly-exception-1.0" => true
    _ => false
  }
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
