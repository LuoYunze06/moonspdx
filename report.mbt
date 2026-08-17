///|
fn join_text(values : Array[String], separator : String) -> String {
  let output = StringBuilder::new()
  for index, value in values {
    if index > 0 {
      output.write_string(separator)
    }
    output.write_string(value)
  }
  output.to_string()
}

///|
fn escape_json(value : String) -> String {
  let output = StringBuilder::new()
  for char in value {
    match char {
      '"' => output.write_string("\\\"")
      '\\' => output.write_string("\\\\")
      '\n' => output.write_string("\\n")
      '\r' => output.write_string("\\r")
      '\t' => output.write_string("\\t")
      other => output.write_char(other)
    }
  }
  output.to_string()
}

///|
fn quote_json(value : String) -> String {
  "\"" + escape_json(value) + "\""
}

///|
fn bool_json(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
fn strings_json(values : Array[String]) -> String {
  let output = StringBuilder::new()
  output.write_char('[')
  for index, value in values {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string(quote_json(value))
  }
  output.write_char(']')
  output.to_string()
}

///|
pub fn ExpressionStats::to_text(self : ExpressionStats) -> String {
  "atoms=" +
  self.atoms.to_string() +
  " and=" +
  self.and_operators.to_string() +
  " or=" +
  self.or_operators.to_string() +
  " depth=" +
  self.depth.to_string() +
  " alternatives=" +
  (if self.alternatives > 64 { ">64" } else { self.alternatives.to_string() })
}
