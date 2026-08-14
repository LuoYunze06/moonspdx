///|
pub enum DecisionStatus {
  Accepted
  Rejected
  Review
} derive(Eq, @debug.Debug)

///|
pub struct Policy {
  require_osi : Bool
  allowed_ids : Array[String]
  denied_ids : Array[String]
  preferred_ids : Array[String]
  required_obligations : Array[String]
} derive(Eq, @debug.Debug)

///|
pub fn Policy::new(
  require_osi? : Bool = false,
  allowed_ids? : Array[String] = [],
  denied_ids? : Array[String] = [],
  preferred_ids? : Array[String] = [],
  required_obligations? : Array[String] = [],
) -> Policy {
  {
    require_osi,
    allowed_ids: allowed_ids.copy(),
    denied_ids: denied_ids.copy(),
    preferred_ids: preferred_ids.copy(),
    required_obligations: required_obligations.copy(),
  }
}

///|
pub fn Policy::permissive() -> Policy {
  Policy::new()
}

///|
pub fn Policy::osi_only() -> Policy {
  Policy::new(require_osi=true)
}

///|
pub fn Policy::with_allowed(self : Policy, ids : Array[String]) -> Policy {
  { ..self, allowed_ids: ids.copy() }
}

///|
pub fn Policy::with_denied(self : Policy, ids : Array[String]) -> Policy {
  { ..self, denied_ids: ids.copy() }
}

///|
pub fn Policy::with_preferences(self : Policy, ids : Array[String]) -> Policy {
  { ..self, preferred_ids: ids.copy() }
}

///|
pub fn Policy::requiring(self : Policy, obligations : Array[String]) -> Policy {
  { ..self, required_obligations: obligations.copy() }
}

///|
pub fn Policy::requires_osi(self : Policy) -> Bool {
  self.require_osi
}

///|
pub fn Policy::allowed_ids(self : Policy) -> Array[String] {
  self.allowed_ids.copy()
}

///|
pub fn Policy::denied_ids(self : Policy) -> Array[String] {
  self.denied_ids.copy()
}

///|
pub struct Evaluation {
  status : DecisionStatus
  selected : String
  obligations : Obligations
  reasons : Array[String]
} derive(Eq, @debug.Debug)

///|
pub fn Evaluation::status(self : Evaluation) -> DecisionStatus {
  self.status
}

///|
pub fn Evaluation::status_name(self : Evaluation) -> String {
  match self.status {
    Accepted => "accepted"
    Rejected => "rejected"
    Review => "review"
  }
}

///|
pub fn Evaluation::selected(self : Evaluation) -> String {
  self.selected
}

///|
pub fn Evaluation::obligations(self : Evaluation) -> Obligations {
  self.obligations
}

///|
pub fn Evaluation::reasons(self : Evaluation) -> Array[String] {
  self.reasons.copy()
}

///|
fn evaluation(
  status : DecisionStatus,
  selected : String,
  obligations : Obligations,
  reasons : Array[String],
) -> Evaluation {
  { status, selected, obligations, reasons }
}

///|
fn contains_string(values : Array[String], value : String) -> Bool {
  values.any(fn(item) { item == value })
}

///|
fn required_obligations_satisfied(
  required : Array[String],
  obligations : Obligations,
) -> Bool {
  for item in required {
    let available = obligations.names()
    if !contains_string(available, item) {
      return false
    }
  }
  true
}

///|
fn exception_compatible(license : String, exception : String) -> Bool {
  match exception {
    "Classpath-exception-2.0" =>
      license == "GPL-2.0-only" ||
      license == "GPL-2.0-or-later" ||
      license == "GPL-3.0-only" ||
      license == "GPL-3.0-or-later" ||
      license == "LGPL-2.0-only" ||
      license == "LGPL-2.0-or-later" ||
      license == "LGPL-2.1-only" ||
      license == "LGPL-2.1-or-later"
    "GCC-exception-2.0" | "GCC-exception-3.1" =>
      license == "GPL-2.0-only" ||
      license == "GPL-2.0-or-later" ||
      license == "GPL-3.0-only" ||
      license == "GPL-3.0-or-later"
    "Autoconf-exception-2.0" | "Autoconf-exception-3.0" =>
      license == "GPL-2.0-only" ||
      license == "GPL-2.0-or-later" ||
      license == "GPL-3.0-only" ||
      license == "GPL-3.0-or-later"
    "Bison-exception-2.2" =>
      license == "GPL-2.0-only" || license == "GPL-3.0-only"
    "Linux-syscall-note" => license == "GPL-2.0-only"
    "LLVM-exception" => license == "Apache-2.0"
    _ => true
  }
}

