///|
test "ROBDD proves commutativity and distributivity" {
  let commutative = prove_equivalent(
    parse_expression("MIT AND Apache-2.0").unwrap(),
    parse_expression("Apache-2.0 AND MIT").unwrap(),
  )
  assert_true(commutative.holds())
  assert_eq(commutative.counterexample(), None)
  let distributive = prove_equivalent(
    parse_expression("MIT AND (Apache-2.0 OR BSD-3-Clause)").unwrap(),
    parse_expression("MIT AND Apache-2.0 OR MIT AND BSD-3-Clause").unwrap(),
  )
  assert_true(distributive.holds())
}

///|
test "ROBDD proves associativity and absorption" {
  assert_true(
    prove_equivalent(
      parse_expression("MIT OR (Apache-2.0 OR BSD-3-Clause)").unwrap(),
      parse_expression("(MIT OR Apache-2.0) OR BSD-3-Clause").unwrap(),
    ).holds(),
  )
  assert_true(
    prove_equivalent(
      parse_expression("MIT OR MIT AND Apache-2.0").unwrap(),
      parse_expression("MIT").unwrap(),
    ).holds(),
  )
}

///|
test "equivalence failure returns a replayable minimum witness" {
  let left = parse_expression("MIT OR Apache-2.0").unwrap()
  let right = parse_expression("MIT AND Apache-2.0").unwrap()
  let proof = prove_equivalent(left, right)
  assert_false(proof.holds())
  let witness = proof.counterexample().unwrap()
  assert_eq(witness.true_count(), 1)
  assert_true(left.evaluate_assignment(witness))
  assert_false(right.evaluate_assignment(witness))
  assert_true(proof.to_json().contains("\"counterexample\""))
}

///|
test "implication proof distinguishes valid and invalid claims" {
  let conjunction = parse_expression("MIT AND Apache-2.0").unwrap()
  let mit = parse_expression("MIT").unwrap()
  assert_true(prove_implication(conjunction, mit).holds())
  let invalid = prove_implication(mit, conjunction)
  assert_false(invalid.holds())
  let witness = invalid.counterexample().unwrap()
  assert_true(mit.evaluate_assignment(witness))
  assert_false(conjunction.evaluate_assignment(witness))
}

///|
test "semantic fingerprint is source-order independent" {
  let first = semantic_summary(
    parse_expression("MIT OR Apache-2.0 AND BSD-3-Clause").unwrap(),
  )
  let second = semantic_summary(
    parse_expression("BSD-3-Clause AND Apache-2.0 OR MIT").unwrap(),
  )
  assert_eq(first.fingerprint(), second.fingerprint())
  assert_eq(first.variables(), ["Apache-2.0", "BSD-3-Clause", "MIT"])
  assert_true(first.decision_nodes() > 0)
}

///|
test "WITH expressions are independent semantic atoms" {
  let plain = parse_expression("GPL-2.0-only").unwrap()
  let excepted = parse_expression("GPL-2.0-only WITH Classpath-exception-2.0").unwrap()
  let proof = prove_equivalent(plain, excepted)
  assert_false(proof.holds())
  assert_eq(proof.variables().length(), 2)
}

///|
test "truth table enumerates deterministic false-first rows" {
  let expression = parse_expression("MIT OR Apache-2.0").unwrap()
  let table = truth_table(expression).unwrap()
  assert_eq(table.rows().length(), 4)
  assert_false(table.rows()[0].result())
  assert_true(table.rows()[1].result())
  assert_true(table.to_json().contains("\"rows\""))
}

///|
test "truth table enforces variable safety limit" {
  let source = "0BSD OR AFL-3.0 OR AGPL-3.0-only OR Apache-2.0 OR Artistic-2.0 OR BSD-2-Clause OR BSD-3-Clause OR BSL-1.0 OR CC0-1.0 OR EPL-2.0 OR ISC"
  assert_eq(
    truth_table(parse_expression(source).unwrap()).unwrap_err().code(),
    "semantic.table.limit",
  )
}

///|
test "semantic CLI exposes proof verdicts and counterexamples" {
  let proven = execute([
    "equivalent", "--left", "MIT AND Apache-2.0", "--right", "Apache-2.0 AND MIT",
  ])
  assert_eq(proven.exit_code(), 0)
  assert_true(proven.output().contains("holds=true"))
  let disproven = execute([
    "implies", "--premise", "MIT", "--conclusion", "Apache-2.0", "--json",
  ])
  assert_eq(disproven.exit_code(), 1)
  assert_true(disproven.output().contains("\"holds\":false"))
  assert_true(disproven.output().contains("\"counterexample\""))
}

///|
test "semantic CLI renders models, tables, and usage errors" {
  assert_eq(
    execute(["model", "--expression", "MIT AND Apache-2.0"]).exit_code(),
    0,
  )
  assert_true(
    execute(["fingerprint", "--expression", "MIT OR Apache-2.0"])
    .output()
    .contains("FINGERPRINT"),
  )
  assert_true(
    execute(["truth-table", "--expression", "MIT"]).output().contains("rows=2"),
  )
  assert_eq(execute(["equivalent", "--left", "MIT"]).exit_code(), 2)
}
