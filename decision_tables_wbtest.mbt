///|
test "tables: unique triples reuse IDs and reduced branches allocate nothing" {
  let e = parse_expression("MIT OR Apache-2.0").unwrap()
  let m = new_decision_manager([e], SemanticLimits::default()).unwrap()
  let x = make_node(m, 0, 0, 1)
  assert_eq(make_node(m, 0, 0, 1), x)
  assert_eq(make_node(m, 1, x, x), x)
  assert_eq(m.nodes.length(), 1)
  assert_eq(m.unique.length(), 1)
}

///|
test "tables: commutative keys are shared without mixing operators" {
  let e = parse_expression("MIT OR Apache-2.0").unwrap()
  let m = new_decision_manager([e], SemanticLimits::default()).unwrap()
  let a = make_node(m, 0, 0, 1)
  let b = make_node(m, 1, 0, 1)
  let memo = Map::Map([])
  let both = apply_decisions(m, BooleanAnd, a, b, memo)
  let size = memo.length()
  let operations = m.operations[0]
  assert_eq(apply_decisions(m, BooleanAnd, b, a, memo), both)
  assert_eq(memo.length(), size)
  assert_eq(m.operations[0] - operations, 2)
  let either = apply_decisions(m, BooleanOr, a, b, memo)
  let xor = apply_decisions(m, BooleanXor, a, b, memo)
  assert_true(both != either && either != xor && both != xor)
  assert_eq(apply_decisions(m, BooleanAnd, a, a, memo), a)
  assert_eq(apply_decisions(m, BooleanOr, 1, a, memo), 1)
  assert_eq(apply_decisions(m, BooleanXor, a, a, memo), 0)
  assert_eq(apply_decisions(m, BooleanXor, 0, a, memo), a)
}

///|
test "tables: complement and restriction keys preserve canonical roots" {
  let e = parse_expression("Apache-2.0 AND MIT").unwrap()
  let m = new_decision_manager([e], SemanticLimits::default()).unwrap()
  let root = compile_decision(m, e, Map::Map([]))
  let complements = Map::Map([])
  let negated = complement_decision(m, root, complements)
  assert_eq(complement_decision(m, negated, complements), root)
  let restrictions = Map::Map([])
  assert_eq(restrict_decision(m, root, 0, false, restrictions), 0)
  let a = restrict_decision(m, root, 0, true, restrictions)
  let b = restrict_decision(m, root, 1, true, restrictions)
  assert_true(a != b && a >= 2 && b >= 2)
  assert_eq(restrict_decision(m, a, 1, true, restrictions), 1)
}

///|
test "tables: exhausted managers stay failed without caching partial results" {
  let e = parse_expression("Apache-2.0 AND MIT").unwrap()
  let m = new_decision_manager([e], SemanticLimits::new(32, 1, 1000).unwrap()).unwrap()
  let memo = Map::Map([])
  let _ = compile_decision(m, e, memo)
  assert_eq(semantic_budget_error(m).unwrap().code(), "semantic.node.limit")
  assert_eq(m.nodes.length(), 1)
  assert_eq(memo.length(), 0)
  let operations = m.operations[0]
  let _ = compile_decision(m, e, memo)
  assert_eq(m.operations[0], operations)
  assert_eq(memo.length(), 0)
  // No process-global cache: a new proof after failure remains independent.
  assert_true(prove_equivalent(e, e).unwrap().holds())
}

///|
test "maintenance: exact counted-operation boundary returns error not false proof" {
  let left = parse_expression("MIT OR Apache-2.0").unwrap()
  let right = parse_expression("MIT AND Apache-2.0").unwrap()
  let proof = prove_equivalent(left, right).unwrap()
  let exact = SemanticLimits::new(32, 4096, proof.operations()).unwrap()
  assert_eq(prove_equivalent_with_limits(left, right, exact).unwrap(), proof)
  let small = SemanticLimits::new(32, 4096, proof.operations() - 1).unwrap()
  assert_eq(
    prove_equivalent_with_limits(left, right, small).unwrap_err().code(),
    "semantic.operation.limit",
  )
}

///|
test "maintenance: twelve-atom reverse conjunction fits a 1000-operation budget" {
  let atoms = known_license_ids()
  let left = StringBuilder()
  let right = StringBuilder()
  for i = 0; i < 12; i = i + 1 {
    if i > 0 {
      left.write_string(" AND ")
      right.write_string(" AND ")
    }
    left.write_string(atoms[i])
    right.write_string(atoms[11 - i])
  }
  let proof = prove_equivalent_with_limits(
    parse_expression(left.to_string()).unwrap(),
    parse_expression(right.to_string()).unwrap(),
    SemanticLimits::new(32, 4096, 1000).unwrap(),
  ).unwrap()
  assert_true(proof.holds())
  assert_eq(proof.operations(), 498)
}
