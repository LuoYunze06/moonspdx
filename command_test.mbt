///|
test "CLI normalizes and inspects expressions" {
  assert_eq(
    execute([
      "normalize", "--expression", "MIT OR (Apache-2.0 AND BSD-3-Clause)",
    ]).output(),
    "MIT OR Apache-2.0 AND BSD-3-Clause",
  )
  let inspected = execute(["inspect", "--expression", "MIT OR Apache-2.0"])
  assert_eq(inspected.exit_code(), 0)
  assert_true(inspected.output().contains("alternatives=2"))
}

///|
test "CLI evaluates preference and denial policy" {
  let result = execute([
    "evaluate", "--expression", "MIT OR Apache-2.0", "--policy", "prefer=Apache-2.0,MIT",
  ])
  assert_eq(result.exit_code(), 0)
  assert_true(result.output().contains("selected=Apache-2.0"))
  let denied = execute([
    "evaluate", "--expression", "GPL-3.0-only", "--policy", "deny=GPL-3.0-only",
  ])
  assert_eq(denied.exit_code(), 1)
}

///|
test "CLI audits escaped multiline inventory" {
  let result = execute([
    "audit", "--inventory", "app|1.0|MIT\\nengine|2.0|Apache-2.0", "--policy", "require-osi=true",
    "--json",
  ])
  assert_eq(result.exit_code(), 0)
  assert_true(result.output().contains("\"accepted\":true"))
}

///|
test "CLI rejects invalid options and input" {
  assert_eq(execute(["normalize"]).exit_code(), 2)
  assert_eq(
    execute(["normalize", "--expression", "Made-Up-1.0"]).exit_code(),
    2,
  )
  assert_eq(execute(["unknown"]).exit_code(), 2)
}

///|
test "CLI reports inventory drift and policy coverage" {
  let drift = execute([
    "diff", "--before", "app|1|MIT", "--after", "app|2|Apache-2.0\\nnew|1|ISC",
  ])
  assert_eq(drift.exit_code(), 0)
  assert_true(drift.output().contains("added=1"))
  assert_true(drift.output().contains("license_changed=1"))
  let matrix = execute([
    "matrix", "--policy", "require-osi=true\\ndeny=GPL-3.0-only", "--json",
  ])
  assert_eq(matrix.exit_code(), 0)
  assert_true(matrix.output().contains("\"rejected\":1"))
}

///|
test "CLI summarizes inventory and produces notice checklist" {
  let inventory = "app|1|MIT\\nengine|2|Apache-2.0"
  let summary = execute(["summary", "--inventory", inventory])
  assert_eq(summary.exit_code(), 0)
  assert_true(summary.output().contains("unique_licenses=2"))
  let notices = execute([
    "notices", "--inventory", inventory, "--policy", "require-osi=true",
  ])
  assert_eq(notices.exit_code(), 0)
  assert_true(notices.output().contains("NOTICE-PLAN components=2"))
}

///|
test "CLI queries and canonicalizes inventory" {
  let inventory = "app|1|MIT OR (Apache-2.0 AND BSD-3-Clause)\\nengine|2|GPL-2.0+"
  let query = execute([
    "query", "--inventory", inventory, "--license", "Apache-2.0",
  ])
  assert_eq(query.exit_code(), 0)
  assert_true(query.output().contains("matches=1"))
  let canonical = execute(["canonical-inventory", "--inventory", inventory])
  assert_eq(canonical.exit_code(), 0)
  assert_true(canonical.output().contains("GPL-2.0-or-later"))
}
