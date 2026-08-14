///|
pub struct LicenseUsage {
  id : String
  components : Int
  occurrences : Int
  family : LicenseFamily
} derive(Eq, @debug.Debug)

///|
pub fn LicenseUsage::id(self : LicenseUsage) -> String {
  self.id
}

///|
pub fn LicenseUsage::components(self : LicenseUsage) -> Int {
  self.components
}

///|
pub fn LicenseUsage::occurrences(self : LicenseUsage) -> Int {
  self.occurrences
}

///|
pub fn LicenseUsage::family(self : LicenseUsage) -> LicenseFamily {
  self.family
}

///|
pub struct InventoryStats {
  components : Int
  unique_licenses : Int
  expression_atoms : Int
  and_operators : Int
  or_operators : Int
  exceptions : Int
  maximum_depth : Int
  maximum_alternatives : Int
  permissive_components : Int
  weak_copyleft_components : Int
  strong_copyleft_components : Int
  public_domain_components : Int
  other_components : Int
  usages : Array[LicenseUsage]
} derive(Eq, @debug.Debug)

///|
pub fn InventoryStats::components(self : InventoryStats) -> Int {
  self.components
}

///|
pub fn InventoryStats::unique_licenses(self : InventoryStats) -> Int {
  self.unique_licenses
}

///|
pub fn InventoryStats::expression_atoms(self : InventoryStats) -> Int {
  self.expression_atoms
}

///|
pub fn InventoryStats::and_operators(self : InventoryStats) -> Int {
  self.and_operators
}

///|
pub fn InventoryStats::or_operators(self : InventoryStats) -> Int {
  self.or_operators
}

///|
pub fn InventoryStats::exceptions(self : InventoryStats) -> Int {
  self.exceptions
}

///|
pub fn InventoryStats::maximum_depth(self : InventoryStats) -> Int {
  self.maximum_depth
}

///|
pub fn InventoryStats::maximum_alternatives(self : InventoryStats) -> Int {
  self.maximum_alternatives
}

///|
pub fn InventoryStats::usages(self : InventoryStats) -> Array[LicenseUsage] {
  self.usages.copy()
}

///|
fn usage_index(usages : Array[LicenseUsage], id : String) -> Int? {
  for index, usage in usages {
    if usage.id == id {
      return Some(index)
    }
  }
  None
}

///|
fn add_usage(usages : Array[LicenseUsage], atom : LicenseAtom) -> Unit {
  match usage_index(usages, atom.id) {
    Some(index) => {
      let old = usages[index]
      usages[index] = { ..old, occurrences: old.occurrences + 1 }
    }
    None => {
      let info = lookup_license(atom.id).unwrap()
      usages.push({
        id: atom.id,
        components: 0,
        occurrences: 1,
        family: info.family(),
      })
    }
  }
}

///|
fn increment_component_usage(
  usages : Array[LicenseUsage],
  atoms : Array[LicenseAtom],
) -> Unit {
  let seen = []
  for atom in atoms {
    if !contains_string(seen, atom.id) {
      match usage_index(usages, atom.id) {
        Some(index) => {
          let old = usages[index]
          usages[index] = { ..old, components: old.components + 1 }
        }
        None => ()
      }
      seen.push(atom.id)
    }
  }
}

///|
fn component_families(atoms : Array[LicenseAtom]) -> Array[LicenseFamily] {
  let families = []
  for atom in atoms {
    let family = lookup_license(atom.id).unwrap().family()
    if !families.any(fn(value) { value == family }) {
      families.push(family)
    }
  }
  families
}

