///|
/// One Boolean value in a replayable semantic witness.
pub struct TruthValue {
  atom : String
  value : Bool
} derive(Eq, @debug.Debug)

///|
pub fn TruthValue::atom(self : TruthValue) -> String {
  self.atom
}

///|
pub fn TruthValue::value(self : TruthValue) -> Bool {
  self.value
}

///|
/// A complete assignment over the ordered atoms in a proof.
pub struct TruthAssignment {
  values : Array[TruthValue]
} derive(Eq, @debug.Debug)

///|
pub fn TruthAssignment::values(self : TruthAssignment) -> Array[TruthValue] {
  self.values
}

///|
pub fn TruthAssignment::true_count(self : TruthAssignment) -> Int {
  let mut count = 0
  for value in self.values {
    if value.value {
      count = count + 1
    }
  }
  count
}

///|
fn assignment_value(assignment : TruthAssignment, atom : String) -> Bool {
  for value in assignment.values {
    if value.atom == atom {
      return value.value
    }
  }
  false
}

///|
/// Replay an assignment directly against the parsed expression tree.
pub fn Expression::evaluate_assignment(
  self : Expression,
  assignment : TruthAssignment,
) -> Bool {
  match self {
    Atom(atom) => assignment_value(assignment, atom.canonical())
    And(left, right) =>
      left.evaluate_assignment(assignment) &&
      right.evaluate_assignment(assignment)
    Or(left, right) =>
      left.evaluate_assignment(assignment) ||
      right.evaluate_assignment(assignment)
  }
}

///|
pub fn TruthAssignment::to_text(self : TruthAssignment) -> String {
  let output = StringBuilder::new()
  for index, value in self.values {
    if index > 0 {
      output.write_string(", ")
    }
    output.write_string(value.atom + "=" + value.value.to_string())
  }
  output.to_string()
}

///|
pub fn TruthAssignment::to_json(self : TruthAssignment) -> String {
  let output = StringBuilder::new()
  output.write_char('{')
  for index, value in self.values {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string(quote_json(value.atom) + ":" + bool_json(value.value))
  }
  output.write_char('}')
  output.to_string()
}

///|
priv struct DecisionNode {
  variable : Int
  low : Int
  high : Int
} derive(Eq)

///|
priv struct DecisionManager {
  variables : Array[String]
  nodes : Array[DecisionNode]
}

///|
priv enum BooleanOperation {
  BooleanAnd
  BooleanOr
  BooleanXor
} derive(Eq)

///|
priv struct ApplyMemo {
  operation : BooleanOperation
  left : Int
  right : Int
  result : Int
}

///|
priv struct ComplementMemo {
  source : Int
  result : Int
}

///|
fn contains_text(values : Array[String], target : String) -> Bool {
  values.any(fn(value) { value == target })
}

///|
fn add_expression_atoms(
  expression : Expression,
  values : Array[String],
) -> Unit {
  for atom in expression.atoms() {
    let canonical = atom.canonical()
    if !contains_text(values, canonical) {
      values.push(canonical)
    }
  }
}

///|
/// Use SPDX catalog order so semantically identical formulas get the same
/// variable order even when their source operands are rearranged.
fn ordered_variables(expressions : Array[Expression]) -> Array[String] {
  let present : Array[String] = []
  for expression in expressions {
    add_expression_atoms(expression, present)
  }
  let ordered : Array[String] = []
  for license in known_license_ids() {
    if contains_text(present, license) {
      ordered.push(license)
    }
    for exception in known_exception_ids() {
      let atom = license + " WITH " + exception
      if contains_text(present, atom) {
        ordered.push(atom)
      }
    }
  }
  ordered
}

///|
fn variable_index(variables : Array[String], atom : String) -> Int {
  for index, value in variables {
    if value == atom {
      return index
    }
  }
  -1
}

///|
fn decision_node(manager : DecisionManager, id : Int) -> DecisionNode {
  manager.nodes[id - 2]
}

///|
fn decision_top(manager : DecisionManager, id : Int) -> Int {
  if id < 2 {
    manager.variables.length()
  } else {
    decision_node(manager, id).variable
  }
}

///|
fn make_node(
  manager : DecisionManager,
  variable : Int,
  low : Int,
  high : Int,
) -> Int {
  if low == high {
    return low
  }
  let wanted : DecisionNode = { variable, low, high }
  for index, node in manager.nodes {
    if node == wanted {
      return index + 2
    }
  }
  manager.nodes.push(wanted)
  manager.nodes.length() + 1
}

