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
pub fn Obligations::to_text(self : Obligations) -> String {
  let values = self.names()
  if values.is_empty() {
    "none"
  } else {
    join_text(values, ",")
  }
}

///|
pub fn Obligations::to_json(self : Obligations) -> String {
  strings_json(self.names())
}

///|
pub fn Evaluation::to_text(self : Evaluation) -> String {
  let output = StringBuilder::new()
  output.write_string(
    self.status_name() +
    " selected=" +
    self.selected +
    " obligations=" +
    self.obligations.to_text(),
  )
  if !self.reasons.is_empty() {
    output.write_string(" reasons=" + join_text(self.reasons, "; "))
  }
  output.to_string()
}

///|
pub fn Evaluation::to_json(self : Evaluation) -> String {
  "{" +
  "\"status\":" +
  quote_json(self.status_name()) +
  ",\"selected\":" +
  quote_json(self.selected) +
  ",\"obligations\":" +
  self.obligations.to_json() +
  ",\"reasons\":" +
  strings_json(self.reasons) +
  "}"
}

///|
pub fn AuditReport::to_text(self : AuditReport) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "MOONSPDX components=" +
    self.results.length().to_string() +
    " accepted=" +
    self.accepted.to_string() +
    " review=" +
    self.review_count.to_string() +
    " rejected=" +
    self.rejected_count.to_string(),
  )
  for result in self.results {
    output.write_string(
      "\n" +
      result.component.name +
      "@" +
      result.component.version +
      " " +
      result.evaluation.to_text(),
    )
  }
  output.write_string("\nOBLIGATIONS " + self.obligations.to_text())
  output.to_string()
}

///|
pub fn AuditReport::to_json(self : AuditReport) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "{\"accepted\":" +
    bool_json(self.accepted) +
    ",\"review_count\":" +
    self.review_count.to_string() +
    ",\"rejected_count\":" +
    self.rejected_count.to_string() +
    ",\"obligations\":" +
    self.obligations.to_json() +
    ",\"components\":[",
  )
  for index, result in self.results {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string(
      "{\"name\":" +
      quote_json(result.component.name) +
      ",\"version\":" +
      quote_json(result.component.version) +
      ",\"expression\":" +
      quote_json(result.component.expression) +
      ",\"evaluation\":" +
      result.evaluation.to_json() +
      "}",
    )
  }
  output.write_string("]}")
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
