///|
pub struct InventoryIndex {
  components : Array[Component]
  expressions : Array[Expression]
} derive(Eq, @debug.Debug)

///|
pub fn InventoryIndex::components(self : InventoryIndex) -> Array[Component] {
  self.components.copy()
}

///|
/// Compile a validated inventory into a reusable query index.
pub fn InventoryIndex::build(
  components : Array[Component],
) -> Result[InventoryIndex, Diagnostic] {
  let expressions = []
  for index, component in components {
    match parse_expression(component.expression) {
      Ok(value) => expressions.push(value)
      Err(error) =>
        return Err(
          Diagnostic::new(
            "index.expression.invalid",
            "components[" + index.to_string() + "]",
            "cannot index an invalid component expression",
            "valid SPDX expression",
            error.to_text(),
          ),
        )
    }
  }
  Ok({ components: components.copy(), expressions })
}

///|
pub fn compile_inventory(source : String) -> Result[InventoryIndex, Diagnostic] {
  match parse_inventory(source) {
    Ok(components) => InventoryIndex::build(components)
    Err(error) => Err(error)
  }
}

///|
pub fn InventoryIndex::find(self : InventoryIndex, name : String) -> Component? {
  find_component(self.components, name)
}

///|
pub fn InventoryIndex::using_license(
  self : InventoryIndex,
  id : String,
) -> Result[Array[Component], Diagnostic] {
  if lookup_license(id) is None {
    return Err(
      Diagnostic::new(
        "query.license.unknown", "license", "query license is outside the supported catalog",
        "supported SPDX license identifier", id,
      ),
    )
  }
  let result = []
  for index, expression in self.expressions {
    if expression.atoms().any(fn(atom) { atom.id == id }) {
      result.push(self.components[index])
    }
  }
  Ok(result)
}

///|
pub fn InventoryIndex::using_family(
  self : InventoryIndex,
  family : LicenseFamily,
) -> Array[Component] {
  let result = []
  for index, expression in self.expressions {
    if expression
      .atoms()
      .any(fn(atom) { lookup_license(atom.id).unwrap().family() == family }) {
      result.push(self.components[index])
    }
  }
  result
}

///|
pub fn InventoryIndex::using_family_name(
  self : InventoryIndex,
  family : String,
) -> Result[Array[Component], Diagnostic] {
  let expected = match family {
    "permissive" => Permissive
    "weak-copyleft" => WeakCopyleft
    "strong-copyleft" => StrongCopyleft
    "public-domain" => PublicDomain
    "other" => Other
    _ =>
      return Err(
        Diagnostic::new(
          "query.family.unknown", "family", "query family is not supported", "permissive, weak-copyleft, strong-copyleft, public-domain, or other",
          family,
        ),
      )
  }
  Ok(self.using_family(expected))
}

///|
pub fn InventoryIndex::requiring(
  self : InventoryIndex,
  obligation : String,
) -> Result[Array[Component], Diagnostic] {
  if !is_obligation_name(obligation) {
    return Err(
      Diagnostic::new(
        "query.obligation.unknown", "obligation", "query obligation is not supported",
        "documented obligation name", obligation,
      ),
    )
  }
  let result = []
  for index, expression in self.expressions {
    let mut matches = false
    for atom in expression.atoms() {
      if contains_string(
          lookup_license(atom.id).unwrap().obligations().names(),
          obligation,
        ) {
        matches = true
      }
    }
    if matches {
      result.push(self.components[index])
    }
  }
  Ok(result)
}

///|
pub fn InventoryIndex::canonical(self : InventoryIndex) -> String {
  let output = StringBuilder::new()
  for index, component in self.components {
    if index > 0 {
      output.write_char('\n')
    }
    output.write_string(
      component.name +
      "|" +
      component.version +
      "|" +
      self.expressions[index].canonical(),
    )
  }
  output.to_string()
}

///|
pub fn canonical_inventory(source : String) -> Result[String, Diagnostic] {
  match compile_inventory(source) {
    Ok(index) => Ok(index.canonical())
    Err(error) => Err(error)
  }
}

///|
pub struct QueryResult {
  query : String
  components : Array[Component]
} derive(Eq, @debug.Debug)

///|
pub fn QueryResult::new(
  query : String,
  components : Array[Component],
) -> QueryResult {
  { query, components: components.copy() }
}

///|
pub fn QueryResult::query(self : QueryResult) -> String {
  self.query
}

///|
pub fn QueryResult::components(self : QueryResult) -> Array[Component] {
  self.components.copy()
}

///|
pub fn QueryResult::to_text(self : QueryResult) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "QUERY " + self.query + " matches=" + self.components.length().to_string(),
  )
  for component in self.components {
    output.write_string(
      "\n" +
      component.name +
      "@" +
      component.version +
      " " +
      component.expression,
    )
  }
  output.to_string()
}

///|
pub fn QueryResult::to_json(self : QueryResult) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "{\"query\":" + quote_json(self.query) + ",\"components\":[",
  )
  for index, component in self.components {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string(
      "{\"name\":" +
      quote_json(component.name) +
      ",\"version\":" +
      quote_json(component.version) +
      ",\"expression\":" +
      quote_json(component.expression) +
      "}",
    )
  }
  output.write_string("]}")
  output.to_string()
}
