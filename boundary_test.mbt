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
test "parser rejects excessive parenthesis nesting before recursion" {
  let source = StringBuilder::new()
  let mut index = 0
  while index < 65 {
    source.write_char('(')
    index = index + 1
  }
  source.write_string("MIT")
  index = 0
  while index < 65 {
    source.write_char(')')
    index = index + 1
  }
  assert_eq(
    parse_expression(source.to_string()).unwrap_err().code(),
    "expression.depth.limit",
  )
}

///|
test "unknown command is a usage error" {
  let result = execute(["definitely-not-a-command"])
  assert_eq(result.exit_code(), 2)
  assert_true(result.output().contains("unknown command"))
}
