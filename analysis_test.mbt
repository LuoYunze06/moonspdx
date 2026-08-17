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
