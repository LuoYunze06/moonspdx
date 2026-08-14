///|
test "chooses the first allowed OR branch" {
  let expression = parse_expression("GPL-3.0-only OR Apache-2.0").unwrap()
  let result = evaluate(
    expression,
    Policy::osi_only().with_denied(["GPL-3.0-only"]),
  )
  assert_eq(result.status_name(), "accepted")
  assert_eq(result.selected(), "Apache-2.0")
}

///|
test "AND combines obligations and rejects denied license" {
  let expression = parse_expression("MIT AND GPL-3.0-only").unwrap()
  let result = evaluate(
    expression,
    Policy::permissive().with_denied(["GPL-3.0-only"]),
  )
  assert_eq(result.status_name(), "rejected")
  assert_true(result.obligations().requires_source_disclosure())
}

///|
test "invalid exception attachment is rejected" {
  let result = evaluate_source(
    "MIT WITH Classpath-exception-2.0",
    Policy::permissive(),
  ).unwrap()
  assert_eq(result.status_name(), "rejected")
  assert_true(result.reasons()[0].contains("not compatible"))
}

///|
test "parses and audits inventory" {
  let source = "app|1.0|MIT OR Apache-2.0\nengine|2.1|GPL-3.0-only\ndocs|1.0|CC0-1.0"
  let report = audit_inventory(source, Policy::osi_only()).unwrap()
  assert_true(report.accepted())
  assert_eq(report.results().length(), 3)
  assert_true(report.obligations().requires_notice())
}

///|
test "rejects malformed and duplicate inventory records" {
  assert_eq(
    parse_inventory("app|1.0").unwrap_err().code(),
    "inventory.line.fields",
  )
  assert_eq(
    parse_inventory("app|1.0|MIT\napp|2.0|MIT").unwrap_err().code(),
    "inventory.component.duplicate",
  )
}
