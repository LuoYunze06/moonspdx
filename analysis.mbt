///|
pub struct ExpressionStats {
  atoms : Int
  and_operators : Int
  or_operators : Int
  depth : Int
  alternatives : Int
} derive(Eq, @debug.Debug)

///|
pub fn ExpressionStats::atoms(self : ExpressionStats) -> Int {
  self.atoms
}

///|
pub fn ExpressionStats::and_operators(self : ExpressionStats) -> Int {
  self.and_operators
}

///|
pub fn ExpressionStats::or_operators(self : ExpressionStats) -> Int {
  self.or_operators
}

///|
pub fn ExpressionStats::depth(self : ExpressionStats) -> Int {
  self.depth
}

///|
pub fn ExpressionStats::alternatives(self : ExpressionStats) -> Int {
  self.alternatives
}

///|
fn capped_product(left : Int, right : Int) -> Int {
  if left > 64 || right > 64 || left * right > 64 {
    65
  } else {
    left * right
  }
}

///|
pub fn Expression::stats(self : Expression) -> ExpressionStats {
  match self {
    Atom(_) =>
      { atoms: 1, and_operators: 0, or_operators: 0, depth: 1, alternatives: 1 }
    And(left, right) => {
      let a = left.stats()
      let b = right.stats()
      {
        atoms: a.atoms + b.atoms,
        and_operators: a.and_operators + b.and_operators + 1,
        or_operators: a.or_operators + b.or_operators,
        depth: 1 + max_int(a.depth, b.depth),
        alternatives: capped_product(a.alternatives, b.alternatives),
      }
    }
    Or(left, right) => {
      let a = left.stats()
      let b = right.stats()
      {
        atoms: a.atoms + b.atoms,
        and_operators: a.and_operators + b.and_operators,
        or_operators: a.or_operators + b.or_operators + 1,
        depth: 1 + max_int(a.depth, b.depth),
        alternatives: min_int(65, a.alternatives + b.alternatives),
      }
    }
  }
}

///|
fn combine_alternatives(
  left : Array[Array[LicenseAtom]],
  right : Array[Array[LicenseAtom]],
) -> Result[Array[Array[LicenseAtom]], Diagnostic] {
  let result = []
  for first in left {
    for second in right {
      if result.length() >= 64 {
        return Err(
          Diagnostic::new(
            "expression.alternatives.limit", "expression", "expanded alternatives exceed the safety limit",
            "at most 64 alternatives", "more than 64",
          ),
        )
      }
      let combined = first.copy()
      for atom in second {
        combined.push(atom)
      }
      result.push(combined)
    }
  }
  Ok(result)
}

///|
fn expand_expression(
  expression : Expression,
) -> Result[Array[Array[LicenseAtom]], Diagnostic] {
  match expression {
    Atom(atom) => Ok([[atom]])
    Or(left, right) => {
      let first = match expand_expression(left) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let second = match expand_expression(right) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      if first.length() + second.length() > 64 {
        return Err(
          Diagnostic::new(
            "expression.alternatives.limit",
            "expression",
            "expanded alternatives exceed the safety limit",
            "at most 64 alternatives",
            (first.length() + second.length()).to_string(),
          ),
        )
      }
      Ok(first + second)
    }
    And(left, right) => {
      let first = match expand_expression(left) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let second = match expand_expression(right) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      combine_alternatives(first, second)
    }
  }
}

///|
/// Expand an expression into at most 64 conjunctive alternatives.
pub fn Expression::alternatives(
  self : Expression,
) -> Result[Array[Array[LicenseAtom]], Diagnostic] {
  expand_expression(self)
}

///|
pub fn render_alternative(atoms : Array[LicenseAtom]) -> String {
  let values = atoms.map(fn(atom) { atom.canonical() })
  join_text(values, " AND ")
}

///|
fn max_int(left : Int, right : Int) -> Int {
  if left > right {
    left
  } else {
    right
  }
}

///|
fn min_int(left : Int, right : Int) -> Int {
  if left < right {
    left
  } else {
    right
  }
}
