///|
priv enum TokenKind {
  Identifier(String)
  AndKeyword
  OrKeyword
  WithKeyword
  LeftParen
  RightParen
  End
} derive(Eq)

///|
priv struct Token {
  kind : TokenKind
  offset : Int
}

///|
fn is_identifier_char(value : Char) -> Bool {
  (value >= 'a' && value <= 'z') ||
  (value >= 'A' && value <= 'Z') ||
  (value >= '0' && value <= '9') ||
  value == '-' ||
  value == '.' ||
  value == '+'
}

///|
fn classify_word(value : String) -> TokenKind {
  match value {
    "AND" => AndKeyword
    "OR" => OrKeyword
    "WITH" => WithKeyword
    _ => Identifier(value)
  }
}

///|
fn tokenize(source : String) -> Result[Array[Token], Diagnostic] {
  if source.length() > 4096 {
    return Err(
      Diagnostic::new(
        "expression.limit",
        "expression",
        "expression exceeds the safety limit",
        "at most 4096 characters",
        source.length().to_string(),
      ),
    )
  }
  let chars : Array[Char] = source.to_array()
  let tokens = []
  let mut index = 0
  while index < chars.length() {
    let current = chars[index]
    if current == ' ' || current == '\t' || current == '\r' || current == '\n' {
      index = index + 1
    } else if current == '(' {
      tokens.push({ kind: LeftParen, offset: index })
      index = index + 1
    } else if current == ')' {
      tokens.push({ kind: RightParen, offset: index })
      index = index + 1
    } else if is_identifier_char(current) {
      let start = index
      let output = StringBuilder::new()
      while index < chars.length() && is_identifier_char(chars[index]) {
        output.write_char(chars[index])
        index = index + 1
      }
      tokens.push({ kind: classify_word(output.to_string()), offset: start })
    } else {
      return Err(
        Diagnostic::new(
          "expression.character.invalid",
          source_location(index),
          "character is not valid in an SPDX expression",
          "identifier, whitespace, or parenthesis",
          current.to_string(),
        ),
      )
    }
  }
  tokens.push({ kind: End, offset: chars.length() })
  Ok(tokens)
}

///|
fn token_description(kind : TokenKind) -> String {
  match kind {
    Identifier(value) => value
    AndKeyword => "AND"
    OrKeyword => "OR"
    WithKeyword => "WITH"
    LeftParen => "("
    RightParen => ")"
    End => "end of expression"
  }
}

///|
fn validate_atom(id : String, offset : Int) -> Result[LicenseAtom, Diagnostic] {
  if id.has_prefix("LicenseRef-") || id.has_prefix("DocumentRef-") {
    return Err(
      Diagnostic::new(
        "expression.reference.unsupported",
        source_location(offset),
        "custom SPDX license references are outside the supported profile",
        "a catalog SPDX identifier",
        id,
      ),
    )
  }
  let normalized = match normalize_identifier(id) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if !is_known_license(normalized) {
    return Err(
      Diagnostic::new(
        "expression.license.unknown",
        source_location(offset),
        "license identifier is not in the supported catalog",
        "a supported SPDX license identifier",
        normalized,
      ),
    )
  }
  Ok(LicenseAtom::new(normalized))
}

