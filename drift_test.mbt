///|
test "diffs inventory additions removals and changes" {
  let before = "core|1.0|MIT\nold|1.0|BSD-2-Clause\nsame|2.0|Apache-2.0"
  let after = "core|2.0|Apache-2.0\nsame|2.0|Apache-2.0\nnew|1.0|ISC"
  let diff = diff_inventories(before, after).unwrap()
  assert_eq(diff.added(), 1)
  assert_eq(diff.removed(), 1)
  assert_eq(diff.version_changed(), 1)
  assert_eq(diff.license_changed(), 1)
  assert_eq(diff.unchanged(), 1)
  assert_true(diff.has_license_drift())
  assert_true(diff.to_text().contains("version-and-license-changed core"))
  assert_true(diff.to_json().contains("\"kind\":\"added\""))
}

///|
test "reports which side of a diff is invalid" {
  assert_eq(
    diff_inventories("bad", "app|1|MIT").unwrap_err().code(),
    "diff.before.invalid",
  )
  assert_eq(
    diff_inventories("app|1|MIT", "bad").unwrap_err().code(),
    "diff.after.invalid",
  )
}

///|
test "builds a complete policy matrix" {
  let matrix = policy_matrix(Policy::osi_only().with_denied(["GPL-3.0-only"]))
  assert_eq(matrix.decisions().length(), known_license_ids().length())
  assert_true(matrix.accepted() > 0)
  assert_true(matrix.review() > 0)
  assert_true(matrix.rejected() > 0)
  assert_true(matrix.to_text().contains("BUSL-1.1 review"))
  assert_true(matrix.to_json().contains("\"license\":\"MIT\""))
}
