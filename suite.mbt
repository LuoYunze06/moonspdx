///|
pub enum ClaimRelation {
  EquivalentClaim
  ImplicationClaim
} derive(Eq, @debug.Debug)

///|
pub fn ClaimRelation::name(self : ClaimRelation) -> String {
  match self {
    EquivalentClaim => "equivalent"
    ImplicationClaim => "implies"
  }
}

///|
pub struct SemanticClaim {
  name : String
  relation : ClaimRelation
  left : Expression
  right : Expression
} derive(Eq, @debug.Debug)

///|
pub fn SemanticClaim::name(self : SemanticClaim) -> String {
  self.name
}

///|
pub fn SemanticClaim::relation(self : SemanticClaim) -> ClaimRelation {
  self.relation
}

///|
pub fn SemanticClaim::left(self : SemanticClaim) -> Expression {
  self.left
}

///|
pub fn SemanticClaim::right(self : SemanticClaim) -> Expression {
  self.right
}

///|
fn suite_trim(value : StringView) -> String {
  value.trim().to_owned()
}

///|
fn claim_name_exists(claims : Array[SemanticClaim], name : String) -> Bool {
  claims.any(fn(claim) { claim.name == name })
}

///|
fn parse_claim_relation(
  source : String,
  line_number : Int,
) -> Result[ClaimRelation, Diagnostic] {
  match source {
    "equivalent" => Ok(EquivalentClaim)
    "implies" => Ok(ImplicationClaim)
    other =>
      Err(
        Diagnostic::new(
          "claim.relation.invalid",
          "line[" + line_number.to_string() + "]",
          "claim relation is not supported",
          "equivalent or implies",
          other,
        ),
      )
  }
}

///|
fn parse_claim_expression(
  source : String,
  side : String,
  line_number : Int,
) -> Result[Expression, Diagnostic] {
  match parse_expression(source) {
    Ok(value) => Ok(value)
    Err(error) =>
      Err(
        Diagnostic::new(
          "claim.expression.invalid",
          "line[" + line_number.to_string() + "]." + side,
          "claim contains an invalid SPDX expression: " + error.code(),
          "a supported SPDX expression",
          source,
        ),
      )
  }
}

///|
/// Parse `name|equivalent|left|right` or `name|implies|premise|conclusion`.
/// Blank lines and lines beginning with `#` are ignored.
pub fn parse_claims(
  source : String,
) -> Result[Array[SemanticClaim], Diagnostic] {
  let lines : Array[StringView] = source.split("\n").collect()
  if lines.length() > 129 {
    return Err(
      Diagnostic::new(
        "claim.limit",
        "claims",
        "claim suite has too many lines",
        "at most 128 claim lines",
        lines.length().to_string(),
      ),
    )
  }
  let claims : Array[SemanticClaim] = []
  for line_number, raw_line in lines {
    let line = suite_trim(raw_line)
    if !line.is_empty() && !line.has_prefix("#") {
      let fields : Array[String] = line
        .split("|")
        .map(fn(value) { suite_trim(value) })
        .collect()
      if fields.length() != 4 {
        return Err(
          Diagnostic::new(
            "claim.fields.invalid",
            "line[" + line_number.to_string() + "]",
            "claim must contain four pipe-separated fields",
            "name|relation|left|right",
            line,
          ),
        )
      }
      if fields.any(fn(value) { value.is_empty() }) {
        return Err(
          Diagnostic::new(
            "claim.field.empty",
            "line[" + line_number.to_string() + "]",
            "claim fields cannot be empty",
            "four non-empty fields",
            line,
          ),
        )
      }
      if claim_name_exists(claims, fields[0]) {
        return Err(
          Diagnostic::new(
            "claim.name.duplicate",
            "line[" + line_number.to_string() + "]",
            "claim name appears more than once",
            "a unique claim name",
            fields[0],
          ),
        )
      }
      let relation = match parse_claim_relation(fields[1], line_number) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let left = match parse_claim_expression(fields[2], "left", line_number) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let right = match
        parse_claim_expression(fields[3], "right", line_number) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      claims.push({ name: fields[0], relation, left, right })
    }
  }
  if claims.is_empty() {
    Err(
      Diagnostic::new(
        "claim.empty", "claims", "claim suite contains no claims", "at least one semantic claim",
        "empty",
      ),
    )
  } else {
    Ok(claims)
  }
}

///|
pub struct ClaimResult {
  claim : SemanticClaim
  proof : SemanticProof
} derive(Eq, @debug.Debug)

///|
pub fn ClaimResult::claim(self : ClaimResult) -> SemanticClaim {
  self.claim
}

///|
pub fn ClaimResult::proof(self : ClaimResult) -> SemanticProof {
  self.proof
}

///|
pub struct ProofSuite {
  results : Array[ClaimResult]
  passed : Int
  failed : Int
} derive(Eq, @debug.Debug)

///|
pub fn ProofSuite::results(self : ProofSuite) -> Array[ClaimResult] {
  self.results
}

///|
pub fn ProofSuite::passed(self : ProofSuite) -> Int {
  self.passed
}

///|
pub fn ProofSuite::failed(self : ProofSuite) -> Int {
  self.failed
}

///|
pub fn ProofSuite::all_proven(self : ProofSuite) -> Bool {
  self.failed == 0
}

///|
pub fn verify_claims(source : String) -> Result[ProofSuite, Diagnostic] {
  let claims = match parse_claims(source) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let results : Array[ClaimResult] = []
  let mut passed = 0
  let mut failed = 0
  for claim in claims {
    let proof = match claim.relation {
      EquivalentClaim => prove_equivalent(claim.left, claim.right)
      ImplicationClaim => prove_implication(claim.left, claim.right)
    }
    if proof.holds() {
      passed = passed + 1
    } else {
      failed = failed + 1
    }
    results.push({ claim, proof })
  }
  Ok({ results, passed, failed })
}

///|
pub fn ProofSuite::to_text(self : ProofSuite) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "PROOF-SUITE claims=" +
    self.results.length().to_string() +
    " passed=" +
    self.passed.to_string() +
    " failed=" +
    self.failed.to_string(),
  )
  for result in self.results {
    output.write_string(
      "\n" +
      (if result.proof.holds() { "PROVEN " } else { "DISPROVEN " }) +
      result.claim.name +
      " relation=" +
      result.claim.relation.name(),
    )
    match result.proof.counterexample() {
      Some(value) => output.write_string(" witness=" + value.to_text())
      None => ()
    }
  }
  output.to_string()
}

///|
pub fn ProofSuite::to_json(self : ProofSuite) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "{\"all_proven\":" +
    bool_json(self.all_proven()) +
    ",\"passed\":" +
    self.passed.to_string() +
    ",\"failed\":" +
    self.failed.to_string() +
    ",\"results\":[",
  )
  for index, result in self.results {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string(
      "{\"name\":" +
      quote_json(result.claim.name) +
      ",\"proof\":" +
      result.proof.to_json() +
      "}",
    )
  }
  output.write_string("]}")
  output.to_string()
}