///|
fn terminal_operation(
  operation : BooleanOperation,
  left : Int,
  right : Int,
) -> Int {
  let a = left == 1
  let b = right == 1
  let value = match operation {
    BooleanAnd => a && b
    BooleanOr => a || b
    BooleanXor => a != b
  }
  if value {
    1
  } else {
    0
  }
}

///|
fn memoized_apply(
  memo : Array[ApplyMemo],
  operation : BooleanOperation,
  left : Int,
  right : Int,
) -> Int? {
  for entry in memo {
    if entry.operation == operation &&
      entry.left == left &&
      entry.right == right {
      return Some(entry.result)
    }
  }
  None
}

///|
fn apply_decisions(
  manager : DecisionManager,
  operation : BooleanOperation,
  left : Int,
  right : Int,
  memo : Array[ApplyMemo],
) -> Int {
  if left < 2 && right < 2 {
    return terminal_operation(operation, left, right)
  }
  match memoized_apply(memo, operation, left, right) {
    Some(result) => return result
    None => ()
  }
  let left_top = decision_top(manager, left)
  let right_top = decision_top(manager, right)
  let top = if left_top < right_top { left_top } else { right_top }
  let left_low = if left_top == top {
    decision_node(manager, left).low
  } else {
    left
  }
  let left_high = if left_top == top {
    decision_node(manager, left).high
  } else {
    left
  }
  let right_low = if right_top == top {
    decision_node(manager, right).low
  } else {
    right
  }
  let right_high = if right_top == top {
    decision_node(manager, right).high
  } else {
    right
  }
  let low = apply_decisions(manager, operation, left_low, right_low, memo)
  let high = apply_decisions(manager, operation, left_high, right_high, memo)
  let result = make_node(manager, top, low, high)
  memo.push({ operation, left, right, result })
  result
}

///|
fn compile_decision(
  manager : DecisionManager,
  expression : Expression,
  memo : Array[ApplyMemo],
) -> Int {
  match expression {
    Atom(atom) => {
      let index = variable_index(manager.variables, atom.canonical())
      make_node(manager, index, 0, 1)
    }
    And(left, right) => {
      let first = compile_decision(manager, left, memo)
      let second = compile_decision(manager, right, memo)
      apply_decisions(manager, BooleanAnd, first, second, memo)
    }
    Or(left, right) => {
      let first = compile_decision(manager, left, memo)
      let second = compile_decision(manager, right, memo)
      apply_decisions(manager, BooleanOr, first, second, memo)
    }
  }
}

///|
fn complement_decision(
  manager : DecisionManager,
  source : Int,
  memo : Array[ComplementMemo],
) -> Int {
  if source == 0 {
    return 1
  }
  if source == 1 {
    return 0
  }
  for entry in memo {
    if entry.source == source {
      return entry.result
    }
  }
  let node = decision_node(manager, source)
  let low = complement_decision(manager, node.low, memo)
  let high = complement_decision(manager, node.high, memo)
  let result = make_node(manager, node.variable, low, high)
  memo.push({ source, result })
  result
}

///|
fn minimum_true_cost(
  manager : DecisionManager,
  root : Int,
  memo : Array[Int],
) -> Int {
  if root == 0 {
    return 1000000
  }
  if root == 1 {
    return 0
  }
  if memo[root] >= 0 {
    return memo[root]
  }
  let node = decision_node(manager, root)
  let low = minimum_true_cost(manager, node.low, memo)
  let high = minimum_true_cost(manager, node.high, memo) + 1
  let result = if low <= high { low } else { high }
  memo[root] = result
  result
}

///|
fn minimum_witness(manager : DecisionManager, root : Int) -> TruthAssignment? {
  if root == 0 {
    return None
  }
  let selected = Array::make(manager.variables.length(), false)
  let memo = Array::make(manager.nodes.length() + 2, -1)
  let mut cursor = root
  while cursor >= 2 {
    let node = decision_node(manager, cursor)
    let low_cost = minimum_true_cost(manager, node.low, memo)
    let high_cost = minimum_true_cost(manager, node.high, memo) + 1
    if low_cost <= high_cost {
      cursor = node.low
    } else {
      selected[node.variable] = true
      cursor = node.high
    }
  }
  if cursor == 0 {
    None
  } else {
    let values : Array[TruthValue] = []
    for index, atom in manager.variables {
      values.push({ atom, value: selected[index] })
    }
    Some({ values, })
  }
}

