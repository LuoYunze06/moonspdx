///|
pub struct NoticeAction {
  component : String
  version : String
  selected_license : String
  obligation : String
} derive(Eq, @debug.Debug)

///|
pub fn NoticeAction::component(self : NoticeAction) -> String {
  self.component
}

///|
pub fn NoticeAction::version(self : NoticeAction) -> String {
  self.version
}

///|
pub fn NoticeAction::selected_license(self : NoticeAction) -> String {
  self.selected_license
}

///|
pub fn NoticeAction::obligation(self : NoticeAction) -> String {
  self.obligation
}

///|
pub struct NoticePlan {
  actions : Array[NoticeAction]
  components : Int
  obligation_kinds : Array[String]
} derive(Eq, @debug.Debug)

///|
pub fn NoticePlan::actions(self : NoticePlan) -> Array[NoticeAction] {
  self.actions.copy()
}

///|
pub fn NoticePlan::components(self : NoticePlan) -> Int {
  self.components
}

///|
pub fn NoticePlan::obligation_kinds(self : NoticePlan) -> Array[String] {
  self.obligation_kinds.copy()
}

///|
/// Convert an accepted audit into a mechanical compliance checklist.
pub fn notice_plan(report : AuditReport) -> Result[NoticePlan, Diagnostic] {
  if report.rejected_count() > 0 {
    return Err(
      Diagnostic::new(
        "notice.audit.rejected",
        "audit",
        "notice plan cannot be built while components are rejected",
        "audit without rejected components",
        report.rejected_count().to_string() + " rejected",
      ),
    )
  }
  if report.review_count() > 0 {
    return Err(
      Diagnostic::new(
        "notice.audit.review",
        "audit",
        "notice plan cannot replace unresolved policy review",
        "audit without review components",
        report.review_count().to_string() + " review",
      ),
    )
  }
  let actions = []
  let kinds = []
  for result in report.results {
    for obligation in result.evaluation.obligations().names() {
      actions.push({
        component: result.component.name,
        version: result.component.version,
        selected_license: result.evaluation.selected(),
        obligation,
      })
      if !contains_string(kinds, obligation) {
        kinds.push(obligation)
      }
    }
  }
  Ok({ actions, components: report.results.length(), obligation_kinds: kinds })
}

///|
pub fn NoticePlan::to_text(self : NoticePlan) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "NOTICE-PLAN components=" +
    self.components.to_string() +
    " actions=" +
    self.actions.length().to_string() +
    " kinds=" +
    join_text(self.obligation_kinds, ","),
  )
  for index, action in self.actions {
    output.write_string(
      "\n[ ] " +
      (index + 1).to_string() +
      " " +
      action.component +
      "@" +
      action.version +
      " " +
      action.obligation +
      " (" +
      action.selected_license +
      ")",
    )
  }
  output.to_string()
}

///|
pub fn NoticePlan::to_json(self : NoticePlan) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "{\"components\":" +
    self.components.to_string() +
    ",\"obligation_kinds\":" +
    strings_json(self.obligation_kinds) +
    ",\"actions\":[",
  )
  for index, action in self.actions {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string(
      "{\"component\":" +
      quote_json(action.component) +
      ",\"version\":" +
      quote_json(action.version) +
      ",\"selected_license\":" +
      quote_json(action.selected_license) +
      ",\"obligation\":" +
      quote_json(action.obligation) +
      "}",
    )
  }
  output.write_string("]}")
  output.to_string()
}
