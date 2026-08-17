///|
pub struct CommandResult {
  exit_code : Int
  output : String
} derive(Eq, @debug.Debug)

///|
pub fn CommandResult::exit_code(self : CommandResult) -> Int {
  self.exit_code
}

///|
pub fn CommandResult::output(self : CommandResult) -> String {
  self.output
}

///|
fn command_ok(output : String) -> CommandResult {
  { exit_code: 0, output }
}

///|
fn command_disproven(output : String) -> CommandResult {
  { exit_code: 1, output }
}

///|
fn command_error(output : String) -> CommandResult {
  { exit_code: 2, output }
}

///|
pub let help_text =
  #|MoonSPDX 0.2.0
  #|Symbolic proofs and counterexamples for SPDX expression semantics.
  #|
  #|USAGE:
  #|  moonspdx equivalent  --left TEXT --right TEXT [--json]
  #|  moonspdx implies     --premise TEXT --conclusion TEXT [--json]
  #|  moonspdx fingerprint --expression TEXT [--json]
  #|  moonspdx model       --expression TEXT [--json]
  #|  moonspdx truth-table --expression TEXT [--json]
  #|  moonspdx verify      --claims TEXT [--json]
  #|  moonspdx normalize   --expression TEXT
  #|  moonspdx inspect     --expression TEXT
  #|  moonspdx demo
  #|
  #|SEMANTICS: each SPDX license or WITH atom is a Boolean proposition.
  #|EXIT CODES: 0 proven/success, 1 disproven with witness, 2 invalid input.

///|
fn decode_cli_text(value : String) -> Result[String, CommandResult] {
  let output = StringBuilder::new()
  let mut escaping = false
  for char in value {
    if escaping {
      match char {
        'n' => output.write_char('\n')
        'r' => output.write_char('\r')
        't' => output.write_char('\t')
        '\\' => output.write_char('\\')
        other =>
          return Err(command_error("invalid escape: \\" + other.to_string()))
      }
      escaping = false
    } else if char == '\\' {
      escaping = true
    } else {
      output.write_char(char)
    }
  }
  if escaping {
    Err(command_error("trailing escape in text option"))
  } else {
    Ok(output.to_string())
  }
}

///|
fn command_option(
  args : Array[String],
  name : String,
) -> Result[String, CommandResult] {
  let mut value : String? = None
  let mut index = 1
  while index < args.length() {
    if args[index] == name {
      if value is Some(_) {
        return Err(command_error("duplicate option " + name))
      }
      if index + 1 >= args.length() {
        return Err(command_error("missing value for " + name))
      }
      value = Some(args[index + 1])
      index = index + 2
    } else {
      index = index + 1
    }
  }
  match value {
    Some(result) => decode_cli_text(result)
    None => Err(command_error("missing required option " + name))
  }
}

///|
fn has_flag(args : Array[String], flag : String) -> Bool {
  args.any(fn(value) { value == flag })
}

///|
fn named_expression_option(
  args : Array[String],
  name : String,
) -> Result[Expression, CommandResult] {
  let source = match command_option(args, name) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match parse_expression(source) {
    Ok(value) => Ok(value)
    Err(error) => Err(command_error(error.to_text()))
  }
}

///|
fn expression_option(args : Array[String]) -> Result[Expression, CommandResult] {
  named_expression_option(args, "--expression")
}

///|
fn equivalent_command(args : Array[String]) -> CommandResult {
  let left = match named_expression_option(args, "--left") {
    Ok(value) => value
    Err(error) => return error
  }
  let right = match named_expression_option(args, "--right") {
    Ok(value) => value
    Err(error) => return error
  }
  let proof = prove_equivalent(left, right)
  let output = if has_flag(args, "--json") {
    proof.to_json()
  } else {
    proof.to_text()
  }
  if proof.holds() {
    command_ok(output)
  } else {
    command_disproven(output)
  }
}

///|
fn implication_command(args : Array[String]) -> CommandResult {
  let premise = match named_expression_option(args, "--premise") {
    Ok(value) => value
    Err(error) => return error
  }
  let conclusion = match named_expression_option(args, "--conclusion") {
    Ok(value) => value
    Err(error) => return error
  }
  let proof = prove_implication(premise, conclusion)
  let output = if has_flag(args, "--json") {
    proof.to_json()
  } else {
    proof.to_text()
  }
  if proof.holds() {
    command_ok(output)
  } else {
    command_disproven(output)
  }
}

///|
fn semantic_summary_command(
  args : Array[String],
  model_only : Bool,
) -> CommandResult {
  let expression = match expression_option(args) {
    Ok(value) => value
    Err(error) => return error
  }
  let summary = semantic_summary(expression)
  if model_only {
    match summary.model() {
      Some(value) =>
        command_ok(
          if has_flag(args, "--json") {
            value.to_json()
          } else {
            "MODEL " + value.to_text()
          },
        )
      None => command_disproven("MODEL none")
    }
  } else {
    command_ok(
      if has_flag(args, "--json") {
        summary.to_json()
      } else {
        summary.to_text()
      },
    )
  }
}

///|
fn truth_table_command(args : Array[String]) -> CommandResult {
  let expression = match expression_option(args) {
    Ok(value) => value
    Err(error) => return error
  }
  let table = match truth_table(expression) {
    Ok(value) => value
    Err(error) => return command_error(error.to_text())
  }
  command_ok(
    if has_flag(args, "--json") {
      table.to_json()
    } else {
      table.to_text()
    },
  )
}

///|
fn verify_command(args : Array[String]) -> CommandResult {
  let source = match command_option(args, "--claims") {
    Ok(value) => value
    Err(error) => return error
  }
  let suite = match verify_claims(source) {
    Ok(value) => value
    Err(error) => return command_error(error.to_text())
  }
  let output = if has_flag(args, "--json") {
    suite.to_json()
  } else {
    suite.to_text()
  }
  if suite.all_proven() {
    command_ok(output)
  } else {
    command_disproven(output)
  }
}

///|
fn normalize_command(args : Array[String]) -> CommandResult {
  match expression_option(args) {
    Ok(expression) => command_ok(expression.canonical())
    Err(error) => error
  }
}

///|
fn inspect_command(args : Array[String]) -> CommandResult {
  let expression = match expression_option(args) {
    Ok(value) => value
    Err(error) => return error
  }
  let summary = semantic_summary(expression)
  command_ok(summary.to_text())
}

///|
fn demo_command() -> CommandResult {
  let left = parse_expression("MIT AND (Apache-2.0 OR BSD-3-Clause)").unwrap()
  let right = parse_expression("MIT AND Apache-2.0 OR MIT AND BSD-3-Clause").unwrap()
  command_ok(prove_equivalent(left, right).to_text())
}

///|
pub fn execute(args : Array[String]) -> CommandResult {
  if args.is_empty() {
    return command_ok(help_text)
  }
  match args[0] {
    "help" | "--help" | "-h" => command_ok(help_text)
    "equivalent" => equivalent_command(args)
    "implies" => implication_command(args)
    "fingerprint" => semantic_summary_command(args, false)
    "model" => semantic_summary_command(args, true)
    "truth-table" => truth_table_command(args)
    "verify" => verify_command(args)
    "normalize" => normalize_command(args)
    "inspect" => inspect_command(args)
    "demo" => demo_command()
    other => command_error("unknown command: " + other + "\n\n" + help_text)
  }
}
