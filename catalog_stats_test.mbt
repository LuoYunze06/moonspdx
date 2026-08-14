///|
test "catalog statistics account for every identifier" {
  let stats = catalog_stats()
  assert_eq(stats.licenses(), known_license_ids().length())
  assert_eq(stats.osi_approved() + stats.non_osi(), stats.licenses())
  assert_true(stats.permissive() > stats.strong_copyleft())
  assert_true(stats.weak_copyleft() > 0)
  assert_eq(stats.exceptions(), known_exception_ids().length())
  assert_true(stats.to_text().contains("CATALOG licenses=44"))
  assert_true(stats.to_json().contains("\"exceptions\":10"))
}

///|
test "exception catalog agrees with parser lookup" {
  for id in known_exception_ids() {
    assert_true(is_known_exception(id))
  }
  assert_true(!is_known_exception("Imaginary-exception"))
}
