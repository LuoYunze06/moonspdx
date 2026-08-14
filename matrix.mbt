///|
pub struct CatalogDecision {
  license : LicenseInfo
  evaluation : Evaluation
} derive(Eq, @debug.Debug)

///|
pub fn CatalogDecision::license(self : CatalogDecision) -> LicenseInfo {
  self.license
}

///|
pub fn CatalogDecision::evaluation(self : CatalogDecision) -> Evaluation {
  self.evaluation
}

///|
pub struct PolicyMatrix {
  decisions : Array[CatalogDecision]
  accepted : Int
  review : Int
  rejected : Int
} derive(Eq, @debug.Debug)

///|
pub fn PolicyMatrix::decisions(self : PolicyMatrix) -> Array[CatalogDecision] {
  self.decisions.copy()
}

///|
pub fn PolicyMatrix::accepted(self : PolicyMatrix) -> Int {
  self.accepted
}

///|
pub fn PolicyMatrix::review(self : PolicyMatrix) -> Int {
  self.review
}

///|
pub fn PolicyMatrix::rejected(self : PolicyMatrix) -> Int {
  self.rejected
}

///|
/// Evaluate every identifier in the curated catalog against one policy.
pub fn policy_matrix(policy : Policy) -> PolicyMatrix {
  let decisions = []
  let mut accepted = 0
  let mut review = 0
  let mut rejected = 0
  for id in known_license_ids() {
    let info = lookup_license(id).unwrap()
    let result = evaluate(Atom(LicenseAtom::new(id)), policy)
    match result.status() {
      Accepted => accepted = accepted + 1
      Review => review = review + 1
      Rejected => rejected = rejected + 1
    }
    decisions.push({ license: info, evaluation: result })
  }
  { decisions, accepted, review, rejected }
}

///|
pub fn PolicyMatrix::to_text(self : PolicyMatrix) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "POLICY-MATRIX accepted=" +
    self.accepted.to_string() +
    " review=" +
    self.review.to_string() +
    " rejected=" +
    self.rejected.to_string(),
  )
  for decision in self.decisions {
    output.write_string(
      "\n" +
      decision.license.id() +
      " " +
      decision.evaluation.status_name() +
      " family=" +
      decision.license.family().name(),
    )
    if !decision.evaluation.reasons().is_empty() {
      output.write_string(
        " reasons=" + join_text(decision.evaluation.reasons(), "; "),
      )
    }
  }
  output.to_string()
}

///|
pub fn PolicyMatrix::to_json(self : PolicyMatrix) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "{\"accepted\":" +
    self.accepted.to_string() +
    ",\"review\":" +
    self.review.to_string() +
    ",\"rejected\":" +
    self.rejected.to_string() +
    ",\"decisions\":[",
  )
  for index, decision in self.decisions {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string(
      "{\"license\":" +
      quote_json(decision.license.id()) +
      ",\"family\":" +
      quote_json(decision.license.family().name()) +
      ",\"status\":" +
      quote_json(decision.evaluation.status_name()) +
      ",\"reasons\":" +
      strings_json(decision.evaluation.reasons()) +
      "}",
    )
  }
  output.write_string("]}")
  output.to_string()
}