///|
fn fingerprint_node(
  manager : DecisionManager,
  root : Int,
  memo : Array[String],
) -> String {
  if root == 0 {
    return "0"
  }
  if root == 1 {
    return "1"
  }
  if !memo[root].is_empty() {
    return memo[root]
  }
  let node = decision_node(manager, root)
  let value = "(" +
    manager.variables[node.variable] +
    "?" +
    fingerprint_node(manager, node.high, memo) +
    ":" +
    fingerprint_node(manager, node.low, memo) +
    ")"
  memo[root] = value
  value
}

///|
fn semantic_fingerprint_for(manager : DecisionManager, root : Int) -> String {
  fingerprint_node(manager, root, Array::make(manager.nodes.length() + 2, ""))
}

///|
pub struct SemanticSummary {
  expression : String
  variables : Array[String]
  decision_nodes : Int
  fingerprint : String
  model : TruthAssignment?
} derive(Eq, @debug.Debug)

///|
pub fn SemanticSummary::variables(self : SemanticSummary) -> Array[String] {
  self.variables
}

///|
pub fn SemanticSummary::decision_nodes(self : SemanticSummary) -> Int {
  self.decision_nodes
}

///|
pub fn SemanticSummary::fingerprint(self : SemanticSummary) -> String {
  self.fingerprint
}

///|
pub fn SemanticSummary::model(self : SemanticSummary) -> TruthAssignment? {
  self.model
}

///|
/// Compile one expression into a canonical semantic representation.
pub fn semantic_summary(expression : Expression) -> SemanticSummary {
  let variables = ordered_variables([expression])
  let manager : DecisionManager = { variables, nodes: [] }
  let root = compile_decision(manager, expression, [])
  {
    expression: expression.canonical(),
    variables,
    decision_nodes: manager.nodes.length(),
    fingerprint: semantic_fingerprint_for(manager, root),
    model: minimum_witness(manager, root),
  }
}

///|
pub fn SemanticSummary::to_text(self : SemanticSummary) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "SEMANTICS expression=" +
    self.expression +
    " variables=" +
    self.variables.length().to_string() +
    " nodes=" +
    self.decision_nodes.to_string() +
    "\nFINGERPRINT " +
    self.fingerprint,
  )
  match self.model {
    Some(value) => output.write_string("\nMODEL " + value.to_text())
    None => output.write_string("\nMODEL none")
  }
  output.to_string()
}

///|
pub fn SemanticSummary::to_json(self : SemanticSummary) -> String {
  let model_json = match self.model {
    Some(value) => value.to_json()
    None => "null"
  }
  "{" +
  "\"expression\":" +
  quote_json(self.expression) +
  ",\"variables\":" +
  strings_json(self.variables) +
  ",\"decision_nodes\":" +
  self.decision_nodes.to_string() +
  ",\"fingerprint\":" +
  quote_json(self.fingerprint) +
  ",\"model\":" +
  model_json +
  "}"
}

///|
pub struct SemanticProof {
  relation : String
  left : String
  right : String
  holds : Bool
  variables : Array[String]
  decision_nodes : Int
  counterexample : TruthAssignment?
} derive(Eq, @debug.Debug)

///|
pub fn SemanticProof::relation(self : SemanticProof) -> String {
  self.relation
}

///|
pub fn SemanticProof::holds(self : SemanticProof) -> Bool {
  self.holds
}

///|
pub fn SemanticProof::variables(self : SemanticProof) -> Array[String] {
  self.variables
}

///|
pub fn SemanticProof::decision_nodes(self : SemanticProof) -> Int {
  self.decision_nodes
}

///|
pub fn SemanticProof::counterexample(self : SemanticProof) -> TruthAssignment? {
  self.counterexample
}

///|
fn semantic_proof(
  relation : String,
  left : Expression,
  right : Expression,
) -> SemanticProof {
  let variables = ordered_variables([left, right])
  let manager : DecisionManager = { variables, nodes: [] }
  let apply_memo : Array[ApplyMemo] = []
  let left_root = compile_decision(manager, left, apply_memo)
  let right_root = compile_decision(manager, right, apply_memo)
  let failure = if relation == "equivalent" {
    apply_decisions(manager, BooleanXor, left_root, right_root, apply_memo)
  } else {
    let negated = complement_decision(manager, right_root, [])
    apply_decisions(manager, BooleanAnd, left_root, negated, apply_memo)
  }
  {
    relation,
    left: left.canonical(),
    right: right.canonical(),
    holds: failure == 0,
    variables,
    decision_nodes: manager.nodes.length(),
    counterexample: minimum_witness(manager, failure),
  }
}

