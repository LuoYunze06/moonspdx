///|
/// Broad policy family used for reports. It is not a legal conclusion.
pub enum LicenseFamily {
  Permissive
  WeakCopyleft
  StrongCopyleft
  PublicDomain
  Other
} derive(Eq, @debug.Debug)

///|
pub struct Obligations {
  notice : Bool
  attribution : Bool
  source_disclosure : Bool
  same_license : Bool
  network_source : Bool
  patent_notice : Bool
} derive(Eq, @debug.Debug)

///|
pub fn Obligations::none() -> Obligations {
  {
    notice: false,
    attribution: false,
    source_disclosure: false,
    same_license: false,
    network_source: false,
    patent_notice: false,
  }
}

///|
pub fn Obligations::make(
  notice? : Bool = false,
  attribution? : Bool = false,
  source_disclosure? : Bool = false,
  same_license? : Bool = false,
  network_source? : Bool = false,
  patent_notice? : Bool = false,
) -> Obligations {
  {
    notice,
    attribution,
    source_disclosure,
    same_license,
    network_source,
    patent_notice,
  }
}

///|
pub fn Obligations::combine(
  self : Obligations,
  other : Obligations,
) -> Obligations {
  {
    notice: self.notice || other.notice,
    attribution: self.attribution || other.attribution,
    source_disclosure: self.source_disclosure || other.source_disclosure,
    same_license: self.same_license || other.same_license,
    network_source: self.network_source || other.network_source,
    patent_notice: self.patent_notice || other.patent_notice,
  }
}

///|
pub fn Obligations::is_empty(self : Obligations) -> Bool {
  !self.notice &&
  !self.attribution &&
  !self.source_disclosure &&
  !self.same_license &&
  !self.network_source &&
  !self.patent_notice
}

///|
pub fn Obligations::requires_notice(self : Obligations) -> Bool {
  self.notice
}

///|
pub fn Obligations::requires_attribution(self : Obligations) -> Bool {
  self.attribution
}

///|
pub fn Obligations::requires_source_disclosure(self : Obligations) -> Bool {
  self.source_disclosure
}

///|
pub fn Obligations::requires_same_license(self : Obligations) -> Bool {
  self.same_license
}

///|
pub fn Obligations::requires_network_source(self : Obligations) -> Bool {
  self.network_source
}

///|
pub fn Obligations::requires_patent_notice(self : Obligations) -> Bool {
  self.patent_notice
}

///|
pub fn Obligations::names(self : Obligations) -> Array[String] {
  let values = []
  if self.notice {
    values.push("preserve-notices")
  }
  if self.attribution {
    values.push("preserve-attribution")
  }
  if self.source_disclosure {
    values.push("disclose-source")
  }
  if self.same_license {
    values.push("same-license")
  }
  if self.network_source {
    values.push("network-source-offer")
  }
  if self.patent_notice {
    values.push("patent-notice")
  }
  values
}

///|
pub struct LicenseInfo {
  id : String
  family : LicenseFamily
  osi_approved : Bool
  deprecated : Bool
  obligations : Obligations
} derive(Eq, @debug.Debug)

///|
pub fn LicenseInfo::id(self : LicenseInfo) -> String {
  self.id
}

///|
pub fn LicenseInfo::family(self : LicenseInfo) -> LicenseFamily {
  self.family
}

///|
pub fn LicenseInfo::is_osi_approved(self : LicenseInfo) -> Bool {
  self.osi_approved
}

///|
pub fn LicenseInfo::is_deprecated(self : LicenseInfo) -> Bool {
  self.deprecated
}

///|
pub fn LicenseInfo::obligations(self : LicenseInfo) -> Obligations {
  self.obligations
}

///|
pub struct LicenseAtom {
  id : String
  exception : String?
} derive(Eq, @debug.Debug)

///|
pub fn LicenseAtom::new(
  id : String,
  exception? : String? = None,
) -> LicenseAtom {
  { id, exception }
}

///|
pub fn LicenseAtom::id(self : LicenseAtom) -> String {
  self.id
}

///|
pub fn LicenseAtom::exception(self : LicenseAtom) -> String? {
  self.exception
}

///|
pub enum Expression {
  Atom(LicenseAtom)
  And(Expression, Expression)
  Or(Expression, Expression)
} derive(Eq, @debug.Debug)

///|
fn expression_precedence(expression : Expression) -> Int {
  match expression {
    Atom(_) => 3
    And(_, _) => 2
    Or(_, _) => 1
  }
}

///|
fn render_expression(
  output : StringBuilder,
  expression : Expression,
  parent_precedence : Int,
) -> Unit {
  let precedence = expression_precedence(expression)
  let parentheses = precedence < parent_precedence
  if parentheses {
    output.write_char('(')
  }
  match expression {
    Atom(atom) => {
      output.write_string(atom.id)
      match atom.exception {
        Some(value) => output.write_string(" WITH " + value)
        None => ()
      }
    }
    And(left, right) => {
      render_expression(output, left, precedence)
      output.write_string(" AND ")
      render_expression(output, right, precedence)
    }
    Or(left, right) => {
      render_expression(output, left, precedence)
      output.write_string(" OR ")
      render_expression(output, right, precedence)
    }
  }
  if parentheses {
    output.write_char(')')
  }
}

///|
/// Render the expression with stable spacing and only semantic parentheses.
pub fn Expression::canonical(self : Expression) -> String {
  let output = StringBuilder::new()
  render_expression(output, self, 0)
  output.to_string()
}

///|
pub fn Expression::atoms(self : Expression) -> Array[LicenseAtom] {
  match self {
    Atom(value) => [value]
    And(left, right) | Or(left, right) => left.atoms() + right.atoms()
  }
}

///|
pub fn LicenseFamily::name(self : LicenseFamily) -> String {
  match self {
    Permissive => "permissive"
    WeakCopyleft => "weak-copyleft"
    StrongCopyleft => "strong-copyleft"
    PublicDomain => "public-domain"
    Other => "other"
  }
}
