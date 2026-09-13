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
  { exit_code: 0, output, }
}

///|
fn command_disproven(output : String) -> CommandResult {
  { exit_code: 1, output, }
}

///|
fn command_error(output : String) -> CommandResult {
  { exit_code: 2, output, }
}

///|
pub let help_text =
  #|MoonSPDX 0.3.0
  #|Symbolic proofs and counterexamples for SPDX expression semantics.
  #|
  #|USAGE:
  #|  moonspdx equivalent  --left TEXT --right TEXT [--json]
  #|  moonspdx implies     --premise TEXT --conclusion TEXT [--json]
  #|  moonspdx fingerprint --expression TEXT [--json]
  #|  moonspdx model       --expression TEXT [--json]
  #|  moonspdx truth-table --expression TEXT [--json]
  #|  moonspdx verify      --claims TEXT [--json]
  #|  moonspdx compare     --left TEXT --right TEXT [--json]
  #|  moonspdx influence   --expression TEXT [--json]
  #|  moonspdx normalize   --expression TEXT
  #|  moonspdx inspect     --expression TEXT
  #|  moonspdx demo
  #|
  #|SEMANTICS: each SPDX license or WITH atom is a Boolean proposition.
  #|BUDGETS: semantic commands accept --max-variables N, --max-nodes N,
  #|         and --max-operations N.
  #|EXIT CODES: 0 proven/success, 1 disproven with witness, 2 invalid input.

