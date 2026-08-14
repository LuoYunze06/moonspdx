///|
test "canonicalizes expressions inside inventory" {
  let source = "app|1|MIT OR (Apache-2.0 AND BSD-3-Clause)\nengine|2|GPL-2.0+"
  assert_eq(
    canonical_inventory(source),
    Ok("app|1|MIT OR Apache-2.0 AND BSD-3-Clause\nengine|2|GPL-2.0-or-later"),
  )
}

///|
test "queries inventory by license and obligation" {
  let index = compile_inventory(
    "app|1|MIT OR Apache-2.0\nengine|2|GPL-3.0-only\ndata|1|CC0-1.0",
  ).unwrap()
  assert_eq(index.using_license("MIT").unwrap().length(), 1)
  assert_eq(
    index.using_license("Made-Up-1.0").unwrap_err().code(),
    "query.license.unknown",
  )
  assert_eq(index.requiring("disclose-source").unwrap()[0].name(), "engine")
  assert_eq(
    index.requiring("pay-royalties").unwrap_err().code(),
    "query.obligation.unknown",
  )
  assert_eq(index.find("data").unwrap().version(), "1")
  assert_true(index.find("missing") is None)
}

///|
test "queries inventory by license family" {
  let index = compile_inventory(
    "app|1|MIT\nengine|2|GPL-3.0-only\nlib|1|MPL-2.0",
  ).unwrap()
  assert_eq(index.using_family_name("strong-copyleft").unwrap().length(), 1)
  assert_eq(index.using_family_name("weak-copyleft").unwrap().length(), 1)
  assert_eq(index.using_family_name("permissive").unwrap().length(), 1)
}

///|
test "query results have stable reports" {
  let components = parse_inventory("app|1|MIT\nlib|2|Apache-2.0").unwrap()
  let result = QueryResult::new("family=permissive", components)
  assert_true(result.to_text().contains("matches=2"))
  assert_true(result.to_json().contains("\"query\":\"family=permissive\""))
}
