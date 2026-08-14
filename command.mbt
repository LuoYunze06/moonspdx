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
fn command_policy_failure(output : String) -> CommandResult {
  { exit_code: 1, output }
}

///|
fn command_error(output : String) -> CommandResult {
  { exit_code: 2, output }
}

///|
pub let help_text =
  #|MoonSPDX 0.1.0
  #|Deterministic SPDX expression and dependency license policy analysis.
  #|
  #|USAGE:
  #|  moonspdx normalize --expression TEXT
  #|  moonspdx inspect   --expression TEXT
  #|  moonspdx evaluate  --expression TEXT [--policy TEXT] [--json]
  #|  moonspdx audit     --inventory TEXT [--policy TEXT] [--json]
  #|  moonspdx diff      --before TEXT --after TEXT [--json]
  #|  moonspdx matrix    [--policy TEXT] [--json]
  #|  moonspdx summary   --inventory TEXT [--json]
  #|  moonspdx notices   --inventory TEXT [--policy TEXT] [--json]
  #|  moonspdx query     --inventory TEXT --license ID [--json]
  #|  moonspdx canonical-inventory --inventory TEXT
  #|  moonspdx catalog
  #|  moonspdx demo
  #|
  #|TEXT INPUT: encode newlines as \n and tabs as \t.
  #|POLICY: key=value lines for require-osi, allow, deny, prefer, and
  #|        require-obligations.
  #|INVENTORY: name|version|SPDX expression lines.
  #|EXIT CODES: 0 accepted, 1 policy rejection/review, 2 invalid input.

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
  match value {
    Some(result) =>
      match decode_cli_text(result) {
        Ok(decoded) => Ok(Some(decoded))
        Err(error) => Err(error)
      }
    None => Ok(None)
  }
}

///|
fn has_flag(args : Array[String], flag : String) -> Bool {
  args.any(fn(value) { value == flag })
}

///|
fn expression_option(args : Array[String]) -> Result[Expression, CommandResult] {
  let source = match command_option(args, "--expression") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match parse_expression(source) {
    Ok(value) => Ok(value)
    Err(error) => Err(command_error(error.to_text()))
  }
}

