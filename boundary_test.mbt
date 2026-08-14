///|
test "expression boundary diagnostics remain stable" {
  assert_eq(parse_expression("").unwrap_err().code(), "expression.empty")
  assert_eq(
    parse_expression("MIT / Apache-2.0").unwrap_err().code(),
    "expression.character.invalid",
  )
  assert_eq(
    parse_expression("LicenseRef-Proprietary").unwrap_err().code(),
    "expression.reference.unsupported",
  )
  assert_eq(
    parse_expression("MIT+").unwrap_err().code(),
    "expression.plus.unsupported",
  )
}

///|
test "policy comments blanks and duplicate keys are deterministic" {
  let source = "# release policy\n\nrequire-osi=true\ndeny=BUSL-1.1"
  let policy = parse_policy(source).unwrap()
  assert_true(policy.requires_osi())
  assert_eq(policy.denied_ids(), ["BUSL-1.1"])
  assert_eq(
    parse_policy("allow=MIT\nallow=Apache-2.0").unwrap_err().code(),
    "policy.key.duplicate",
  )
  assert_eq(
    parse_policy("require-osi=yes").unwrap_err().code(),
    "policy.boolean.invalid",
  )
}

///|
test "inventory comments and whitespace are normalized" {
  let source = "# dependencies\n app | 1.0 | (MIT OR Apache-2.0) \n\nlib|2|BSD-3-Clause"
  let index = compile_inventory(source).unwrap()
  assert_eq(index.components().length(), 2)
  assert_eq(index.canonical(), "app|1.0|MIT OR Apache-2.0\nlib|2|BSD-3-Clause")
}

///|
test "JSON reports escape component data" {
  let component = Component::new("quoted\"name", "1\\2", "MIT")
  let report = audit([component], Policy::permissive()).unwrap()
  let json = report.to_json()
  assert_true(json.contains("quoted\\\"name"))
  assert_true(json.contains("1\\\\2"))
}

///|
test "preference order affects only acceptable OR branches" {
  let source = "MIT OR Apache-2.0 OR GPL-3.0-only"
  let preferred = Policy::permissive().with_preferences([
    "GPL-3.0-only", "Apache-2.0", "MIT",
  ])
  assert_eq(
    evaluate_source(source, preferred).unwrap().selected(),
    "GPL-3.0-only",
  )
  let denied = preferred.with_denied(["GPL-3.0-only"])
  assert_eq(evaluate_source(source, denied).unwrap().selected(), "Apache-2.0")
}

///|
test "non-OSI catalog entries require review under OSI policy" {
  let result = evaluate_source("BUSL-1.1", Policy::osi_only()).unwrap()
  assert_eq(result.status_name(), "review")
  assert_true(result.reasons()[0].contains("not marked OSI-approved"))
  let matrix = policy_matrix(Policy::osi_only())
  assert_true(matrix.review() >= 1)
}

///|
test "unknown command is a usage error" {
  let result = execute(["definitely-not-a-command"])
  assert_eq(result.exit_code(), 2)
  assert_true(result.output().contains("unknown command"))
}

///|
test "catalog command includes profile header and entries" {
  let result = execute(["catalog"])
  assert_eq(result.exit_code(), 0)
  assert_true(result.output().has_prefix("CATALOG licenses=44"))
  assert_true(result.output().contains("Apache-2.0 family=permissive"))
}
