///|
test "expands conjunctive alternatives" {
  let expression = parse_expression(
    "(MIT OR Apache-2.0) AND (BSD-2-Clause OR BSD-3-Clause)",
  ).unwrap()
  let alternatives = expression.alternatives().unwrap()
  assert_eq(alternatives.length(), 4)
  assert_eq(render_alternative(alternatives[0]), "MIT AND BSD-2-Clause")
  assert_eq(render_alternative(alternatives[3]), "Apache-2.0 AND BSD-3-Clause")
  assert_eq(expression.stats().alternatives(), 4)
  assert_eq(expression.stats().depth(), 3)
}

///|
test "parses and canonicalizes policy" {
  let source = "require-osi=true\nallow=MIT,Apache-2.0\ndeny=BUSL-1.1\nprefer=Apache-2.0\nrequire-obligations=preserve-notices"
  let policy = parse_policy(source).unwrap()
  assert_true(policy.requires_osi())
  assert_eq(policy.allowed_ids().length(), 2)
  assert_eq(policy.denied_ids(), ["BUSL-1.1"])
  assert_eq(parse_policy(policy.canonical()), Ok(policy))
}

///|
test "rejects policy conflicts and unknown values" {
  assert_eq(
    parse_policy("allow=MIT\ndeny=MIT").unwrap_err().code(),
    "policy.rule.conflict",
  )
  assert_eq(
    parse_policy("deny=Made-Up-1.0").unwrap_err().code(),
    "policy.license.unknown",
  )
  assert_eq(
    parse_policy("require-obligations=pay-royalties").unwrap_err().code(),
    "policy.obligation.unknown",
  )
}

///|
test "renders stable text and JSON reports" {
  let report = audit_inventory(
    "app|1.0|MIT\nengine|2.0|Apache-2.0",
    Policy::osi_only(),
  ).unwrap()
  assert_true(report.to_text().contains("MOONSPDX components=2 accepted=true"))
  assert_true(report.to_json().contains("\"name\":\"engine\""))
}
