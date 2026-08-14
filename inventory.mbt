///|
pub struct Component {
  name : String
  version : String
  expression : String
} derive(Eq, @debug.Debug)

///|
pub fn Component::new(
  name : String,
  version : String,
  expression : String,
) -> Component {
  { name, version, expression }
}

///|
pub fn Component::name(self : Component) -> String {
  self.name
}

///|
pub fn Component::version(self : Component) -> String {
  self.version
}

///|
pub fn Component::expression(self : Component) -> String {
  self.expression
}

///|
fn trim_owned(value : StringView) -> String {
  value.trim().to_owned()
}

///|
/// Parse `name|version|SPDX expression` lines. Blank and `#` comment lines are skipped.
pub fn parse_inventory(source : String) -> Result[Array[Component], Diagnostic] {
  let components = []
  let seen = []
  let lines = source.split("\n").collect()
  if lines.length() > 513 {
    return Err(
      Diagnostic::new(
        "inventory.limit",
        "inventory",
        "inventory has too many lines",
        "at most 512 component lines",
        lines.length().to_string(),
      ),
    )
  }
  let mut line_number = 0
  while line_number < lines.length() {
    let line = trim_owned(lines[line_number])
    if !line.is_empty() && !line.has_prefix("#") {
      let fields = line
        .split("|")
        .map(fn(value) { trim_owned(value) })
        .collect()
      if fields.length() != 3 {
        return Err(
          Diagnostic::new(
            "inventory.line.fields",
            "line[" + line_number.to_string() + "]",
            "component line must contain exactly three pipe-separated fields",
            "name|version|SPDX expression",
            line,
          ),
        )
      }
      if fields[0].is_empty() || fields[1].is_empty() || fields[2].is_empty() {
        return Err(
          Diagnostic::new(
            "inventory.line.empty",
            "line[" + line_number.to_string() + "]",
            "component fields cannot be empty",
            "non-empty name, version, and expression",
            line,
          ),
        )
      }
      if contains_string(seen, fields[0]) {
        return Err(
          Diagnostic::new(
            "inventory.component.duplicate",
            "line[" + line_number.to_string() + "]",
            "component name appears more than once",
            "unique component name",
            fields[0],
          ),
        )
      }
      seen.push(fields[0])
      components.push(Component::new(fields[0], fields[1], fields[2]))
    }
    line_number = line_number + 1
  }
  if components.is_empty() {
    return Err(
      Diagnostic::new(
        "inventory.empty", "inventory", "inventory has no component records", "at least one component line",
        "empty",
      ),
    )
  }
  Ok(components)
}

///|
pub struct ComponentResult {
  component : Component
  evaluation : Evaluation
} derive(Eq, @debug.Debug)

///|
pub fn ComponentResult::component(self : ComponentResult) -> Component {
  self.component
}

///|
pub fn ComponentResult::evaluation(self : ComponentResult) -> Evaluation {
  self.evaluation
}

///|
pub struct AuditReport {
  results : Array[ComponentResult]
  obligations : Obligations
  accepted : Bool
  review_count : Int
  rejected_count : Int
} derive(Eq, @debug.Debug)

///|
pub fn AuditReport::results(self : AuditReport) -> Array[ComponentResult] {
  self.results.copy()
}

///|
pub fn AuditReport::obligations(self : AuditReport) -> Obligations {
  self.obligations
}

///|
pub fn AuditReport::accepted(self : AuditReport) -> Bool {
  self.accepted
}

///|
pub fn AuditReport::review_count(self : AuditReport) -> Int {
  self.review_count
}

///|
pub fn AuditReport::rejected_count(self : AuditReport) -> Int {
  self.rejected_count
}

///|
/// Audit every component and aggregate the obligations required by all choices.
pub fn audit(
  components : Array[Component],
  policy : Policy,
) -> Result[AuditReport, Diagnostic] {
  let results = []
  let mut obligations = Obligations::none()
  let mut review_count = 0
  let mut rejected_count = 0
  for index, component in components {
    let evaluation = match evaluate_source(component.expression, policy) {
      Ok(value) => value
      Err(error) =>
        return Err(
          Diagnostic::new(
            "inventory.expression.invalid",
            "components[" + index.to_string() + "].expression",
            "component license expression failed validation",
            "valid SPDX expression",
            error.to_text(),
          ),
        )
    }
    obligations = obligations.combine(evaluation.obligations())
    match evaluation.status() {
      Accepted => ()
      Review => review_count = review_count + 1
      Rejected => rejected_count = rejected_count + 1
    }
    results.push({ component, evaluation })
  }
  Ok({
    results,
    obligations,
    accepted: rejected_count == 0,
    review_count,
    rejected_count,
  })
}

///|
pub fn audit_inventory(
  source : String,
  policy : Policy,
) -> Result[AuditReport, Diagnostic] {
  match parse_inventory(source) {
    Ok(components) => audit(components, policy)
    Err(error) => Err(error)
  }
}