///|
fn evaluate_atom(atom : LicenseAtom, policy : Policy) -> Evaluation {
  let info = match lookup_license(atom.id) {
    Some(value) => value
    None =>
      return evaluation(Rejected, atom.canonical(), Obligations::none(), [
        "unknown license identifier: " + atom.id,
      ])
  }
  match atom.exception {
    Some(exception) =>
      if !exception_compatible(atom.id, exception) {
        return evaluation(Rejected, atom.canonical(), Obligations::none(), [
          "exception " + exception + " is not compatible with " + atom.id,
        ])
      }
    None => ()
  }
  if contains_string(policy.denied_ids, atom.id) {
    return evaluation(Rejected, atom.canonical(), info.obligations(), [
      "license is explicitly denied: " + atom.id,
    ])
  }
  if !policy.allowed_ids.is_empty() &&
    !contains_string(policy.allowed_ids, atom.id) {
    return evaluation(Rejected, atom.canonical(), info.obligations(), [
      "license is outside the allow-list: " + atom.id,
    ])
  }
  if policy.require_osi && !info.is_osi_approved() {
    return evaluation(Review, atom.canonical(), info.obligations(), [
      "license is not marked OSI-approved in the curated catalog: " + atom.id,
    ])
  }
  if !required_obligations_satisfied(
      policy.required_obligations,
      info.obligations(),
    ) {
    return evaluation(Review, atom.canonical(), info.obligations(), [
      "policy requires obligations not represented by this license",
    ])
  }
  evaluation(Accepted, atom.canonical(), info.obligations(), [])
}

///|
fn join_reasons(left : Array[String], right : Array[String]) -> Array[String] {
  let result = left.copy()
  for value in right {
    result.push(value)
  }
  result
}

///|
fn evaluate_expression(expression : Expression, policy : Policy) -> Evaluation {
  match expression {
    Atom(atom) => evaluate_atom(atom, policy)
    And(left, right) => {
      let first = evaluate_expression(left, policy)
      let second = evaluate_expression(right, policy)
      let status = match (first.status, second.status) {
        (Rejected, _) | (_, Rejected) => Rejected
        (Review, _) | (_, Review) => Review
        _ => Accepted
      }
      evaluation(
        status,
        first.selected + " AND " + second.selected,
        first.obligations.combine(second.obligations),
        join_reasons(first.reasons, second.reasons),
      )
    }
    Or(left, right) => {
      let first = evaluate_expression(left, policy)
      if first.status == Accepted {
        return first
      }
      let second = evaluate_expression(right, policy)
      if second.status == Accepted {
        return second
      }
      let status = if first.status == Review || second.status == Review {
        Review
      } else {
        Rejected
      }
      evaluation(
        status,
        first.selected + " OR " + second.selected,
        first.obligations.combine(second.obligations),
        join_reasons(first.reasons, second.reasons),
      )
    }
  }
}

///|
/// Evaluate a parsed SPDX expression. OR branches are considered left to right.
pub fn evaluate(expression : Expression, policy : Policy) -> Evaluation {
  evaluate_expression(expression, policy)
}

///|
/// Parse and evaluate a source expression in one operation.
pub fn evaluate_source(
  source : String,
  policy : Policy,
) -> Result[Evaluation, Diagnostic] {
  match parse_expression(source) {
    Ok(expression) => Ok(evaluate(expression, policy))
    Err(error) => Err(error)
  }
}

///|
pub fn DecisionStatus::name(self : DecisionStatus) -> String {
  match self {
    Accepted => "accepted"
    Rejected => "rejected"
    Review => "review"
  }
}
