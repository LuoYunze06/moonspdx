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
  let output = StringBuilder()
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
  let output = StringBuilder()
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
} derive(Eq, Hash)

///|
priv struct DecisionManager {
  variables : Array[String]
  nodes : Array[DecisionNode]
  unique : Map[DecisionNode, Int]
  max_nodes : Int
  max_operations : Int
  operations : Array[Int]
  exceeded : Array[String]
}

///|
/// Resource budget for one symbolic compilation or proof.
pub struct SemanticLimits {
  max_variables : Int
  max_nodes : Int
  max_operations : Int
} derive(Eq, @debug.Debug)

///|
pub fn SemanticLimits::default() -> SemanticLimits {
  { max_variables: 32, max_nodes: 4096, max_operations: 50000, }
}

///|
pub fn SemanticLimits::new(
  max_variables : Int,
  max_nodes : Int,
  max_operations : Int,
) -> Result[SemanticLimits, Diagnostic] {
  if max_variables < 1 || max_nodes < 1 || max_operations < 1 {
    Err(
      Diagnostic::new(
        "semantic.limit.invalid",
        "limits",
        "semantic limits must all be positive",
        "positive variable, node, and operation limits",
        max_variables.to_string() +
        "," +
        max_nodes.to_string() +
        "," +
        max_operations.to_string(),
      ),
    )
  } else {
    Ok({ max_variables, max_nodes, max_operations, })
  }
}

///|
pub fn SemanticLimits::max_variables(self : SemanticLimits) -> Int {
  self.max_variables
}

///|
pub fn SemanticLimits::max_nodes(self : SemanticLimits) -> Int {
  self.max_nodes
}

///|
pub fn SemanticLimits::max_operations(self : SemanticLimits) -> Int {
  self.max_operations
}

///|
priv enum BooleanOperation {
  BooleanAnd
  BooleanOr
  BooleanXor
} derive(Eq, Hash)

///|
priv struct ApplyMemo {
  operation : BooleanOperation
  left : Int
  right : Int
} derive(Eq, Hash)

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
fn new_decision_manager(
  expressions : Array[Expression],
  limits : SemanticLimits,
) -> Result[DecisionManager, Diagnostic] {
  let variables = ordered_variables(expressions)
  if variables.length() > limits.max_variables {
    Err(
      Diagnostic::new(
        "semantic.variable.limit",
        "expression",
        "semantic compilation exceeds the variable budget",
        "at most " + limits.max_variables.to_string() + " distinct atoms",
        variables.length().to_string(),
      ),
    )
  } else {
    Ok({
      variables,
      nodes: [],
      unique: Map::Map([]),
      max_nodes: limits.max_nodes,
      max_operations: limits.max_operations,
      operations: [0],
      exceeded: [""],
    })
  }
}

///|
fn consume_operation(manager : DecisionManager) -> Bool {
  if !manager.exceeded[0].is_empty() {
    return false
  }
  if manager.operations[0] >= manager.max_operations {
    manager.exceeded[0] = "operations"
    return false
  }
  manager.operations[0] = manager.operations[0] + 1
  true
}

