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