///|
fn parse_primary(
  tokens : Array[Token],
  index : Int,
) -> Result[(Expression, Int), Diagnostic] {
  let token = tokens[index]
  match token.kind {
    Identifier(value) => {
      let atom = match validate_atom(value, token.offset) {
        Ok(result) => result
        Err(error) => return Err(error)
      }
      if tokens[index + 1].kind == WithKeyword {
        let exception_token = tokens[index + 2]
        match exception_token.kind {
          Identifier(exception) => {
            if !is_known_exception(exception) {
              return Err(
                Diagnostic::new(
                  "expression.exception.unknown",
                  source_location(exception_token.offset),
                  "exception identifier is not in the supported catalog",
                  "a supported SPDX exception identifier",
                  exception,
                ),
              )
            }
            Ok(
              (
                Atom(LicenseAtom::new(atom.id, exception=Some(exception))),
                index + 3,
              ),
            )
          }
          other =>
            Err(
              Diagnostic::new(
                "expression.exception.missing",
                source_location(exception_token.offset),
                "WITH must be followed by an exception identifier",
                "SPDX exception identifier",
                token_description(other),
              ),
            )
        }
      } else {
        Ok((Atom(atom), index + 1))
      }
    }
    LeftParen => {
      let nested = match parse_or(tokens, index + 1) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let closing = tokens[nested.1]
      if closing.kind != RightParen {
        return Err(
          Diagnostic::new(
            "expression.parenthesis.unclosed",
            source_location(closing.offset),
            "opening parenthesis has no matching close",
            ")",
            token_description(closing.kind),
          ),
        )
      }
      if tokens[nested.1 + 1].kind == WithKeyword {
        return Err(
          Diagnostic::new(
            "expression.with.composite",
            source_location(tokens[nested.1 + 1].offset),
            "WITH can attach only to a simple license identifier",
            "AND or OR after a parenthesized expression",
            "WITH",
          ),
        )
      }
      Ok((nested.0, nested.1 + 1))
    }
    End =>
      Err(
        Diagnostic::new(
          "expression.operand.missing",
          source_location(token.offset),
          "expression ended where a license was required",
          "license identifier or (",
          "end of expression",
        ),
      )
    other =>
      Err(
        Diagnostic::new(
          "expression.operand.invalid",
          source_location(token.offset),
          "operator appears where a license was required",
          "license identifier or (",
          token_description(other),
        ),
      )
  }
}

///|
fn parse_and(
  tokens : Array[Token],
  index : Int,
) -> Result[(Expression, Int), Diagnostic] {
  let first = match parse_primary(tokens, index) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let mut expression = first.0
  let mut cursor = first.1
  while tokens[cursor].kind == AndKeyword {
    let next = match parse_primary(tokens, cursor + 1) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    expression = And(expression, next.0)
    cursor = next.1
  }
  Ok((expression, cursor))
}

///|
fn parse_or(
  tokens : Array[Token],
  index : Int,
) -> Result[(Expression, Int), Diagnostic] {
  let first = match parse_and(tokens, index) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let mut expression = first.0
  let mut cursor = first.1
  while tokens[cursor].kind == OrKeyword {
    let next = match parse_and(tokens, cursor + 1) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    expression = Or(expression, next.0)
    cursor = next.1
  }
  Ok((expression, cursor))
}

///|
/// Parse and validate the supported SPDX 2.x expression profile.
pub fn parse_expression(source : String) -> Result[Expression, Diagnostic] {
  if source.trim().is_empty() {
    return Err(
      Diagnostic::new(
        "expression.empty", "expression", "license expression is empty", "SPDX license expression",
        "empty",
      ),
    )
  }
  let tokens = match tokenize(source) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let parsed = match parse_or(tokens, 0) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let trailing = tokens[parsed.1]
  match trailing.kind {
    End => Ok(parsed.0)
    RightParen =>
      Err(
        Diagnostic::new(
          "expression.parenthesis.unexpected",
          source_location(trailing.offset),
          "closing parenthesis has no matching open",
          "end of expression",
          ")",
        ),
      )
    other =>
      Err(
        Diagnostic::new(
          "expression.operator.missing",
          source_location(trailing.offset),
          "licenses must be joined by AND or OR",
          "AND, OR, or end of expression",
          token_description(other),
        ),
      )
  }
}

///|
pub fn normalize_expression(source : String) -> Result[String, Diagnostic] {
  match parse_expression(source) {
    Ok(value) => Ok(value.canonical())
    Err(error) => Err(error)
  }
}