///|
fn decode_cli_text(value : String) -> Result[String, CommandResult] {
  let output = StringBuilder()
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
fn optional_command_option(
  args : Array[String],
  name : String,
) -> Result[String?, CommandResult] {
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
  Ok(value)
}

///|
fn positive_integer_option(
  args : Array[String],
  name : String,
  fallback : Int,
) -> Result[Int, CommandResult] {
  let source = match optional_command_option(args, name) {
    Ok(Some(value)) => value
    Ok(None) => return Ok(fallback)
    Err(error) => return Err(error)
  }
  if source.is_empty() {
    return Err(command_error(name + " must be a positive decimal integer"))
  }
  let mut number = 0
  for char in source {
    if char < '0' || char > '9' || number > 100000000 {
      return Err(command_error(name + " must be a positive decimal integer"))
    }
    number = number * 10 + char.to_int() - '0'.to_int()
  }
  if number < 1 {
    Err(command_error(name + " must be a positive decimal integer"))
  } else {
    Ok(number)
  }
}

///|
fn semantic_limits_option(
  args : Array[String],
) -> Result[SemanticLimits, CommandResult] {
  let defaults = SemanticLimits::default()
  let variables = match
    positive_integer_option(args, "--max-variables", defaults.max_variables()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let nodes = match
    positive_integer_option(args, "--max-nodes", defaults.max_nodes()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let operations = match
    positive_integer_option(args, "--max-operations", defaults.max_operations()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match SemanticLimits::new(variables, nodes, operations) {
    Ok(value) => Ok(value)
    Err(error) => Err(command_error(error.to_text()))
  }
}

///|
fn has_flag(args : Array[String], flag : String) -> Bool {
  args.any(fn(value) { value == flag })
}

///|
fn command_contains(values : Array[String], target : String) -> Bool {
  values.any(fn(value) { value == target })
}

///|
fn validate_command_options(
  args : Array[String],
  value_options : Array[String],
  flags : Array[String],
) -> Result[Unit, CommandResult] {
  let seen : Array[String] = []
  let mut index = 1
  while index < args.length() {
    let option = args[index]
    if command_contains(value_options, option) {
      if command_contains(seen, option) {
        return Err(command_error("duplicate option " + option))
      }
      if index + 1 >= args.length() {
        return Err(command_error("missing value for " + option))
      }
      seen.push(option)
      index = index + 2
    } else if command_contains(flags, option) {
      if command_contains(seen, option) {
        return Err(command_error("duplicate flag " + option))
      }
      seen.push(option)
      index = index + 1
    } else {
      return Err(command_error("unknown option or argument: " + option))
    }
  }
  Ok(())
}

///|
fn semantic_budget_options() -> Array[String] {
  ["--max-variables", "--max-nodes", "--max-operations"]
}

///|
fn command_schema(args : Array[String]) -> Result[Unit, CommandResult] {
  let budgets = semantic_budget_options()
  match args[0] {
    "equivalent" | "compare" =>
      validate_command_options(args, ["--left", "--right"] + budgets, ["--json"])
    "implies" =>
      validate_command_options(args, ["--premise", "--conclusion"] + budgets, [
        "--json",
      ])
    "fingerprint" | "model" | "influence" =>
      validate_command_options(args, ["--expression"] + budgets, ["--json"])
    "inspect" => validate_command_options(args, ["--expression"] + budgets, [])
    "truth-table" =>
      validate_command_options(args, ["--expression"], ["--json"])
    "verify" =>
      validate_command_options(args, ["--claims"] + budgets, ["--json"])
    "normalize" => validate_command_options(args, ["--expression"], [])
    "demo" | "help" | "--help" | "-h" => validate_command_options(args, [], [])
    _ => Ok(())
  }
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
  let limits = match semantic_limits_option(args) {
    Ok(value) => value
    Err(error) => return error
  }
  let left = match named_expression_option(args, "--left") {
    Ok(value) => value
    Err(error) => return error
  }
  let right = match named_expression_option(args, "--right") {
    Ok(value) => value
    Err(error) => return error
  }
  let proof = match prove_equivalent_with_limits(left, right, limits) {
    Ok(value) => value
    Err(error) => return command_error(error.to_text())
  }
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
  let limits = match semantic_limits_option(args) {
    Ok(value) => value
    Err(error) => return error
  }
  let premise = match named_expression_option(args, "--premise") {
    Ok(value) => value
    Err(error) => return error
  }
  let conclusion = match named_expression_option(args, "--conclusion") {
    Ok(value) => value
    Err(error) => return error
  }
  let proof = match prove_implication_with_limits(premise, conclusion, limits) {
    Ok(value) => value
    Err(error) => return command_error(error.to_text())
  }
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
  let limits = match semantic_limits_option(args) {
    Ok(value) => value
    Err(error) => return error
  }
  let expression = match expression_option(args) {
    Ok(value) => value
    Err(error) => return error
  }
  let summary = match semantic_summary_with_limits(expression, limits) {
    Ok(value) => value
    Err(error) => return command_error(error.to_text())
  }
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
  let limits = match semantic_limits_option(args) {
    Ok(value) => value
    Err(error) => return error
  }
  let source = match command_option(args, "--claims") {
    Ok(value) => value
    Err(error) => return error
  }
  let suite = match verify_claims_with_limits(source, limits) {
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
fn comparison_command(args : Array[String]) -> CommandResult {
  let limits = match semantic_limits_option(args) {
    Ok(value) => value
    Err(error) => return error
  }
  let left = match named_expression_option(args, "--left") {
    Ok(value) => value
    Err(error) => return error
  }
  let right = match named_expression_option(args, "--right") {
    Ok(value) => value
    Err(error) => return error
  }
  let comparison = match compare_semantics_with_limits(left, right, limits) {
    Ok(value) => value
    Err(error) => return command_error(error.to_text())
  }
  command_ok(
    if has_flag(args, "--json") {
      comparison.to_json()
    } else {
      comparison.to_text()
    },
  )
}

///|
fn influence_command(args : Array[String]) -> CommandResult {
  let limits = match semantic_limits_option(args) {
    Ok(value) => value
    Err(error) => return error
  }
  let expression = match expression_option(args) {
    Ok(value) => value
    Err(error) => return error
  }
  let report = match analyze_influence_with_limits(expression, limits) {
    Ok(value) => value
    Err(error) => return command_error(error.to_text())
  }
  command_ok(
    if has_flag(args, "--json") {
      report.to_json()
    } else {
      report.to_text()
    },
  )
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
  let limits = match semantic_limits_option(args) {
    Ok(value) => value
    Err(error) => return error
  }
  let expression = match expression_option(args) {
    Ok(value) => value
    Err(error) => return error
  }
  let summary = match semantic_summary_with_limits(expression, limits) {
    Ok(value) => value
    Err(error) => return command_error(error.to_text())
  }
  command_ok(summary.to_text())
}

///|
fn demo_command() -> CommandResult {
  let left = parse_expression("MIT AND (Apache-2.0 OR BSD-3-Clause)").unwrap()
  let right = parse_expression("MIT AND Apache-2.0 OR MIT AND BSD-3-Clause").unwrap()
  match prove_equivalent(left, right) {
    Ok(value) => command_ok(value.to_text())
    Err(error) => command_error(error.to_text())
  }
}

///|
pub fn execute(args : Array[String]) -> CommandResult {
  if args.is_empty() {
    return command_ok(help_text)
  }
  match command_schema(args) {
    Err(error) => return error
    Ok(_) => ()
  }
  match args[0] {
    "help" | "--help" | "-h" => command_ok(help_text)
    "equivalent" => equivalent_command(args)
    "implies" => implication_command(args)
    "fingerprint" => semantic_summary_command(args, false)
    "model" => semantic_summary_command(args, true)
    "truth-table" => truth_table_command(args)
    "verify" => verify_command(args)
    "compare" => comparison_command(args)
    "influence" => influence_command(args)
    "normalize" => normalize_command(args)
    "inspect" => inspect_command(args)
    "demo" => demo_command()
    other => command_error("unknown command: " + other + "\n\n" + help_text)
  }
}
