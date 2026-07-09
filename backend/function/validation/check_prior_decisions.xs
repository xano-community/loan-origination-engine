// Check the Xano DB for prior decisions on an applicant
function "validation/check_prior_decisions" {
  description = "Queries prior decisions to prevent duplicate applications"
  input {
    int applicant_id
  }
  stack {
    // Find active or recently decided applications for this applicant
    var $thirty_days_ago { value = now|transform_timestamp:"-30 days" }

    db.query application {
      where = $db.application.applicant_id == $input.applicant_id && ($db.application.status == "submitted" || $db.application.status == "pending_bureau" || $db.application.status == "pending_kyc" || $db.application.status == "under_review" || $db.application.status == "approved" || $db.application.status == "conditionally_approved")
      return = { type: "list" }
    } as $active_applications

    // Get recent decisions (last 30 days)
    db.query decision {
      join = {
        app: {
          table: "application",
          type: "inner",
          where: $db.decision.application_id == $db.application.id
        }
      }
      where = $db.application.applicant_id == $input.applicant_id && $db.decision.created_at >= $thirty_days_ago
      sort = { created_at: "desc" }
      return = { type: "list" }
    } as $recent_decisions
  }
  response = {
    has_active_application: ($active_applications|count) > 0,
    active_application_count: $active_applications|count,
    recent_decisions: $recent_decisions
  }
  guid = "-6RPzacCwHcDcbdKD501ml4LPGo"
}