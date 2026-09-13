///|
// Independent corpus construction: no BDD internals are used by the oracle.
fn maintenance_variables() -> Array[String] {
  [
    "Apache-2.0", "BSD-3-Clause", "ISC", "MIT", "MPL-2.0", "GPL-2.0-only WITH Classpath-exception-2.0",
  ]
}

///|
fn maintenance_formulas() -> Array[Expression] {
  let atoms = maintenance_variables()
  let formulas = []
  for i = 0; i < 24; i = i + 1 {
    let a = atoms[i % 6]
    let b = atoms[(i * 3 + 1) % 6]
    let c = atoms[(i * 5 + 2) % 6]
    let source = match i / 6 {
      0 => a + " AND (" + b + " OR " + c + ")"
      1 => a + " OR (" + b + " AND " + c + ")"
      2 => "(" + a + " OR " + b + ") AND (" + a + " OR " + c + ")"
      _ => a + " OR (" + a + " AND " + b + ") OR " + c
    }
    formulas.push(parse_expression(source).unwrap())
  }
  formulas
}

///|
test "maintenance: 576 pairs match all 64 AST assignments and minimum witnesses" {
  let formulas = maintenance_formulas()
  let assignments = oracle_assignments(maintenance_variables())
  assert_eq(formulas.length(), 24)
  assert_eq(assignments.length(), 64)
  for left in formulas {
    for right in formulas {
      let mut equivalence_min = 1000000
      let mut implication_min = 1000000
      for assignment in assignments {
        let l = left.evaluate_assignment(assignment)
        let r = right.evaluate_assignment(assignment)
        let cost = assignment.true_count()
        if l != r && cost < equivalence_min {
          equivalence_min = cost
        }
        if l && !r && cost < implication_min {
          implication_min = cost
        }
      }
      let equivalent = prove_equivalent(left, right).unwrap()
      let implication = prove_implication(left, right).unwrap()
      assert_eq(equivalent.holds(), equivalence_min == 1000000)
      assert_eq(implication.holds(), implication_min == 1000000)
      match equivalent.counterexample() {
        Some(w) => {
          assert_eq(w.true_count(), equivalence_min)
          assert_true(
            left.evaluate_assignment(w) != right.evaluate_assignment(w),
          )
        }
        None => assert_true(equivalent.holds())
      }
      match implication.counterexample() {
        Some(w) => {
          assert_eq(w.true_count(), implication_min)
          assert_true(
            left.evaluate_assignment(w) && !right.evaluate_assignment(w),
          )
        }
        None => assert_true(implication.holds())
      }
    }
  }
}

///|
test "maintenance: influence agrees with exhaustive atom flips including WITH" {
  let assignments = oracle_assignments(maintenance_variables())
  for formula in maintenance_formulas() {
    let report = analyze_influence(formula).unwrap()
    for influence in report.influences() {
      let mut relevant = false
      for assignment in assignments {
        let off = assignment_overriding(assignment, influence.atom(), false)
        let on = assignment_overriding(assignment, influence.atom(), true)
        if formula.evaluate_assignment(off) != formula.evaluate_assignment(on) {
          relevant = true
        }
      }
      assert_eq(influence.relevant(), relevant)
      if relevant {
        let off = influence.when_false().unwrap()
        let on = influence.when_true().unwrap()
        assert_eq(formula.evaluate_assignment(off), influence.false_result())
        assert_eq(formula.evaluate_assignment(on), influence.true_result())
        assert_true(influence.false_result() != influence.true_result())
      }
    }
  }
}
