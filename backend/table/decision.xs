table decision {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int application_id {
      table = "application"
    }
    int decided_by? {
      table = "user"
      description = "User who made or triggered the decision"
    }
    enum decision_type {
      values = ["auto_approve", "auto_deny", "manual_approve", "manual_deny", "conditional_approve", "referral"]
    }
    enum outcome {
      values = ["approved", "denied", "conditionally_approved", "referred"]
    }
    int risk_tier_id? {
      table = "risk_tier"
    }
    decimal approved_amount?
    decimal approved_rate?
    int approved_term_months?
    json conditions? {
      description = "Conditions for conditional approval"
    }
    json denial_reasons? {
      description = "ECOA-compliant adverse action reasons"
    }
    json decision_factors? {
      description = "All factors evaluated in decisioning"
    }
    text notes?

    // FCRA / ECOA compliance
    bool adverse_action_required?=false
    timestamp adverse_action_sent_at?
    text adverse_action_notice_id?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "application_id"}]}
    {type: "btree", field: [{name: "decided_by"}]}
    {type: "btree", field: [{name: "outcome"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]
  guid = "6um_GL4Wixb64Od_7MNLtkIr0tU"
}