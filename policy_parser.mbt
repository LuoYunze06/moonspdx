///|
fn parse_bool(value : String, key : String) -> Result[Bool, Diagnostic] {
  match value {
    "true" => Ok(true)
    "false" => Ok(false)
    _ =>
      Err(
        Diagnostic::new(
          "policy.boolean.invalid", key, "policy boolean must be lowercase true or false",
          "true or false", value,
        ),
      )
  }
}

///|
fn csv_values(
  value : String,
  key : String,
) -> Result[Array[String], Diagnostic] {
  if value.is_empty() {
    return Ok([])
  }
  let result = []
  for item in value.split(",") {
    let normalized = item.trim().to_owned()
    if normalized.is_empty() {
      return Err(
        Diagnostic::new(
          "policy.list.empty", key, "comma-separated policy list contains an empty value",
          "non-empty list item", value,
        ),
      )
    }
    if contains_string(result, normalized) {
      return Err(
        Diagnostic::new(
          "policy.list.duplicate", key, "policy list contains a duplicate value",
          "unique list values", normalized,
        ),
      )
    }
    result.push(normalized)
  }
  Ok(result)
}

///|
fn validate_policy_ids(
  ids : Array[String],
  key : String,
) -> Result[Unit, Diagnostic] {
  for id in ids {
    if lookup_license(id) is None {
      return Err(
        Diagnostic::new(
          "policy.license.unknown", key, "policy names a license outside the supported catalog",
          "supported SPDX license identifier", id,
        ),
      )
    }
  }
  Ok(())
}

///|
fn is_obligation_name(value : String) -> Bool {
  match value {
    "preserve-notices"
    | "preserve-attribution"
    | "disclose-source"
    | "same-license"
    | "network-source-offer"
    | "patent-notice" => true
    _ => false
  }
}

///|
fn validate_obligations(values : Array[String]) -> Result[Unit, Diagnostic] {
  for value in values {
    if !is_obligation_name(value) {
      return Err(
        Diagnostic::new(
          "policy.obligation.unknown", "require-obligations", "policy names an unsupported obligation",
          "documented obligation name", value,
        ),
      )
    }
  }
  Ok(())
}

///|
fn validate_policy(policy : Policy) -> Result[Policy, Diagnostic] {
  match validate_policy_ids(policy.allowed_ids, "allow") {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  match validate_policy_ids(policy.denied_ids, "deny") {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  match validate_policy_ids(policy.preferred_ids, "prefer") {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  match validate_obligations(policy.required_obligations) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  for id in policy.allowed_ids {
    if contains_string(policy.denied_ids, id) {
      return Err(
        Diagnostic::new(
          "policy.rule.conflict", "policy", "license appears in both allow and deny rules",
          "disjoint allow and deny lists", id,
        ),
      )
    }
  }
  for id in policy.preferred_ids {
    if contains_string(policy.denied_ids, id) {
      return Err(
        Diagnostic::new(
          "policy.preference.denied", "prefer", "preferred license is explicitly denied",
          "a policy-eligible preferred license", id,
        ),
      )
    }
  }
  Ok(policy)
}

///|
/// Parse line-oriented policy configuration. Lines use `key=value`.
pub fn parse_policy(source : String) -> Result[Policy, Diagnostic] {
  let mut require_osi = false
  let mut allowed : Array[String] = []
  let mut denied : Array[String] = []
  let mut preferred : Array[String] = []
  let mut required : Array[String] = []
  let seen = []
  let lines : Array[StringView] = source.split("\n").collect()
  let mut index = 0
  while index < lines.length() {
    let line = lines[index].trim().to_owned()
    if !line.is_empty() && !line.has_prefix("#") {
      let separator = match line.find("=") {
        Some(value) => value
        None =>
          return Err(
            Diagnostic::new(
              "policy.line.syntax",
              "line[" + index.to_string() + "]",
              "policy line has no equals sign",
              "key=value",
              line,
            ),
          )
      }
      let key = line[:separator].trim().to_owned()
      let value = line[separator + 1:].trim().to_owned()
      if key.is_empty() {
        return Err(
          Diagnostic::new(
            "policy.key.empty",
            "line[" + index.to_string() + "]",
            "policy key is empty",
            "supported policy key",
            line,
          ),
        )
      }
      if contains_string(seen, key) {
        return Err(
          Diagnostic::new(
            "policy.key.duplicate",
            "line[" + index.to_string() + "]",
            "policy key appears more than once",
            "one value per key",
            key,
          ),
        )
      }
      seen.push(key)
      match key {
        "require-osi" =>
          match parse_bool(value, key) {
            Ok(result) => require_osi = result
            Err(error) => return Err(error)
          }
        "allow" =>
          match csv_values(value, key) {
            Ok(result) => allowed = result
            Err(error) => return Err(error)
          }
        "deny" =>
          match csv_values(value, key) {
            Ok(result) => denied = result
            Err(error) => return Err(error)
          }
        "prefer" =>
          match csv_values(value, key) {
            Ok(result) => preferred = result
            Err(error) => return Err(error)
          }
        "require-obligations" =>
          match csv_values(value, key) {
            Ok(result) => required = result
            Err(error) => return Err(error)
          }
        _ =>
          return Err(
            Diagnostic::new(
              "policy.key.unknown",
              "line[" + index.to_string() + "]",
              "policy key is not supported",
              "require-osi, allow, deny, prefer, or require-obligations",
              key,
            ),
          )
      }
    }
    index = index + 1
  }
  validate_policy(
    Policy::new(
      require_osi~,
      allowed_ids=allowed,
      denied_ids=denied,
      preferred_ids=preferred,
      required_obligations=required,
    ),
  )
}

///|
pub fn Policy::canonical(self : Policy) -> String {
  let output = StringBuilder::new()
  output.write_string("require-osi=" + self.require_osi.to_string())
  output.write_string("\nallow=" + join_text(self.allowed_ids, ","))
  output.write_string("\ndeny=" + join_text(self.denied_ids, ","))
  output.write_string("\nprefer=" + join_text(self.preferred_ids, ","))
  output.write_string(
    "\nrequire-obligations=" + join_text(self.required_obligations, ","),
  )
  output.to_string()
}
