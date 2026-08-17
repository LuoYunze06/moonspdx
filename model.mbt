///|
pub struct LicenseAtom {
  id : String
  exception : String?
} derive(Eq, @debug.Debug)

///|
pub fn LicenseAtom::new(
  id : String,
  exception? : String? = None,
) -> LicenseAtom {
  { id, exception }
}

///|
pub fn LicenseAtom::id(self : LicenseAtom) -> String {
  self.id
}

///|
pub fn LicenseAtom::exception(self : LicenseAtom) -> String? {
  self.exception
}

///|
pub fn LicenseAtom::canonical(self : LicenseAtom) -> String {
  match self.exception {
    Some(value) => self.id + " WITH " + value
    None => self.id
  }
}

///|
pub enum Expression {
  Atom(LicenseAtom)
  And(Expression, Expression)
  Or(Expression, Expression)
} derive(Eq, @debug.Debug)

///|
fn expression_precedence(expression : Expression) -> Int {
  match expression {
    Atom(_) => 3
    And(_, _) => 2
    Or(_, _) => 1
  }
}

///|
fn render_expression(
  output : StringBuilder,
  expression : Expression,
  parent_precedence : Int,
) -> Unit {
  let precedence = expression_precedence(expression)
  let parentheses = precedence < parent_precedence
  if parentheses {
    output.write_char('(')
  }
  match expression {
    Atom(atom) => {
      output.write_string(atom.id)
      match atom.exception {
        Some(value) => output.write_string(" WITH " + value)
        None => ()
      }
    }
    And(left, right) => {
      render_expression(output, left, precedence)
      output.write_string(" AND ")
      render_expression(output, right, precedence)
    }
    Or(left, right) => {
      render_expression(output, left, precedence)
      output.write_string(" OR ")
      render_expression(output, right, precedence)
    }
  }
  if parentheses {
    output.write_char(')')
  }
}

///|
/// Render the expression with stable spacing and only semantic parentheses.
pub fn Expression::canonical(self : Expression) -> String {
  let output = StringBuilder::new()
  render_expression(output, self, 0)
  output.to_string()
}

///|
pub fn Expression::atoms(self : Expression) -> Array[LicenseAtom] {
  match self {
    Atom(value) => [value]
    And(left, right) | Or(left, right) => left.atoms() + right.atoms()
  }
}
