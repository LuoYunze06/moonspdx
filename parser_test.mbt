///|
test "normalizes precedence and parentheses" {
  assert_eq(
    normalize_expression("MIT OR (Apache-2.0 AND BSD-3-Clause)"),
    Ok("MIT OR Apache-2.0 AND BSD-3-Clause"),
  )
  assert_eq(
    normalize_expression("(MIT OR Apache-2.0) AND BSD-3-Clause"),
    Ok("(MIT OR Apache-2.0) AND BSD-3-Clause"),
  )
}

///|
test "normalizes legacy plus identifiers" {
  assert_eq(
    normalize_expression("GPL-2.0+ WITH Classpath-exception-2.0"),
    Ok("GPL-2.0-or-later WITH Classpath-exception-2.0"),
  )
}

///|
test "rejects unknown license and exception" {
  let unknown_license = parse_expression("Made-Up-1.0")
  assert_eq(unknown_license.unwrap_err().code(), "expression.license.unknown")
  let unknown_exception = parse_expression("GPL-2.0-only WITH Magic-exception")
  assert_eq(
    unknown_exception.unwrap_err().code(),
    "expression.exception.unknown",
  )
}

///|
test "rejects malformed operator sequences" {
  assert_eq(
    parse_expression("MIT AND").unwrap_err().code(),
    "expression.operand.missing",
  )
  assert_eq(
    parse_expression("MIT Apache-2.0").unwrap_err().code(),
    "expression.operator.missing",
  )
  assert_eq(
    parse_expression("(MIT OR Apache-2.0").unwrap_err().code(),
    "expression.parenthesis.unclosed",
  )
  assert_eq(
    parse_expression("MIT)").unwrap_err().code(),
    "expression.parenthesis.unexpected",
  )
}

///|
test "WITH cannot attach to a compound expression" {
  assert_eq(
    parse_expression("(GPL-2.0-only OR MIT) WITH Classpath-exception-2.0")
    .unwrap_err()
    .code(),
    "expression.with.composite",
  )
}

///|
test "catalog exposes the bounded semantic atom profile" {
  assert_eq(known_license_ids().length(), 44)
  assert_eq(known_exception_ids().length(), 10)
  assert_true(is_known_exception("LLVM-exception"))
}