///|
fn semantic_budget_error(manager : DecisionManager) -> Diagnostic? {
  match manager.exceeded[0] {
    "nodes" =>
      Some(
        Diagnostic::new(
          "semantic.node.limit",
          "expression",
          "semantic compilation exceeds the decision-node budget",
          "at most " + manager.max_nodes.to_string() + " decision nodes",
          "more than " + manager.max_nodes.to_string(),
        ),
      )
    "operations" =>
      Some(
        Diagnostic::new(
          "semantic.operation.limit",
          "expression",
          "semantic compilation exceeds the operation budget",
          "at most " + manager.max_operations.to_string() + " operations",
          "more than " + manager.max_operations.to_string(),
        ),
      )
    _ => None
  }
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
  if !consume_operation(manager) {
    return 0
  }
  if low == high {
    return low
  }
  let wanted : DecisionNode = { variable, low, high, }
  // Count one logical table lookup, not runtime hash collision probes.
  if !consume_operation(manager) {
    return 0
  }
  match manager.unique.get(wanted) {
    Some(id) => return id
    None => ()
  }
  if manager.nodes.length() >= manager.max_nodes {
    manager.exceeded[0] = "nodes"
    return 0
  }
  manager.nodes.push(wanted)
  let id = manager.nodes.length() + 1
  manager.unique.set(wanted, id)
  id
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
fn apply_decisions(
  manager : DecisionManager,
  operation : BooleanOperation,
  left : Int,
  right : Int,
  memo : Map[ApplyMemo, Int],
) -> Int {
  if !consume_operation(manager) {
    return 0
  }
  if left < 2 && right < 2 {
    return terminal_operation(operation, left, right)
  }
  // All supported operations commute. A sorted key shares reversed requests.
  let first = if left <= right { left } else { right }
  let second = if left <= right { right } else { left }
  match operation {
    BooleanAnd => {
      if first == 0 {
        return 0
      }
      if first == 1 || first == second {
        return second
      }
    }
    BooleanOr => {
      if first == 0 || first == second {
        return second
      }
      if first == 1 {
        return 1
      }
    }
    BooleanXor => {
      if first == second {
        return 0
      }
      if first == 0 {
        return second
      }
    }
  }
  let key : ApplyMemo = { operation, left: first, right: second, }
  if !consume_operation(manager) {
    return 0
  }
  match memo.get(key) {
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
  if manager.exceeded[0].is_empty() {
    memo.set(key, result)
  }
  result
}

///|
fn compile_decision(
  manager : DecisionManager,
  expression : Expression,
  memo : Map[ApplyMemo, Int],
) -> Int {
  if !consume_operation(manager) {
    return 0
  }
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
  memo : Map[Int, Int],
) -> Int {
  if !consume_operation(manager) {
    return 0
  }
  if source == 0 {
    return 1
  }
  if source == 1 {
    return 0
  }
  if !consume_operation(manager) {
    return 0
  }
  match memo.get(source) {
    Some(result) => return result
    None => ()
  }
  let node = decision_node(manager, source)
  let low = complement_decision(manager, node.low, memo)
  let high = complement_decision(manager, node.high, memo)
  let result = make_node(manager, node.variable, low, high)
  if manager.exceeded[0].is_empty() {
    memo.set(source, result)
  }
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
      values.push({ atom, value: selected[index], })
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
  operations : Int
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
pub fn SemanticSummary::operations(self : SemanticSummary) -> Int {
  self.operations
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
pub fn semantic_summary(
  expression : Expression,
) -> Result[SemanticSummary, Diagnostic] {
  semantic_summary_with_limits(expression, SemanticLimits::default())
}

///|
pub fn semantic_summary_with_limits(
  expression : Expression,
  limits : SemanticLimits,
) -> Result[SemanticSummary, Diagnostic] {
  let manager = match new_decision_manager([expression], limits) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let root = compile_decision(manager, expression, Map::Map([]))
  match semantic_budget_error(manager) {
    Some(error) => Err(error)
    None =>
      Ok({
        expression: expression.canonical(),
        variables: manager.variables,
        decision_nodes: manager.nodes.length(),
        operations: manager.operations[0],
        fingerprint: semantic_fingerprint_for(manager, root),
        model: minimum_witness(manager, root),
      })
  }
}

///|
pub fn SemanticSummary::to_text(self : SemanticSummary) -> String {
  let output = StringBuilder()
  output.write_string(
    "SEMANTICS expression=" +
    self.expression +
    " variables=" +
    self.variables.length().to_string() +
    " nodes=" +
    self.decision_nodes.to_string() +
    " operations=" +
    self.operations.to_string() +
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
  ",\"operations\":" +
  self.operations.to_string() +
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
  operations : Int
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
pub fn SemanticProof::operations(self : SemanticProof) -> Int {
  self.operations
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
  limits : SemanticLimits,
) -> Result[SemanticProof, Diagnostic] {
  let manager = match new_decision_manager([left, right], limits) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let apply_memo : Map[ApplyMemo, Int] = Map::Map([])
  let left_root = compile_decision(manager, left, apply_memo)
  let right_root = compile_decision(manager, right, apply_memo)
  let failure = if relation == "equivalent" {
    apply_decisions(manager, BooleanXor, left_root, right_root, apply_memo)
  } else {
    let negated = complement_decision(manager, right_root, Map::Map([]))
    apply_decisions(manager, BooleanAnd, left_root, negated, apply_memo)
  }
  match semantic_budget_error(manager) {
    Some(error) => Err(error)
    None =>
      Ok({
        relation,
        left: left.canonical(),
        right: right.canonical(),
        holds: failure == 0,
        variables: manager.variables,
        decision_nodes: manager.nodes.length(),
        operations: manager.operations[0],
        counterexample: minimum_witness(manager, failure),
      })
  }
}

///|
/// Prove that two expressions denote the same Boolean function.
pub fn prove_equivalent(
  left : Expression,
  right : Expression,
) -> Result[SemanticProof, Diagnostic] {
  prove_equivalent_with_limits(left, right, SemanticLimits::default())
}

///|
pub fn prove_equivalent_with_limits(
  left : Expression,
  right : Expression,
  limits : SemanticLimits,
) -> Result[SemanticProof, Diagnostic] {
  semantic_proof("equivalent", left, right, limits)
}

///|
/// Prove that every assignment satisfying the premise also satisfies the conclusion.
pub fn prove_implication(
  premise : Expression,
  conclusion : Expression,
) -> Result[SemanticProof, Diagnostic] {
  prove_implication_with_limits(premise, conclusion, SemanticLimits::default())
}

///|
pub fn prove_implication_with_limits(
  premise : Expression,
  conclusion : Expression,
  limits : SemanticLimits,
) -> Result[SemanticProof, Diagnostic] {
  semantic_proof("implies", premise, conclusion, limits)
}

///|
pub fn SemanticProof::to_text(self : SemanticProof) -> String {
  let output = StringBuilder()
  output.write_string(
    "PROOF relation=" +
    self.relation +
    " holds=" +
    self.holds.to_string() +
    " variables=" +
    self.variables.length().to_string() +
    " nodes=" +
    self.decision_nodes.to_string() +
    " operations=" +
    self.operations.to_string() +
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
  ",\"operations\":" +
  self.operations.to_string() +
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
      values.push({ atom, value: selected[value_index], })
    }
    let assignment : TruthAssignment = { values, }
    rows.push({
      assignment,
      result: expression.evaluate_assignment(assignment),
    })
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
  Ok({ expression: expression.canonical(), variables, rows, })
}

///|
pub fn TruthTable::to_text(self : TruthTable) -> String {
  let output = StringBuilder()
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
  let output = StringBuilder()
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

///|
pub enum SemanticRelation {
  SemanticallyEquivalent
  LeftNarrower
  LeftBroader
  SemanticallyIncomparable
} derive(Eq, @debug.Debug)

///|
pub fn SemanticRelation::name(self : SemanticRelation) -> String {
  match self {
    SemanticallyEquivalent => "equivalent"
    LeftNarrower => "left-narrower"
    LeftBroader => "left-broader"
    SemanticallyIncomparable => "incomparable"
  }
}

///|
/// A four-way comparison based on implication in both directions.
pub struct SemanticComparison {
  left : String
  right : String
  relation : SemanticRelation
  left_implies_right : SemanticProof
  right_implies_left : SemanticProof
} derive(Eq, @debug.Debug)

///|
pub fn SemanticComparison::relation(
  self : SemanticComparison,
) -> SemanticRelation {
  self.relation
}

///|
pub fn SemanticComparison::left_implies_right(
  self : SemanticComparison,
) -> SemanticProof {
  self.left_implies_right
}

///|
pub fn SemanticComparison::right_implies_left(
  self : SemanticComparison,
) -> SemanticProof {
  self.right_implies_left
}

///|
pub fn compare_semantics(
  left : Expression,
  right : Expression,
) -> Result[SemanticComparison, Diagnostic] {
  compare_semantics_with_limits(left, right, SemanticLimits::default())
}

///|
pub fn compare_semantics_with_limits(
  left : Expression,
  right : Expression,
  limits : SemanticLimits,
) -> Result[SemanticComparison, Diagnostic] {
  let forward = match prove_implication_with_limits(left, right, limits) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let backward = match prove_implication_with_limits(right, left, limits) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let relation = if forward.holds() && backward.holds() {
    SemanticallyEquivalent
  } else if forward.holds() {
    LeftNarrower
  } else if backward.holds() {
    LeftBroader
  } else {
    SemanticallyIncomparable
  }
  Ok({
    left: left.canonical(),
    right: right.canonical(),
    relation,
    left_implies_right: forward,
    right_implies_left: backward,
  })
}

///|
pub fn SemanticComparison::to_text(self : SemanticComparison) -> String {
  let output = StringBuilder()
  output.write_string(
    "COMPARISON relation=" +
    self.relation.name() +
    " left_implies_right=" +
    self.left_implies_right.holds().to_string() +
    " right_implies_left=" +
    self.right_implies_left.holds().to_string() +
    "\nLEFT " +
    self.left +
    "\nRIGHT " +
    self.right,
  )
  match self.left_implies_right.counterexample() {
    Some(value) => output.write_string("\nLEFT-ONLY " + value.to_text())
    None => ()
  }
  match self.right_implies_left.counterexample() {
    Some(value) => output.write_string("\nRIGHT-ONLY " + value.to_text())
    None => ()
  }
  output.to_string()
}

///|
pub fn SemanticComparison::to_json(self : SemanticComparison) -> String {
  "{" +
  "\"relation\":" +
  quote_json(self.relation.name()) +
  ",\"left\":" +
  quote_json(self.left) +
  ",\"right\":" +
  quote_json(self.right) +
  ",\"left_implies_right\":" +
  self.left_implies_right.to_json() +
  ",\"right_implies_left\":" +
  self.right_implies_left.to_json() +
  "}"
}

///|
priv struct RestrictionMemo {
  source : Int
  variable : Int
  value : Bool
} derive(Eq, Hash)

///|
fn restrict_decision(
  manager : DecisionManager,
  root : Int,
  variable : Int,
  value : Bool,
  memo : Map[RestrictionMemo, Int],
) -> Int {
  if !consume_operation(manager) {
    return 0
  }
  if root < 2 {
    return root
  }
  let key : RestrictionMemo = { source: root, variable, value, }
  if !consume_operation(manager) {
    return 0
  }
  match memo.get(key) {
    Some(result) => return result
    None => ()
  }
  let node = decision_node(manager, root)
  let result = if node.variable == variable {
    if value {
      node.high
    } else {
      node.low
    }
  } else if node.variable > variable {
    root
  } else {
    let low = restrict_decision(manager, node.low, variable, value, memo)
    let high = restrict_decision(manager, node.high, variable, value, memo)
    make_node(manager, node.variable, low, high)
  }
  if manager.exceeded[0].is_empty() {
    memo.set(key, result)
  }
  result
}

///|
fn assignment_overriding(
  assignment : TruthAssignment,
  atom : String,
  value : Bool,
) -> TruthAssignment {
  let values : Array[TruthValue] = []
  for entry in assignment.values {
    values.push(
      if entry.atom == atom {
        { atom: entry.atom, value, }
      } else {
        entry
      },
    )
  }
  { values, }
}

///|
pub struct AtomInfluence {
  atom : String
  relevant : Bool
  when_false : TruthAssignment?
  when_true : TruthAssignment?
  false_result : Bool
  true_result : Bool
} derive(Eq, @debug.Debug)

///|
pub fn AtomInfluence::atom(self : AtomInfluence) -> String {
  self.atom
}

///|
pub fn AtomInfluence::relevant(self : AtomInfluence) -> Bool {
  self.relevant
}

///|
pub fn AtomInfluence::when_false(self : AtomInfluence) -> TruthAssignment? {
  self.when_false
}

///|
pub fn AtomInfluence::when_true(self : AtomInfluence) -> TruthAssignment? {
  self.when_true
}

///|
pub fn AtomInfluence::false_result(self : AtomInfluence) -> Bool {
  self.false_result
}

///|
pub fn AtomInfluence::true_result(self : AtomInfluence) -> Bool {
  self.true_result
}

///|
pub struct InfluenceReport {
  expression : String
  influences : Array[AtomInfluence]
  relevant : Int
  redundant : Int
  decision_nodes : Int
  operations : Int
} derive(Eq, @debug.Debug)

///|
pub fn InfluenceReport::influences(
  self : InfluenceReport,
) -> Array[AtomInfluence] {
  self.influences
}

///|
pub fn InfluenceReport::relevant(self : InfluenceReport) -> Int {
  self.relevant
}

///|
pub fn InfluenceReport::redundant(self : InfluenceReport) -> Int {
  self.redundant
}

///|
pub fn InfluenceReport::decision_nodes(self : InfluenceReport) -> Int {
  self.decision_nodes
}

///|
pub fn InfluenceReport::operations(self : InfluenceReport) -> Int {
  self.operations
}

///|
/// Find whether changing each atom can change the expression. Relevant atoms
/// include a minimum context and the two replayable assignments.
pub fn analyze_influence(
  expression : Expression,
) -> Result[InfluenceReport, Diagnostic] {
  analyze_influence_with_limits(expression, SemanticLimits::default())
}

///|
pub fn analyze_influence_with_limits(
  expression : Expression,
  limits : SemanticLimits,
) -> Result[InfluenceReport, Diagnostic] {
  let manager = match new_decision_manager([expression], limits) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let root = compile_decision(manager, expression, Map::Map([]))
  let influences : Array[AtomInfluence] = []
  let mut relevant_count = 0
  let mut redundant_count = 0
  for variable, atom in manager.variables {
    let restriction_memo : Map[RestrictionMemo, Int] = Map::Map([])
    let low = restrict_decision(
      manager, root, variable, false, restriction_memo,
    )
    let high = restrict_decision(
      manager, root, variable, true, restriction_memo,
    )
    if low == high {
      redundant_count = redundant_count + 1
      influences.push({
        atom,
        relevant: false,
        when_false: None,
        when_true: None,
        false_result: false,
        true_result: false,
      })
    } else {
      relevant_count = relevant_count + 1
      let difference = apply_decisions(
        manager,
        BooleanXor,
        low,
        high,
        Map::Map([]),
      )
      let context = minimum_witness(manager, difference).unwrap()
      let when_false = assignment_overriding(context, atom, false)
      let when_true = assignment_overriding(context, atom, true)
      influences.push({
        atom,
        relevant: true,
        when_false: Some(when_false),
        when_true: Some(when_true),
        false_result: expression.evaluate_assignment(when_false),
        true_result: expression.evaluate_assignment(when_true),
      })
    }
    match semantic_budget_error(manager) {
      Some(error) => return Err(error)
      None => ()
    }
  }
  Ok({
    expression: expression.canonical(),
    influences,
    relevant: relevant_count,
    redundant: redundant_count,
    decision_nodes: manager.nodes.length(),
    operations: manager.operations[0],
  })
}

///|
pub fn InfluenceReport::to_text(self : InfluenceReport) -> String {
  let output = StringBuilder()
  output.write_string(
    "INFLUENCE expression=" +
    self.expression +
    " relevant=" +
    self.relevant.to_string() +
    " redundant=" +
    self.redundant.to_string() +
    " nodes=" +
    self.decision_nodes.to_string() +
    " operations=" +
    self.operations.to_string(),
  )
  for influence in self.influences {
    output.write_string(
      "\nATOM " + influence.atom + " relevant=" + influence.relevant.to_string(),
    )
    match (influence.when_false, influence.when_true) {
      (Some(low), Some(high)) =>
        output.write_string(
          " false_result=" +
          influence.false_result.to_string() +
          " true_result=" +
          influence.true_result.to_string() +
          " context=" +
          low.to_text() +
          " -> " +
          high.to_text(),
        )
      _ => ()
    }
  }
  output.to_string()
}

///|
pub fn InfluenceReport::to_json(self : InfluenceReport) -> String {
  let output = StringBuilder()
  output.write_string(
    "{\"expression\":" +
    quote_json(self.expression) +
    ",\"relevant\":" +
    self.relevant.to_string() +
    ",\"redundant\":" +
    self.redundant.to_string() +
    ",\"decision_nodes\":" +
    self.decision_nodes.to_string() +
    ",\"operations\":" +
    self.operations.to_string() +
    ",\"atoms\":[",
  )
  for index, influence in self.influences {
    if index > 0 {
      output.write_char(',')
    }
    let false_assignment = match influence.when_false {
      Some(value) => value.to_json()
      None => "null"
    }
    let true_assignment = match influence.when_true {
      Some(value) => value.to_json()
      None => "null"
    }
    output.write_string(
      "{\"atom\":" +
      quote_json(influence.atom) +
      ",\"relevant\":" +
      bool_json(influence.relevant) +
      ",\"when_false\":" +
      false_assignment +
      ",\"when_true\":" +
      true_assignment +
      ",\"false_result\":" +
      bool_json(influence.false_result) +
      ",\"true_result\":" +
      bool_json(influence.true_result) +
      "}",
    )
  }
  output.write_string("]}")
  output.to_string()
}
