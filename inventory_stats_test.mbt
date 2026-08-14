///|
test "summarizes inventory structure and families" {
  let stats = analyze_inventory(
    "app|1|MIT OR Apache-2.0\nengine|2|GPL-3.0-only WITH Classpath-exception-2.0\ndata|1|CC0-1.0",
  ).unwrap()
  assert_eq(stats.components(), 3)
  assert_eq(stats.unique_licenses(), 4)
  assert_eq(stats.expression_atoms(), 4)
  assert_eq(stats.or_operators(), 1)
  assert_eq(stats.exceptions(), 1)
  assert_eq(stats.maximum_alternatives(), 2)
  assert_true(stats.to_text().contains("strong_copyleft=1"))
  assert_true(stats.to_json().contains("\"id\":\"Apache-2.0\""))
}

///|
test "notice plan turns obligations into component actions" {
  let report = audit_inventory(
    "app|1|MIT\nengine|2|Apache-2.0",
    Policy::osi_only(),
  ).unwrap()
  let plan = notice_plan(report).unwrap()
  assert_eq(plan.components(), 2)
  assert_true(plan.actions().length() >= 4)
  assert_true(plan.obligation_kinds().contains("patent-notice"))
  assert_true(plan.to_text().contains("[ ] 1 app@1"))
  assert_true(plan.to_json().contains("\"component\":\"engine\""))
}

///|
test "notice plan refuses unresolved audit" {
  let rejected = audit_inventory(
    "engine|2|GPL-3.0-only",
    Policy::permissive().with_denied(["GPL-3.0-only"]),
  ).unwrap()
  assert_eq(notice_plan(rejected).unwrap_err().code(), "notice.audit.rejected")
  let review = audit_inventory("docs|1|CC-BY-4.0", Policy::osi_only()).unwrap()
  assert_eq(notice_plan(review).unwrap_err().code(), "notice.audit.review")
}
