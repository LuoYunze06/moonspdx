///|
test "claim parser accepts comments and both relations" {
  let claims = parse_claims(
    "# semantic laws\ncommute|equivalent|MIT AND Apache-2.0|Apache-2.0 AND MIT\nsubset|implies|MIT AND Apache-2.0|MIT",
  ).unwrap()
  assert_eq(claims.length(), 2)
  assert_eq(claims[0].name(), "commute")
  assert_eq(claims[0].relation().name(), "equivalent")
  assert_eq(claims[1].relation().name(), "implies")
}

///|
test "claim parser rejects malformed and duplicate records" {
  assert_eq(parse_claims("").unwrap_err().code(), "claim.empty")
  assert_eq(
    parse_claims("bad|equivalent|MIT").unwrap_err().code(),
    "claim.fields.invalid",
  )
  assert_eq(
    parse_claims("bad|unknown|MIT|MIT").unwrap_err().code(),
    "claim.relation.invalid",
  )
  assert_eq(
    parse_claims("same|equivalent|MIT|MIT\nsame|implies|MIT|MIT")
    .unwrap_err()
    .code(),
    "claim.name.duplicate",
  )
}

///|
test "claim parser wraps invalid expression diagnostics" {
  let error = parse_claims("bad|equivalent|Made-Up-1.0|MIT").unwrap_err()
  assert_eq(error.code(), "claim.expression.invalid")
  assert_true(error.message().contains("expression.license.unknown"))
}

///|
test "proof suite reports all proven claims" {
  let suite = verify_claims(
    "commute|equivalent|MIT OR Apache-2.0|Apache-2.0 OR MIT\nabsorb|equivalent|MIT OR MIT AND Apache-2.0|MIT\nsubset|implies|MIT AND Apache-2.0|MIT",
  ).unwrap()
  assert_true(suite.all_proven())
  assert_eq(suite.passed(), 3)
  assert_eq(suite.failed(), 0)
  assert_true(suite.to_text().contains("PROOF-SUITE claims=3"))
}

///|
test "proof suite retains a failed claim counterexample" {
  let suite = verify_claims("invalid-subset|implies|MIT|MIT AND Apache-2.0").unwrap()
  assert_false(suite.all_proven())
  assert_eq(suite.failed(), 1)
  let witness = suite.results()[0].proof().counterexample().unwrap()
  assert_eq(witness.true_count(), 1)
  assert_true(suite.to_text().contains("witness="))
  assert_true(suite.to_json().contains("\"all_proven\":false"))
}

///|
test "verify CLI gates suites with stable exit codes" {
  let passed = execute([
    "verify", "--claims", "commute|equivalent|MIT OR Apache-2.0|Apache-2.0 OR MIT\\nsubset|implies|MIT AND Apache-2.0|MIT",
  ])
  assert_eq(passed.exit_code(), 0)
  assert_true(passed.output().contains("passed=2 failed=0"))
  let failed = execute([
    "verify", "--claims", "bad|implies|MIT|Apache-2.0", "--json",
  ])
  assert_eq(failed.exit_code(), 1)
  assert_true(failed.output().contains("\"all_proven\":false"))
}

///|
test "proof suites propagate semantic budget diagnostics" {
  let limits = SemanticLimits::new(1, 100, 1000).unwrap()
  let error = verify_claims_with_limits(
    "wide|equivalent|MIT OR Apache-2.0|MIT", limits,
  ).unwrap_err()
  assert_eq(error.code(), "semantic.variable.limit")
}