///|
fn policy_option(args : Array[String]) -> Result[Policy, CommandResult] {
  let source = match optional_command_option(args, "--policy") {
    Ok(Some(value)) => value
    Ok(None) => return Ok(Policy::permissive())
    Err(error) => return Err(error)
  }
  match parse_policy(source) {
    Ok(value) => Ok(value)
    Err(error) => Err(command_error(error.to_text()))
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
  let output = StringBuilder::new()
  output.write_string("EXPRESSION " + expression.canonical())
  output.write_string("\nSTATS " + expression.stats().to_text())
  let alternatives = match expression.alternatives() {
    Ok(value) => value
    Err(error) => return command_error(error.to_text())
  }
  for index, alternative in alternatives {
    output.write_string(
      "\nALTERNATIVE " +
      index.to_string() +
      " " +
      render_alternative(alternative),
    )
  }
  command_ok(output.to_string())
}

///|
fn evaluate_command(args : Array[String]) -> CommandResult {
  let expression = match expression_option(args) {
    Ok(value) => value
    Err(error) => return error
  }
  let policy = match policy_option(args) {
    Ok(value) => value
    Err(error) => return error
  }
  let result = evaluate(expression, policy)
  let output = if has_flag(args, "--json") {
    result.to_json()
  } else {
    result.to_text()
  }
  if result.status() == Accepted {
    command_ok(output)
  } else {
    command_policy_failure(output)
  }
}

///|
fn audit_command(args : Array[String]) -> CommandResult {
  let source = match command_option(args, "--inventory") {
    Ok(value) => value
    Err(error) => return error
  }
  let policy = match policy_option(args) {
    Ok(value) => value
    Err(error) => return error
  }
  let report = match audit_inventory(source, policy) {
    Ok(value) => value
    Err(error) => return command_error(error.to_text())
  }
  let output = if has_flag(args, "--json") {
    report.to_json()
  } else {
    report.to_text()
  }
  if report.accepted() && report.review_count() == 0 {
    command_ok(output)
  } else {
    command_policy_failure(output)
  }
}

///|
fn catalog_command() -> CommandResult {
  let output = StringBuilder::new()
  output.write_string(catalog_stats().to_text() + "\n")
  for id in known_license_ids() {
    let info = lookup_license(id).unwrap()
    output.write_string(
      id +
      " family=" +
      info.family().name() +
      " osi=" +
      info.is_osi_approved().to_string() +
      " obligations=" +
      info.obligations().to_text() +
      "\n",
    )
  }
  command_ok(output.to_string().trim().to_owned())
}

///|
fn diff_command(args : Array[String]) -> CommandResult {
  let before = match command_option(args, "--before") {
    Ok(value) => value
    Err(error) => return error
  }
  let after = match command_option(args, "--after") {
    Ok(value) => value
    Err(error) => return error
  }
  let result = match diff_inventories(before, after) {
    Ok(value) => value
    Err(error) => return command_error(error.to_text())
  }
  let output = if has_flag(args, "--json") {
    result.to_json()
  } else {
    result.to_text()
  }
  command_ok(output)
}

///|
fn matrix_command(args : Array[String]) -> CommandResult {
  let policy = match policy_option(args) {
    Ok(value) => value
    Err(error) => return error
  }
  let matrix = policy_matrix(policy)
  command_ok(
    if has_flag(args, "--json") {
      matrix.to_json()
    } else {
      matrix.to_text()
    },
  )
}

///|
fn summary_command(args : Array[String]) -> CommandResult {
  let source = match command_option(args, "--inventory") {
    Ok(value) => value
    Err(error) => return error
  }
  let stats = match analyze_inventory(source) {
    Ok(value) => value
    Err(error) => return command_error(error.to_text())
  }
  command_ok(
    if has_flag(args, "--json") {
      stats.to_json()
    } else {
      stats.to_text()
    },
  )
}

///|
fn notices_command(args : Array[String]) -> CommandResult {
  let source = match command_option(args, "--inventory") {
    Ok(value) => value
    Err(error) => return error
  }
  let policy = match policy_option(args) {
    Ok(value) => value
    Err(error) => return error
  }
  let report = match audit_inventory(source, policy) {
    Ok(value) => value
    Err(error) => return command_error(error.to_text())
  }
  let plan = match notice_plan(report) {
    Ok(value) => value
    Err(error) => return command_policy_failure(error.to_text())
  }
  command_ok(
    if has_flag(args, "--json") {
      plan.to_json()
    } else {
      plan.to_text()
    },
  )
}

///|
fn query_command(args : Array[String]) -> CommandResult {
  let source = match command_option(args, "--inventory") {
    Ok(value) => value
    Err(error) => return error
  }
  let license = match command_option(args, "--license") {
    Ok(value) => value
    Err(error) => return error
  }
  let index = match compile_inventory(source) {
    Ok(value) => value
    Err(error) => return command_error(error.to_text())
  }
  let components = match index.using_license(license) {
    Ok(value) => value
    Err(error) => return command_error(error.to_text())
  }
  let result = QueryResult::new("license=" + license, components)
  command_ok(
    if has_flag(args, "--json") {
      result.to_json()
    } else {
      result.to_text()
    },
  )
}

///|
fn canonical_inventory_command(args : Array[String]) -> CommandResult {
  let source = match command_option(args, "--inventory") {
    Ok(value) => value
    Err(error) => return error
  }
  match canonical_inventory(source) {
    Ok(value) => command_ok(value)
    Err(error) => command_error(error.to_text())
  }
}

///|
pub fn demo_inventory() -> String {
  "moon-core|0.1|Apache-2.0\nparser-kit|2.4|MIT OR GPL-3.0-only\nfont-data|1.2|OFL-1.1"
}

///|
pub fn demo_policy() -> String {
  "require-osi=true\ndeny=GPL-3.0-only\nprefer=Apache-2.0,MIT"
}

///|
fn demo_command() -> CommandResult {
  let report = audit_inventory(
    demo_inventory(),
    parse_policy(demo_policy()).unwrap(),
  ).unwrap()
  command_ok(report.to_text())
}

///|
pub fn execute(args : Array[String]) -> CommandResult {
  if args.is_empty() {
    return command_ok(help_text)
  }
  match args[0] {
    "help" | "--help" | "-h" => command_ok(help_text)
    "normalize" => normalize_command(args)
    "inspect" => inspect_command(args)
    "evaluate" => evaluate_command(args)
    "audit" => audit_command(args)
    "diff" => diff_command(args)
    "matrix" => matrix_command(args)
    "summary" => summary_command(args)
    "notices" => notices_command(args)
    "query" => query_command(args)
    "canonical-inventory" => canonical_inventory_command(args)
    "catalog" => catalog_command()
    "demo" => demo_command()
    other => command_error("unknown command: " + other + "\n\n" + help_text)
  }
}
