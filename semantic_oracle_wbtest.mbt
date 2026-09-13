///|
fn oracle_assignments(variables : Array[String]) -> Array[TruthAssignment] {
  let assignments : Array[TruthAssignment] = []
  let combinations = 1 << variables.length()
  for mask = 0; mask < combinations; mask = mask + 1 {
    let values : Array[TruthValue] = []
    for index, atom in variables {
      values.push({ atom, value: (mask & (1 << index)) != 0, })
    }
    assignments.push({ values, })
  }
  assignments
}

///|
fn oracle_equivalent(
  left : Expression,
  right : Expression,
  assignments : Array[TruthAssignment],
) -> Bool {
  for assignment in assignments {
    if left.evaluate_assignment(assignment) !=
      right.evaluate_assignment(assignment) {
      return false
    }
  }
  true
}

///|
fn oracle_implies(
  left : Expression,
  right : Expression,
  assignments : Array[TruthAssignment],
) -> Bool {
  for assignment in assignments {
    if left.evaluate_assignment(assignment) &&
      !right.evaluate_assignment(assignment) {
      return false
    }
  }
  true
}

///|
fn oracle_minimum_difference(
  left : Expression,
  right : Expression,
  assignments : Array[TruthAssignment],
) -> Int {
  let mut minimum = 1000000
  for assignment in assignments {
    if left.evaluate_assignment(assignment) !=
      right.evaluate_assignment(assignment) &&
      assignment.true_count() < minimum {
      minimum = assignment.true_count()
    }
  }
  minimum
}

///|
fn oracle_formulas() -> Array[Expression] {
  [
    parse_expression("MIT AND (Apache-2.0 OR BSD-3-Clause)").unwrap(),
    parse_expression("MIT OR Apache-2.0 AND BSD-3-Clause").unwrap(),
    parse_expression("(MIT OR Apache-2.0) AND BSD-3-Clause").unwrap(),
    parse_expression("MIT AND Apache-2.0 OR MIT AND BSD-3-Clause").unwrap(),
    parse_expression("MIT OR Apache-2.0 OR BSD-3-Clause").unwrap(),
    parse_expression("MIT AND Apache-2.0 AND BSD-3-Clause").unwrap(),
    parse_expression("MIT OR MIT AND Apache-2.0 OR BSD-3-Clause").unwrap(),
    parse_expression("MIT AND (Apache-2.0 OR MIT) AND BSD-3-Clause").unwrap(),
    parse_expression("(MIT AND Apache-2.0) OR (BSD-3-Clause AND MIT)").unwrap(),
    parse_expression("(MIT OR BSD-3-Clause) AND (Apache-2.0 OR BSD-3-Clause)").unwrap(),
  ]
}

///|
test "ROBDD equivalence and implication match exhaustive AST semantics" {
  let formulas = oracle_formulas()
  let assignments = oracle_assignments(["Apache-2.0", "BSD-3-Clause", "MIT"])
  for left in formulas {
    for right in formulas {
      let equivalent = prove_equivalent(left, right).unwrap()
      let implication = prove_implication(left, right).unwrap()
      assert_eq(equivalent.holds(), oracle_equivalent(left, right, assignments))
      assert_eq(implication.holds(), oracle_implies(left, right, assignments))
    }
  }
}

///|
test "ROBDD equivalence witnesses have globally minimum true count" {
  let formulas = oracle_formulas()
  let assignments = oracle_assignments(["Apache-2.0", "BSD-3-Clause", "MIT"])
  for left in formulas {
    for right in formulas {
      let proof = prove_equivalent(left, right).unwrap()
      match proof.counterexample() {
        Some(witness) => {
          assert_eq(
            witness.true_count(),
            oracle_minimum_difference(left, right, assignments),
          )
          assert_true(
            left.evaluate_assignment(witness) !=
            right.evaluate_assignment(witness),
          )
        }
        None => assert_true(oracle_equivalent(left, right, assignments))
      }
    }
  }
}