///|
/// Analyze the structural license footprint of a validated component inventory.
pub fn inventory_stats(
  components : Array[Component],
) -> Result[InventoryStats, Diagnostic] {
  let usages : Array[LicenseUsage] = []
  let mut expression_atoms = 0
  let mut and_operators = 0
  let mut or_operators = 0
  let mut exceptions = 0
  let mut maximum_depth = 0
  let mut maximum_alternatives = 0
  let mut permissive_components = 0
  let mut weak_copyleft_components = 0
  let mut strong_copyleft_components = 0
  let mut public_domain_components = 0
  let mut other_components = 0
  for index, component in components {
    let expression = match parse_expression(component.expression) {
      Ok(value) => value
      Err(error) =>
        return Err(
          Diagnostic::new(
            "stats.expression.invalid",
            "components[" + index.to_string() + "]",
            "cannot analyze an invalid component expression",
            "valid SPDX expression",
            error.to_text(),
          ),
        )
    }
    let stats = expression.stats()
    expression_atoms = expression_atoms + stats.atoms()
    and_operators = and_operators + stats.and_operators()
    or_operators = or_operators + stats.or_operators()
    if stats.depth() > maximum_depth {
      maximum_depth = stats.depth()
    }
    if stats.alternatives() > maximum_alternatives {
      maximum_alternatives = stats.alternatives()
    }
    let atoms = expression.atoms()
    for atom in atoms {
      if atom.exception is Some(_) {
        exceptions = exceptions + 1
      }
      add_usage(usages, atom)
    }
    increment_component_usage(usages, atoms)
    for family in component_families(atoms) {
      match family {
        Permissive => permissive_components = permissive_components + 1
        WeakCopyleft => weak_copyleft_components = weak_copyleft_components + 1
        StrongCopyleft =>
          strong_copyleft_components = strong_copyleft_components + 1
        PublicDomain => public_domain_components = public_domain_components + 1
        Other => other_components = other_components + 1
      }
    }
  }
  Ok({
    components: components.length(),
    unique_licenses: usages.length(),
    expression_atoms,
    and_operators,
    or_operators,
    exceptions,
    maximum_depth,
    maximum_alternatives,
    permissive_components,
    weak_copyleft_components,
    strong_copyleft_components,
    public_domain_components,
    other_components,
    usages,
  })
}

///|
pub fn analyze_inventory(source : String) -> Result[InventoryStats, Diagnostic] {
  match parse_inventory(source) {
    Ok(components) => inventory_stats(components)
    Err(error) => Err(error)
  }
}

///|
pub fn InventoryStats::to_text(self : InventoryStats) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "INVENTORY-STATS components=" +
    self.components.to_string() +
    " unique_licenses=" +
    self.unique_licenses.to_string() +
    " atoms=" +
    self.expression_atoms.to_string() +
    " and=" +
    self.and_operators.to_string() +
    " or=" +
    self.or_operators.to_string() +
    " exceptions=" +
    self.exceptions.to_string() +
    " max_depth=" +
    self.maximum_depth.to_string() +
    " max_alternatives=" +
    self.maximum_alternatives.to_string(),
  )
  output.write_string(
    "\nFAMILIES permissive=" +
    self.permissive_components.to_string() +
    " weak_copyleft=" +
    self.weak_copyleft_components.to_string() +
    " strong_copyleft=" +
    self.strong_copyleft_components.to_string() +
    " public_domain=" +
    self.public_domain_components.to_string() +
    " other=" +
    self.other_components.to_string(),
  )
  for usage in self.usages {
    output.write_string(
      "\nLICENSE " +
      usage.id +
      " family=" +
      usage.family.name() +
      " components=" +
      usage.components.to_string() +
      " occurrences=" +
      usage.occurrences.to_string(),
    )
  }
  output.to_string()
}

///|
pub fn InventoryStats::to_json(self : InventoryStats) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "{\"components\":" +
    self.components.to_string() +
    ",\"unique_licenses\":" +
    self.unique_licenses.to_string() +
    ",\"expression_atoms\":" +
    self.expression_atoms.to_string() +
    ",\"and_operators\":" +
    self.and_operators.to_string() +
    ",\"or_operators\":" +
    self.or_operators.to_string() +
    ",\"exceptions\":" +
    self.exceptions.to_string() +
    ",\"maximum_depth\":" +
    self.maximum_depth.to_string() +
    ",\"maximum_alternatives\":" +
    self.maximum_alternatives.to_string() +
    ",\"families\":{\"permissive\":" +
    self.permissive_components.to_string() +
    ",\"weak_copyleft\":" +
    self.weak_copyleft_components.to_string() +
    ",\"strong_copyleft\":" +
    self.strong_copyleft_components.to_string() +
    ",\"public_domain\":" +
    self.public_domain_components.to_string() +
    ",\"other\":" +
    self.other_components.to_string() +
    "},\"licenses\":[",
  )
  for index, usage in self.usages {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string(
      "{\"id\":" +
      quote_json(usage.id) +
      ",\"family\":" +
      quote_json(usage.family.name()) +
      ",\"components\":" +
      usage.components.to_string() +
      ",\"occurrences\":" +
      usage.occurrences.to_string() +
      "}",
    )
  }
  output.write_string("]}")
  output.to_string()
}
