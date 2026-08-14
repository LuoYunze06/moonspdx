///|
pub struct CatalogStats {
  licenses : Int
  osi_approved : Int
  non_osi : Int
  permissive : Int
  weak_copyleft : Int
  strong_copyleft : Int
  public_domain : Int
  other : Int
  notice_required : Int
  source_required : Int
  network_source_required : Int
  patent_notice_required : Int
  exceptions : Int
} derive(Eq, @debug.Debug)

///|
pub fn CatalogStats::licenses(self : CatalogStats) -> Int {
  self.licenses
}

///|
pub fn CatalogStats::osi_approved(self : CatalogStats) -> Int {
  self.osi_approved
}

///|
pub fn CatalogStats::non_osi(self : CatalogStats) -> Int {
  self.non_osi
}

///|
pub fn CatalogStats::permissive(self : CatalogStats) -> Int {
  self.permissive
}

///|
pub fn CatalogStats::weak_copyleft(self : CatalogStats) -> Int {
  self.weak_copyleft
}

///|
pub fn CatalogStats::strong_copyleft(self : CatalogStats) -> Int {
  self.strong_copyleft
}

///|
pub fn CatalogStats::exceptions(self : CatalogStats) -> Int {
  self.exceptions
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
/// Summarize the exact curated interoperability profile shipped by MoonSPDX.
pub fn catalog_stats() -> CatalogStats {
  let mut osi_approved = 0
  let mut non_osi = 0
  let mut permissive_count = 0
  let mut weak_copyleft_count = 0
  let mut strong_copyleft_count = 0
  let mut public_domain_count = 0
  let mut other_count = 0
  let mut notice_required = 0
  let mut source_required = 0
  let mut network_source_required = 0
  let mut patent_notice_required = 0
  let ids = known_license_ids()
  for id in ids {
    let info = lookup_license(id).unwrap()
    if info.is_osi_approved() {
      osi_approved = osi_approved + 1
    } else {
      non_osi = non_osi + 1
    }
    match info.family() {
      Permissive => permissive_count = permissive_count + 1
      WeakCopyleft => weak_copyleft_count = weak_copyleft_count + 1
      StrongCopyleft => strong_copyleft_count = strong_copyleft_count + 1
      PublicDomain => public_domain_count = public_domain_count + 1
      Other => other_count = other_count + 1
    }
    let obligations = info.obligations()
    if obligations.requires_notice() {
      notice_required = notice_required + 1
    }
    if obligations.requires_source_disclosure() {
      source_required = source_required + 1
    }
    if obligations.requires_network_source() {
      network_source_required = network_source_required + 1
    }
    if obligations.requires_patent_notice() {
      patent_notice_required = patent_notice_required + 1
    }
  }
  {
    licenses: ids.length(),
    osi_approved,
    non_osi,
    permissive: permissive_count,
    weak_copyleft: weak_copyleft_count,
    strong_copyleft: strong_copyleft_count,
    public_domain: public_domain_count,
    other: other_count,
    notice_required,
    source_required,
    network_source_required,
    patent_notice_required,
    exceptions: known_exception_ids().length(),
  }
}

///|
pub fn CatalogStats::to_text(self : CatalogStats) -> String {
  "CATALOG licenses=" +
  self.licenses.to_string() +
  " exceptions=" +
  self.exceptions.to_string() +
  " osi=" +
  self.osi_approved.to_string() +
  " non_osi=" +
  self.non_osi.to_string() +
  " permissive=" +
  self.permissive.to_string() +
  " weak_copyleft=" +
  self.weak_copyleft.to_string() +
  " strong_copyleft=" +
  self.strong_copyleft.to_string() +
  " public_domain=" +
  self.public_domain.to_string() +
  " other=" +
  self.other.to_string() +
  " notice=" +
  self.notice_required.to_string() +
  " source=" +
  self.source_required.to_string() +
  " network_source=" +
  self.network_source_required.to_string() +
  " patent_notice=" +
  self.patent_notice_required.to_string()
}

///|
pub fn CatalogStats::to_json(self : CatalogStats) -> String {
  "{" +
  "\"licenses\":" +
  self.licenses.to_string() +
  ",\"exceptions\":" +
  self.exceptions.to_string() +
  ",\"osi_approved\":" +
  self.osi_approved.to_string() +
  ",\"non_osi\":" +
  self.non_osi.to_string() +
  ",\"families\":{\"permissive\":" +
  self.permissive.to_string() +
  ",\"weak_copyleft\":" +
  self.weak_copyleft.to_string() +
  ",\"strong_copyleft\":" +
  self.strong_copyleft.to_string() +
  ",\"public_domain\":" +
  self.public_domain.to_string() +
  ",\"other\":" +
  self.other.to_string() +
  "},\"obligation_coverage\":{\"notice\":" +
  self.notice_required.to_string() +
  ",\"source\":" +
  self.source_required.to_string() +
  ",\"network_source\":" +
  self.network_source_required.to_string() +
  ",\"patent_notice\":" +
  self.patent_notice_required.to_string() +
  "}}"
}
