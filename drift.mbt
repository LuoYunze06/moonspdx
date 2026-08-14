///|
pub enum ComponentChangeKind {
  Added
  Removed
  VersionChanged
  LicenseChanged
  VersionAndLicenseChanged
  Unchanged
} derive(Eq, @debug.Debug)

///|
pub fn ComponentChangeKind::name(self : ComponentChangeKind) -> String {
  match self {
    Added => "added"
    Removed => "removed"
    VersionChanged => "version-changed"
    LicenseChanged => "license-changed"
    VersionAndLicenseChanged => "version-and-license-changed"
    Unchanged => "unchanged"
  }
}

///|
pub struct ComponentChange {
  name : String
  kind : ComponentChangeKind
  before_version : String?
  after_version : String?
  before_expression : String?
  after_expression : String?
} derive(Eq, @debug.Debug)

///|
pub fn ComponentChange::name(self : ComponentChange) -> String {
  self.name
}

///|
pub fn ComponentChange::kind(self : ComponentChange) -> ComponentChangeKind {
  self.kind
}

///|
pub fn ComponentChange::before_version(self : ComponentChange) -> String? {
  self.before_version
}

///|
pub fn ComponentChange::after_version(self : ComponentChange) -> String? {
  self.after_version
}

///|
pub fn ComponentChange::before_expression(self : ComponentChange) -> String? {
  self.before_expression
}

///|
pub fn ComponentChange::after_expression(self : ComponentChange) -> String? {
  self.after_expression
}

///|
fn find_component(components : Array[Component], name : String) -> Component? {
  for component in components {
    if component.name == name {
      return Some(component)
    }
  }
  None
}

///|
fn classify_component_change(
  before : Component,
  after : Component,
) -> ComponentChangeKind {
  let version_changed = before.version != after.version
  let license_changed = before.expression != after.expression
  match (version_changed, license_changed) {
    (true, true) => VersionAndLicenseChanged
    (true, false) => VersionChanged
    (false, true) => LicenseChanged
    (false, false) => Unchanged
  }
}

///|
fn changed_record(before : Component, after : Component) -> ComponentChange {
  {
    name: before.name,
    kind: classify_component_change(before, after),
    before_version: Some(before.version),
    after_version: Some(after.version),
    before_expression: Some(before.expression),
    after_expression: Some(after.expression),
  }
}

///|
fn added_record(component : Component) -> ComponentChange {
  {
    name: component.name,
    kind: Added,
    before_version: None,
    after_version: Some(component.version),
    before_expression: None,
    after_expression: Some(component.expression),
  }
}

///|
fn removed_record(component : Component) -> ComponentChange {
  {
    name: component.name,
    kind: Removed,
    before_version: Some(component.version),
    after_version: None,
    before_expression: Some(component.expression),
    after_expression: None,
  }
}

///|
pub struct InventoryDiff {
  changes : Array[ComponentChange]
  added : Int
  removed : Int
  version_changed : Int
  license_changed : Int
  unchanged : Int
} derive(Eq, @debug.Debug)

///|
pub fn InventoryDiff::changes(self : InventoryDiff) -> Array[ComponentChange] {
  self.changes.copy()
}

///|
pub fn InventoryDiff::added(self : InventoryDiff) -> Int {
  self.added
}

///|
pub fn InventoryDiff::removed(self : InventoryDiff) -> Int {
  self.removed
}

///|
pub fn InventoryDiff::version_changed(self : InventoryDiff) -> Int {
  self.version_changed
}

///|
pub fn InventoryDiff::license_changed(self : InventoryDiff) -> Int {
  self.license_changed
}

///|
pub fn InventoryDiff::unchanged(self : InventoryDiff) -> Int {
  self.unchanged
}

///|
pub fn InventoryDiff::has_license_drift(self : InventoryDiff) -> Bool {
  self.license_changed > 0 || self.added > 0
}

///|
/// Compare two validated inventories by component name while preserving input order.
pub fn diff_components(
  before : Array[Component],
  after : Array[Component],
) -> InventoryDiff {
  let changes = []
  let mut added = 0
  let mut removed = 0
  let mut version_changed = 0
  let mut license_changed = 0
  let mut unchanged = 0
  for old in before {
    match find_component(after, old.name) {
      Some(current) => {
        let change = changed_record(old, current)
        match change.kind {
          VersionChanged => version_changed = version_changed + 1
          LicenseChanged => license_changed = license_changed + 1
          VersionAndLicenseChanged => {
            version_changed = version_changed + 1
            license_changed = license_changed + 1
          }
          Unchanged => unchanged = unchanged + 1
          _ => ()
        }
        changes.push(change)
      }
      None => {
        removed = removed + 1
        changes.push(removed_record(old))
      }
    }
  }
  for current in after {
    if find_component(before, current.name) is None {
      added = added + 1
      changes.push(added_record(current))
    }
  }
  { changes, added, removed, version_changed, license_changed, unchanged }
}

///|
pub fn diff_inventories(
  before : String,
  after : String,
) -> Result[InventoryDiff, Diagnostic] {
  let old_components = match parse_inventory(before) {
    Ok(value) => value
    Err(error) =>
      return Err(
        Diagnostic::new(
          "diff.before.invalid",
          "before",
          "baseline inventory is invalid",
          "valid component inventory",
          error.to_text(),
        ),
      )
  }
  let new_components = match parse_inventory(after) {
    Ok(value) => value
    Err(error) =>
      return Err(
        Diagnostic::new(
          "diff.after.invalid",
          "after",
          "current inventory is invalid",
          "valid component inventory",
          error.to_text(),
        ),
      )
  }
  Ok(diff_components(old_components, new_components))
}

///|
fn optional_text(value : String?) -> String {
  match value {
    Some(actual) => actual
    None => "-"
  }
}

///|
pub fn InventoryDiff::to_text(self : InventoryDiff) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "DRIFT added=" +
    self.added.to_string() +
    " removed=" +
    self.removed.to_string() +
    " version_changed=" +
    self.version_changed.to_string() +
    " license_changed=" +
    self.license_changed.to_string() +
    " unchanged=" +
    self.unchanged.to_string(),
  )
  for change in self.changes {
    output.write_string(
      "\n" +
      change.kind.name() +
      " " +
      change.name +
      " version=" +
      optional_text(change.before_version) +
      "->" +
      optional_text(change.after_version) +
      " license=" +
      optional_text(change.before_expression) +
      "->" +
      optional_text(change.after_expression),
    )
  }
  output.to_string()
}

///|
pub fn InventoryDiff::to_json(self : InventoryDiff) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "{\"added\":" +
    self.added.to_string() +
    ",\"removed\":" +
    self.removed.to_string() +
    ",\"version_changed\":" +
    self.version_changed.to_string() +
    ",\"license_changed\":" +
    self.license_changed.to_string() +
    ",\"unchanged\":" +
    self.unchanged.to_string() +
    ",\"changes\":[",
  )
  for index, change in self.changes {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string(
      "{\"name\":" +
      quote_json(change.name) +
      ",\"kind\":" +
      quote_json(change.kind.name()) +
      ",\"before_version\":" +
      quote_json(optional_text(change.before_version)) +
      ",\"after_version\":" +
      quote_json(optional_text(change.after_version)) +
      ",\"before_expression\":" +
      quote_json(optional_text(change.before_expression)) +
      ",\"after_expression\":" +
      quote_json(optional_text(change.after_expression)) +
      "}",
    )
  }
  output.write_string("]}")
  output.to_string()
}