///|
/// Prove that two expressions denote the same Boolean function.
pub fn prove_equivalent(left : Expression, right : Expression) -> SemanticProof {
  semantic_proof("equivalent", left, right)
}

///|
/// Prove that every assignment satisfying the premise also satisfies the conclusion.
pub fn prove_implication(
  premise : Expression,
  conclusion : Expression,
) -> SemanticProof {
  semantic_proof("implies", premise, conclusion)
}

///|
pub fn SemanticProof::to_text(self : SemanticProof) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "PROOF relation=" +
    self.relation +
    " holds=" +
    self.holds.to_string() +
    " variables=" +
    self.variables.length().to_string() +
    " nodes=" +
    self.decision_nodes.to_string() +
    "\nLEFT " +
    self.left +
    "\nRIGHT " +
    self.right,
  )
  match self.counterexample {
    Some(value) => output.write_string("\nCOUNTEREXAMPLE " + value.to_text())
    None => output.write_string("\nCOUNTEREXAMPLE none")
  }
  output.to_string()
}

///|
pub fn SemanticProof::to_json(self : SemanticProof) -> String {
  let counterexample_json = match self.counterexample {
    Some(value) => value.to_json()
    None => "null"
  }
  "{" +
  "\"relation\":" +
  quote_json(self.relation) +
  ",\"holds\":" +
  bool_json(self.holds) +
  ",\"left\":" +
  quote_json(self.left) +
  ",\"right\":" +
  quote_json(self.right) +
  ",\"variables\":" +
  strings_json(self.variables) +
  ",\"decision_nodes\":" +
  self.decision_nodes.to_string() +
  ",\"counterexample\":" +
  counterexample_json +
  "}"
}

///|
pub struct TruthRow {
  assignment : TruthAssignment
  result : Bool
} derive(Eq, @debug.Debug)

///|
pub fn TruthRow::assignment(self : TruthRow) -> TruthAssignment {
  self.assignment
}

///|
pub fn TruthRow::result(self : TruthRow) -> Bool {
  self.result
}

///|
pub struct TruthTable {
  expression : String
  variables : Array[String]
  rows : Array[TruthRow]
} derive(Eq, @debug.Debug)

///|
pub fn TruthTable::variables(self : TruthTable) -> Array[String] {
  self.variables
}

///|
pub fn TruthTable::rows(self : TruthTable) -> Array[TruthRow] {
  self.rows
}

///|
fn enumerate_truth_rows(
  expression : Expression,
  variables : Array[String],
  selected : Array[Bool],
  index : Int,
  rows : Array[TruthRow],
) -> Unit {
  if index == variables.length() {
    let values : Array[TruthValue] = []
    for value_index, atom in variables {
      values.push({ atom, value: selected[value_index] })
    }
    let assignment : TruthAssignment = { values, }
    rows.push({ assignment, result: expression.evaluate_assignment(assignment) })
    return
  }
  selected[index] = false
  enumerate_truth_rows(expression, variables, selected, index + 1, rows)
  selected[index] = true
  enumerate_truth_rows(expression, variables, selected, index + 1, rows)
}

///|
/// Generate a complete truth table for expressions with at most 10 atoms.
pub fn truth_table(expression : Expression) -> Result[TruthTable, Diagnostic] {
  let variables = ordered_variables([expression])
  if variables.length() > 10 {
    return Err(
      Diagnostic::new(
        "semantic.table.limit",
        "expression",
        "truth table exceeds the bounded variable limit",
        "at most 10 distinct atoms",
        variables.length().to_string(),
      ),
    )
  }
  let rows : Array[TruthRow] = []
  enumerate_truth_rows(
    expression,
    variables,
    Array::make(variables.length(), false),
    0,
    rows,
  )
  Ok({ expression: expression.canonical(), variables, rows })
}

///|
pub fn TruthTable::to_text(self : TruthTable) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "TRUTH-TABLE expression=" +
    self.expression +
    " rows=" +
    self.rows.length().to_string(),
  )
  for row in self.rows {
    output.write_string(
      "\n" + row.assignment.to_text() + " => " + row.result.to_string(),
    )
  }
  output.to_string()
}

///|
pub fn TruthTable::to_json(self : TruthTable) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "{\"expression\":" +
    quote_json(self.expression) +
    ",\"variables\":" +
    strings_json(self.variables) +
    ",\"rows\":[",
  )
  for index, row in self.rows {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string(
      "{\"assignment\":" +
      row.assignment.to_json() +
      ",\"result\":" +
      bool_json(row.result) +
      "}",
    )
  }
  output.write_string("]}")
  output.to_string()
}
