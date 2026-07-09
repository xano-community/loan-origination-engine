workspace "Production #2" {
  acceptance = {ai_terms: false}
  preferences = {
    internal_docs    : false
    track_performance: true
    sql_names        : false
    sql_columns      : true
  }
}
---
table applicant {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    timestamp updated_at?

    text first_name filters=trim
    text last_name filters=trim
    email email filters=trim|lower {
      sensitive = true
    }
    text phone? filters=trim {
      sensitive = true
    }
    text ssn? {
      description = "Social Security Number - PoC stores as provided; encrypt at rest before production use"
      sensitive = true
    }
    date date_of_birth? {
      sensitive = true
    }
    json address? {
      description = "Structured address: street, city, state, zip"
    }
    text ssn_hash? {
      description = "Reserved for SSN-hash dedup; the shipped flow dedups applicants by email"
    }
    int user_id? {
      table = "user"
      description = "Linked user account if applicant has login"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "btree|unique", field: [{name: "email"}]}
    {type: "btree", field: [{name: "ssn_hash"}]}
    {type: "btree", field: [{name: "user_id"}]}
  ]
  guid = "nl1rZT5LccTJ9sQOWqeSSNAlvm8"
}
---
table application {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    timestamp updated_at?

    int applicant_id {
      table = "applicant"
    }
    int broker_id? {
      table = "user"
      description = "Broker who created the application"
    }
    int assigned_underwriter_id? {
      table = "user"
      description = "Underwriter assigned for review"
    }
    enum status?="draft" {
      values = ["draft", "submitted", "pending_bureau", "pending_kyc", "under_review", "approved", "conditionally_approved", "denied", "expired", "withdrawn"]
    }
    enum loan_type {
      values = ["personal", "auto", "mortgage", "business", "student"]
    }
    decimal loan_amount filters=min:0 {
      description = "Requested loan amount in USD"
    }
    int loan_term_months? {
      description = "Loan term in months"
    }
    decimal interest_rate? {
      description = "Assigned interest rate after decisioning"
    }
    text purpose? filters=trim
    decimal annual_income? filters=min:0
    decimal monthly_debt? filters=min:0
    decimal dti_ratio? {
      description = "Debt-to-income ratio calculated during decisioning"
    }

    // External verification results
    json plaid_cash_flow? {
      description = "Plaid cash flow verification result"
    }
    json bureau_report? {
      description = "Credit bureau report data (Experian/Equifax)"
    }
    int credit_score?
    json kyc_result? {
      description = "KYC/AML verification result (Alloy/Persona)"
    }
    enum kyc_status?="pending" {
      values = ["pending", "passed", "failed", "review_required"]
    }
    enum bureau_status?="pending" {
      values = ["pending", "received", "error"]
    }

    // Decisioning
    int risk_tier_id? {
      table = "risk_tier"
      description = "Assigned risk tier after decisioning"
    }
    json decision_factors? {
      description = "Factors that contributed to the decision"
    }

    // Compliance
    text fcra_disclosure_id? {
      description = "FCRA disclosure tracking ID"
    }
    timestamp fcra_disclosed_at?
    text ecoa_adverse_action_id? {
      description = "ECOA adverse action notice ID"
    }
    timestamp ecoa_notice_sent_at?
    text glba_privacy_notice_id? {
      description = "GLBA privacy notice tracking ID"
    }

    timestamp submitted_at?
    timestamp decided_at?
    timestamp expires_at? {
      description = "Application expiry timestamp for stale cleanup"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "applicant_id"}]}
    {type: "btree", field: [{name: "broker_id"}]}
    {type: "btree", field: [{name: "assigned_underwriter_id"}]}
    {type: "btree", field: [{name: "status"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "btree", field: [{name: "expires_at"}]}
    {type: "btree", field: [{name: "loan_type"}]}
  ]
  guid = "sZwwgvAA5uAqsOUS0Vk4qnONEVo"
}
---
table audit_log {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int user_id? {
      table = "user"
      description = "User who triggered the action"
    }
    int application_id? {
      table = "application"
    }
    text action {
      description = "Action performed: e.g. application.created, status.changed, decision.made"
    }
    text resource_type {
      description = "Resource type: application, applicant, decision"
    }
    int resource_id? {
      description = "ID of the affected resource"
    }
    text previous_state? {
      description = "Previous state/value before change"
    }
    text new_state? {
      description = "New state/value after change"
    }
    json metadata? {
      description = "Additional context for the audit entry"
    }
    text ip_address?
    text user_agent?

    // SOC2 compliance fields
    text session_id? {
      description = "Session identifier for SOC2 traceability"
    }
    text correlation_id? {
      description = "Request correlation ID for distributed tracing"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "user_id"}]}
    {type: "btree", field: [{name: "application_id"}]}
    {type: "btree", field: [{name: "action"}]}
    {type: "btree", field: [{name: "resource_type"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "btree", field: [{name: "correlation_id"}]}
  ]
  guid = "CjuN8c9QXyLbhZD82xUYBum4Z8s"
}
---
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
---
table notification_log {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int user_id? {
      table = "user"
    }
    int application_id? {
      table = "application"
    }
    enum channel {
      values = ["sms", "email", "push"]
    }
    enum provider {
      values = ["twilio", "sendgrid"]
    }
    text recipient {
      description = "Email address or phone number"
      sensitive = true
    }
    text template_id? {
      description = "Template identifier for the notification"
    }
    text subject?
    enum status?="pending" {
      values = ["pending", "sent", "delivered", "failed", "bounced"]
    }
    text provider_message_id? {
      description = "Message ID from Twilio/SendGrid"
    }
    text error_message?
    json metadata?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "user_id"}]}
    {type: "btree", field: [{name: "application_id"}]}
    {type: "btree", field: [{name: "status"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]
  guid = "ErtwezswqpA7U7VWFQbAjZ0pq9o"
}
---
table risk_tier {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    timestamp updated_at?

    text name filters=trim {
      description = "Tier name: e.g. Prime, Near-Prime, Subprime"
    }
    int min_credit_score filters=min:300
    int max_credit_score filters=max:850
    decimal max_dti_ratio {
      description = "Maximum debt-to-income ratio (e.g. 0.43)"
    }
    decimal base_interest_rate {
      description = "Base APR for this tier"
    }
    decimal max_loan_amount {
      description = "Maximum loan amount for this tier"
    }
    bool auto_decision_eligible?=false {
      description = "Whether applications in this tier can be auto-decided"
    }
    bool is_active?=true
    int priority?=0 {
      description = "Lower number = evaluated first"
    }
    json additional_criteria? {
      description = "Additional criteria like min income, employment length"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "is_active"}]}
    {type: "btree", field: [{name: "priority"}]}
    {type: "btree|unique", field: [{name: "name"}]}
  ]
  guid = "WTzkxQeLbJl0dKW1rekYzYE7m0w"
}
---
table user {
  auth = true

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }

    text name filters=trim
    email? email filters=trim|lower
    password? password filters=min:8|minAlpha:1|minDigit:1 {
      visibility = "internal"
    }
    enum role?="applicant" {
      values = ["broker", "underwriter", "applicant"]
    }
    bool is_active?=true
    timestamp updated_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "btree|unique", field: [{name: "email", op: "asc"}]}
    {type: "btree", field: [{name: "role"}]}
  ]

  guid = "tNqKWPuTmV9e1htoqdhA9JxE_UA"
}
---
table webhook_event {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    text source {
      description = "Webhook source: experian, equifax, alloy, persona"
    }
    text event_type {
      description = "Event type from the provider"
    }
    int application_id? {
      table = "application"
    }
    text external_reference_id? {
      description = "External provider reference ID"
    }
    json payload {
      description = "Raw webhook payload"
    }
    json headers? {
      description = "Incoming request headers for signature verification"
    }
    enum processing_status?="received" {
      values = ["received", "processing", "processed", "failed", "ignored"]
    }
    text error_message?
    bool signature_valid?
    timestamp processed_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "source"}]}
    {type: "btree", field: [{name: "application_id"}]}
    {type: "btree", field: [{name: "external_reference_id"}]}
    {type: "btree", field: [{name: "processing_status"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]
  guid = "4QxeX66G5KvjP2iB5q1XbhXpPL4"
}
---
// Write an audit log entry to the Xano DB for SOC2 compliance
function "audit/write_audit_log" {
  description = "Records audit trail entry for every state transition"
  input {
    text action
    text resource_type
    int resource_id?
    int application_id?
    text previous_state?
    text new_state?
    json metadata?
    int user_id? {
      description = "Acting user id; pass $auth.id from authenticated endpoints, omit for system/webhook calls"
    }
  }
  stack {
    security.create_uuid as $correlation_id

    db.add audit_log {
      data = {
        user_id: $input.user_id,
        application_id: $input.application_id,
        action: $input.action,
        resource_type: $input.resource_type,
        resource_id: $input.resource_id,
        previous_state: $input.previous_state,
        new_state: $input.new_state,
        metadata: $input.metadata,
        ip_address: $env.$remote_ip,
        correlation_id: $correlation_id
      }
    } as $log_entry
  }
  response = $log_entry
  guid = "lLqMRdn5juxspnWTaZN5uCTYSSk"
}
---
// Check if authenticated user has one of the required roles
function "auth/check_role" {
  description = "Validates that the current user has an allowed role"
  input {
    text[] allowed_roles
  }
  stack {
    precondition ($auth.id != null) {
      error_type = "accessdenied"
      error = "Authentication required"
    }

    db.get user {
      field_name = "id"
      field_value = $auth.id
    } as $user

    precondition ($user != null) {
      error_type = "accessdenied"
      error = "User not found"
    }

    var $role_matches { value = $input.allowed_roles|intersect:[$user.role] }
    precondition (($role_matches|count) > 0) {
      error_type = "accessdenied"
      error = "Insufficient permissions"
    }
  }
  response = $user
  guid = "rqjKym0UeeXpwRjs2wv-ibOSwPI"
}
---
// Issue GLBA privacy notice for the application
function "compliance/issue_glba_notice" {
  description = "Generates and records GLBA privacy notice for compliance"
  input {
    int application_id
  }
  stack {
    security.create_uuid as $glba_notice_id

    db.patch application {
      field_name = "id"
      field_value = $input.application_id
      data = { glba_privacy_notice_id: $glba_notice_id }
    }

    function.run "audit/write_audit_log" {
      input = {
        action: "glba.privacy_notice_issued",
        resource_type: "application",
        resource_id: $input.application_id,
        application_id: $input.application_id,
        metadata: { glba_notice_id: $glba_notice_id }
      }
    }
  }
  response = { glba_notice_id: $glba_notice_id }
  guid = "KJSfaUk0fU5RT8GCkVePi-MOnhQ"
}
---
// Deterministic, credential-free credit signals.
// This is the DEFAULT scoring path so the template runs end-to-end with no
// third-party credentials. It derives a credit score + DTI from the applicant's
// own financials. When real Experian/Equifax + Alloy/Persona are configured,
// the /webhooks/bureau and /webhooks/kyc endpoints overwrite these with live
// values before decisioning runs. Pure (no DB) so it is fully unit-testable.
function "decisioning/derive_internal_signals" {
  description = "Deterministic credit score + KYC status from applicant financials (credential-free default path)"
  input {
    decimal annual_income?
    decimal monthly_debt?
    decimal loan_amount
  }
  stack {
    var $income { value = $input.annual_income ?? 0 }
    var $debt { value = $input.monthly_debt ?? 0 }

    var $monthly_income { value = 0 }
    conditional {
      if ($income > 0) {
        var.update $monthly_income { value = $income / 12 }
      }
    }

    var $dti { value = 0 }
    conditional {
      if ($monthly_income > 0) {
        var.update $dti { value = $debt / $monthly_income }
      }
    }

    // Base score, adjusted by income band
    var $score { value = 500 }
    conditional {
      if ($income >= 120000) {
        var.update $score { value = $score + 260 }
      }
      elseif ($income >= 80000) {
        var.update $score { value = $score + 200 }
      }
      elseif ($income >= 55000) {
        var.update $score { value = $score + 130 }
      }
      elseif ($income >= 35000) {
        var.update $score { value = $score + 70 }
      }
    }

    // Loan-to-income penalty
    conditional {
      if ($income > 0) {
        var $lti { value = $input.loan_amount / $income }
        conditional {
          if ($lti > 5) {
            var.update $score { value = $score - 120 }
          }
          elseif ($lti > 3) {
            var.update $score { value = $score - 60 }
          }
        }
      }
    }

    // Debt-to-income penalty
    conditional {
      if ($dti > 0.5) {
        var.update $score { value = $score - 160 }
      }
      elseif ($dti > 0.43) {
        var.update $score { value = $score - 90 }
      }
      elseif ($dti > 0.3) {
        var.update $score { value = $score - 30 }
      }
    }

    // Clamp to the valid FICO range
    conditional {
      if ($score > 850) {
        var.update $score { value = 850 }
      }
    }
    conditional {
      if ($score < 300) {
        var.update $score { value = 300 }
      }
    }
  }
  response = { credit_score: $score, dti_ratio: $dti, kyc_status: "passed" }

  test "prime borrower scores high" {
    input = { annual_income: 150000, monthly_debt: 800, loan_amount: 25000 }
    expect.to_be_greater_than ($response.credit_score) { value = 719 }
  }

  test "high DTI subprime borrower scores low" {
    input = { annual_income: 30000, monthly_debt: 1400, loan_amount: 20000 }
    expect.to_be_less_than ($response.credit_score) { value = 580 }
  }

  test "mid-income borrower lands in subprime band" {
    input = { annual_income: 60000, monthly_debt: 900, loan_amount: 15000 }
    expect.to_be_within ($response.credit_score) {
      min = 580
      max = 659
    }
  }

  test "score is clamped to fico floor" {
    input = { annual_income: 20000, monthly_debt: 1800, loan_amount: 90000 }
    expect.to_be_greater_than ($response.credit_score) { value = 299 }
  }

  test "kyc defaults to passed credential-free" {
    input = { annual_income: 150000, monthly_debt: 800, loan_amount: 25000 }
    expect.to_equal ($response.kyc_status) { value = "passed" }
  }
  guid = "Stiis13t26hISOa9usZCKeRvDx4"
}
---
// Core decisioning engine using configurable risk tiers
function "decisioning/run_decisioning" {
  description = "Evaluates application against risk tiers and produces a decision"
  input {
    int application_id
    int decided_by? {
      description = "Acting user id (pass $auth.id from an authenticated caller; null for system/demo runs)"
    }
  }
  stack {
    db.get application {
      field_name = "id"
      field_value = $input.application_id
    } as $app

    precondition ($app != null) {
      error_type = "notfound"
      error = "Application not found"
    }

    // Fetch all active risk tiers ordered by priority
    db.query risk_tier {
      where = $db.risk_tier.is_active == true
      sort = { priority: "asc" }
      return = { type: "list" }
    } as $tiers

    // Calculate DTI ratio
    var $dti { value = 0 }
    conditional {
      if ($app.annual_income != null && $app.annual_income > 0) {
        var $monthly_income { value = $app.annual_income / 12 }
        var.update $dti { value = ($app.monthly_debt ?? 0) / $monthly_income }
      }
    }

    // Update DTI on application
    db.patch application {
      field_name = "id"
      field_value = $input.application_id
      data = { dti_ratio: $dti }
    }

    var $matched_tier { value = null }
    var $decision_factors { value = [] }
    var $denial_reasons { value = [] }

    // Evaluate against tiers
    foreach ($tiers) {
      each as $tier {
        conditional {
          if ($matched_tier == null) {
            var $tier_eligible { value = true }

            // Check credit score
            conditional {
              if ($app.credit_score != null) {
                conditional {
                  if ($app.credit_score < $tier.min_credit_score || $app.credit_score > $tier.max_credit_score) {
                    var.update $tier_eligible { value = false }
                    var.update $decision_factors {
                      value = $decision_factors|push:("Credit score " ~ ($app.credit_score|to_text) ~ " outside tier range " ~ ($tier.min_credit_score|to_text) ~ "-" ~ ($tier.max_credit_score|to_text))
                    }
                  }
                }
              }
              else {
                var.update $tier_eligible { value = false }
                var.update $decision_factors { value = $decision_factors|push:"No credit score available" }
              }
            }

            // Check DTI
            conditional {
              if ($dti > $tier.max_dti_ratio) {
                var.update $tier_eligible { value = false }
                var.update $decision_factors {
                  value = $decision_factors|push:("DTI ratio " ~ ($dti|round:2|to_text) ~ " exceeds max " ~ ($tier.max_dti_ratio|to_text))
                }
              }
            }

            // Check loan amount
            conditional {
              if ($app.loan_amount > $tier.max_loan_amount) {
                var.update $tier_eligible { value = false }
                var.update $decision_factors {
                  value = $decision_factors|push:("Loan amount exceeds tier max of " ~ ($tier.max_loan_amount|to_text))
                }
              }
            }

            // Check KYC
            conditional {
              if ($app.kyc_status == "failed") {
                var.update $tier_eligible { value = false }
                var.update $denial_reasons { value = $denial_reasons|push:"KYC verification failed" }
              }
            }

            conditional {
              if ($tier_eligible == true) {
                var.update $matched_tier { value = $tier }
              }
            }
          }
        }
      }
    }

    // Determine outcome
    var $outcome { value = "denied" }
    var $decision_type { value = "auto_deny" }
    var $approved_amount { value = null }
    var $approved_rate { value = null }

    conditional {
      if ($matched_tier != null) {
        conditional {
          if ($matched_tier.auto_decision_eligible == true && $app.kyc_status == "passed") {
            var.update $outcome { value = "approved" }
            var.update $decision_type { value = "auto_approve" }
            var.update $approved_amount { value = $app.loan_amount }
            var.update $approved_rate { value = $matched_tier.base_interest_rate }
          }
          elseif ($app.kyc_status == "review_required") {
            var.update $outcome { value = "referred" }
            var.update $decision_type { value = "referral" }
          }
          else {
            var.update $outcome { value = "conditionally_approved" }
            var.update $decision_type { value = "conditional_approve" }
            var.update $approved_amount { value = $app.loan_amount }
            var.update $approved_rate { value = $matched_tier.base_interest_rate }
          }
        }
      }
      else {
        // No matching tier — denial
        conditional {
          if (($denial_reasons|count) == 0) {
            var.update $denial_reasons { value = $denial_reasons|push:"Does not meet minimum credit criteria" }
          }
        }
      }
    }

    // Create decision record
    db.add decision {
      data = {
        application_id: $input.application_id,
        decided_by: $input.decided_by,
        decision_type: $decision_type,
        outcome: $outcome,
        risk_tier_id: $matched_tier.id ?? null,
        approved_amount: $approved_amount,
        approved_rate: $approved_rate,
        approved_term_months: $app.loan_term_months,
        denial_reasons: $denial_reasons,
        decision_factors: $decision_factors,
        adverse_action_required: $outcome == "denied"
      }
    } as $decision_record

    // Map outcome to application status
    var $app_status { value = "denied" }
    conditional {
      if ($outcome == "approved") {
        var.update $app_status { value = "approved" }
      }
      elseif ($outcome == "conditionally_approved") {
        var.update $app_status { value = "conditionally_approved" }
      }
      elseif ($outcome == "referred") {
        var.update $app_status { value = "under_review" }
      }
    }

    // Update application
    db.patch application {
      field_name = "id"
      field_value = $input.application_id
      data = {
        status: $app_status,
        risk_tier_id: $matched_tier.id ?? null,
        interest_rate: $approved_rate,
        decision_factors: $decision_factors,
        decided_at: now,
        updated_at: now
      }
    }

    // Audit log
    function.run "audit/write_audit_log" {
      input = {
        action: "decision.made",
        resource_type: "decision",
        resource_id: $decision_record.id,
        application_id: $input.application_id,
        new_state: $outcome,
        user_id: $input.decided_by,
        metadata: {
          decision_type: $decision_type,
          risk_tier: $matched_tier.name ?? "none",
          credit_score: $app.credit_score,
          dti_ratio: $dti
        }
      }
    }

    // ECOA adverse action logging for denials
    conditional {
      if ($outcome == "denied") {
        security.create_uuid as $ecoa_notice_id

        db.patch application {
          field_name = "id"
          field_value = $input.application_id
          data = {
            ecoa_adverse_action_id: $ecoa_notice_id,
            ecoa_notice_sent_at: now
          }
        }

        db.patch decision {
          field_name = "id"
          field_value = $decision_record.id
          data = {
            adverse_action_notice_id: $ecoa_notice_id,
            adverse_action_sent_at: now
          }
        }

        function.run "audit/write_audit_log" {
          input = {
            action: "ecoa.adverse_action_notice",
            resource_type: "application",
            resource_id: $input.application_id,
            application_id: $input.application_id,
            user_id: $input.decided_by,
            metadata: {
              ecoa_notice_id: $ecoa_notice_id,
              denial_reasons: $denial_reasons
            }
          }
        }

        // Send adverse action notification
        function.run "notifications/send_notification" {
          input = {
            application_id: $input.application_id,
            template_id: "adverse_action_notice",
            channel: "email"
          }
        }
      }
    }

    // Send decision notification
    function.run "notifications/send_notification" {
      input = {
        application_id: $input.application_id,
        template_id: "decision_" ~ $outcome,
        channel: "email"
      }
    }
  }
  response = $decision_record
  guid = "QGBOXT2iprh8Wf-hG2IKH8Ur6PY"
}
---
// Self-contained demo harness: build an applicant + application from raw financials,
// apply credential-free (or overridden) signals, run the decisioning engine, and
// return the resulting decision -- all in one call context. Powers the PoC demo UI
// and the end-to-end outcome workflow tests (a function.call'd function can't see a
// test stack's uncommitted rows, so the whole flow must happen inside one function).
function "decisioning/run_demo_scenario" {
  description = "Create a throwaway applicant+application, run decisioning, return the decision"
  input {
    decimal annual_income?
    decimal monthly_debt?
    decimal loan_amount
    int credit_score? {
      description = "Optional override for the derived score (demo/testing)"
    }
    text kyc_status? {
      description = "Optional KYC override: passed | failed | review_required"
    }
  }
  stack {
    security.create_uuid as $uid

    db.add applicant {
      data = {
        first_name: "Demo",
        last_name: "Scenario",
        email: $uid ~ "@demo.test"
      }
    } as $applicant

    function.run "decisioning/derive_internal_signals" {
      input = {
        annual_income: $input.annual_income,
        monthly_debt: $input.monthly_debt,
        loan_amount: $input.loan_amount
      }
    } as $signals

    var $credit_score { value = $signals.credit_score }
    conditional {
      if ($input.credit_score != null && $input.credit_score > 0) {
        var.update $credit_score { value = $input.credit_score }
      }
    }

    var $kyc_status { value = $signals.kyc_status }
    conditional {
      if ($input.kyc_status != null && $input.kyc_status != "") {
        var.update $kyc_status { value = $input.kyc_status }
      }
    }

    db.add application {
      data = {
        applicant_id: $applicant.id,
        status: "submitted",
        loan_type: "personal",
        loan_amount: $input.loan_amount,
        annual_income: $input.annual_income,
        monthly_debt: $input.monthly_debt,
        credit_score: $credit_score,
        kyc_status: $kyc_status,
        submitted_at: now
      }
    } as $app

    function.run "decisioning/run_decisioning" {
      input = { application_id: $app.id }
    } as $decision
  }
  response = $decision
  guid = "auLNjPk-Do9l8cI9T4iV623FuZA"
}
---
// Call Experian/Equifax for credit bureau report
function "external/call_credit_bureau" {
  description = "Initiates credit pull from Experian/Equifax with FCRA disclosure"
  input {
    int application_id
    int applicant_id
    text bureau?="experian" {
      description = "Bureau to query: experian or equifax"
    }
  }
  stack {
    db.get applicant {
      field_name = "id"
      field_value = $input.applicant_id
    } as $applicant

    precondition ($applicant != null) {
      error_type = "notfound"
      error = "Applicant not found"
    }

    // Generate FCRA disclosure ID
    security.create_uuid as $fcra_disclosure_id

    // Record FCRA disclosure before pulling credit
    db.patch application {
      field_name = "id"
      field_value = $input.application_id
      data = {
        fcra_disclosure_id: $fcra_disclosure_id,
        fcra_disclosed_at: now,
        bureau_status: "pending"
      }
    }

    function.run "audit/write_audit_log" {
      input = {
        action: "fcra.disclosure_issued",
        resource_type: "application",
        resource_id: $input.application_id,
        application_id: $input.application_id,
        metadata: { fcra_disclosure_id: $fcra_disclosure_id, bureau: $input.bureau }
      }
    }

    // Determine bureau URL
    var $bureau_url { value = $env.EXPERIAN_API_URL }
    var $bureau_key { value = $env.EXPERIAN_API_KEY }
    conditional {
      if ($input.bureau == "equifax") {
        var.update $bureau_url { value = $env.EQUIFAX_API_URL }
        var.update $bureau_key { value = $env.EQUIFAX_API_KEY }
      }
    }

    try_catch {
      try {
        api.request {
          url = $bureau_url ~ "/credit-report"
          method = "POST"
          params = {
            first_name: $applicant.first_name,
            last_name: $applicant.last_name,
            ssn: $applicant.ssn,
            date_of_birth: $applicant.date_of_birth,
            address: $applicant.address,
            reference_id: $input.application_id|to_text,
            webhook_url: $env.APP_BASE_URL ~ "/api:loan-origination/webhooks/bureau"
          }
          headers = [
            "Content-Type: application/json",
            "Authorization: Bearer " ~ $bureau_key
          ]
          timeout = 30
        } as $bureau_result

        var $initiated { value = true }

        // Update application status
        db.patch application {
          field_name = "id"
          field_value = $input.application_id
          data = { status: "pending_bureau", updated_at: now }
        }

        function.run "audit/write_audit_log" {
          input = {
            action: "bureau.pull_initiated",
            resource_type: "application",
            resource_id: $input.application_id,
            application_id: $input.application_id,
            previous_state: "submitted",
            new_state: "pending_bureau",
            metadata: { bureau: $input.bureau }
          }
        }
      }
      catch {
        var $initiated { value = false }

        db.patch application {
          field_name = "id"
          field_value = $input.application_id
          data = { bureau_status: "error", updated_at: now }
        }

        function.run "audit/write_audit_log" {
          input = {
            action: "bureau.pull_error",
            resource_type: "application",
            resource_id: $input.application_id,
            application_id: $input.application_id,
            metadata: { bureau: $input.bureau, error: "Bureau API call failed" }
          }
        }
      }
    }
  }
  response = { initiated: $initiated, fcra_disclosure_id: $fcra_disclosure_id }
  guid = "mxmAJXyC7hHuAVNr1SHbS7PoOHI"
}
---
// Call Alloy or Persona for KYC/AML verification
function "external/call_kyc" {
  description = "Initiates KYC/AML verification via Alloy or Persona"
  input {
    int application_id
    int applicant_id
    text provider?="alloy" {
      description = "KYC provider: alloy or persona"
    }
  }
  stack {
    db.get applicant {
      field_name = "id"
      field_value = $input.applicant_id
    } as $applicant

    precondition ($applicant != null) {
      error_type = "notfound"
      error = "Applicant not found"
    }

    var $kyc_url { value = $env.ALLOY_API_URL }
    var $kyc_key { value = $env.ALLOY_API_KEY }
    var $kyc_secret { value = $env.ALLOY_API_SECRET }

    conditional {
      if ($input.provider == "persona") {
        var.update $kyc_url { value = $env.PERSONA_API_URL }
        var.update $kyc_key { value = $env.PERSONA_API_KEY }
        var.update $kyc_secret { value = "" }
      }
    }

    try_catch {
      try {
        api.request {
          url = $kyc_url ~ "/evaluations"
          method = "POST"
          params = {
            name_first: $applicant.first_name,
            name_last: $applicant.last_name,
            email_address: $applicant.email,
            phone_number: $applicant.phone,
            birth_date: $applicant.date_of_birth,
            document_ssn: $applicant.ssn,
            address_line_1: $applicant.address|get:"street",
            address_city: $applicant.address|get:"city",
            address_state: $applicant.address|get:"state",
            address_postal_code: $applicant.address|get:"zip",
            external_entity_id: $input.application_id|to_text,
            webhook_url: $env.APP_BASE_URL ~ "/api:loan-origination/webhooks/kyc"
          }
          headers = [
            "Content-Type: application/json",
            "Authorization: Bearer " ~ $kyc_key
          ]
          timeout = 30
        } as $kyc_result

        var $initiated { value = true }

        db.patch application {
          field_name = "id"
          field_value = $input.application_id
          data = { kyc_status: "pending", updated_at: now }
        }

        function.run "audit/write_audit_log" {
          input = {
            action: "kyc.verification_initiated",
            resource_type: "application",
            resource_id: $input.application_id,
            application_id: $input.application_id,
            metadata: { provider: $input.provider }
          }
        }
      }
      catch {
        var $initiated { value = false }

        function.run "audit/write_audit_log" {
          input = {
            action: "kyc.verification_error",
            resource_type: "application",
            resource_id: $input.application_id,
            application_id: $input.application_id,
            metadata: { provider: $input.provider, error: "KYC API call failed" }
          }
        }
      }
    }
  }
  response = { initiated: $initiated }
  guid = "CTPOuW-7kkFtJbwdxU8X93FgP-Q"
}
---
// Call Plaid API for cash flow verification
function "external/call_plaid" {
  description = "Calls Plaid API to verify applicant cash flow data"
  input {
    int application_id
    text access_token {
      description = "Plaid access token for the applicant's bank"
      sensitive = true
    }
  }
  stack {
    try_catch {
      try {
        api.request {
          url = $env.PLAID_BASE_URL ~ "/transactions/get"
          method = "POST"
          params = {
            client_id: $env.PLAID_CLIENT_ID,
            secret: $env.PLAID_SECRET,
            access_token: $input.access_token,
            start_date: now|transform_timestamp:"-90 days"|format_timestamp:"Y-m-d":"UTC",
            end_date: now|format_timestamp:"Y-m-d":"UTC"
          }
          headers = ["Content-Type: application/json"]
          timeout = 30
        } as $plaid_result

        precondition ($plaid_result.response.status >= 200 && $plaid_result.response.status < 300) {
          error_type = "standard"
          error = "Plaid API error: " ~ ($plaid_result.response.status|to_text)
        }

        var $cash_flow_data {
          value = {
            total_inflows: 0,
            total_outflows: 0,
            net_cash_flow: 0,
            transaction_count: $plaid_result.response.result.transactions|count,
            accounts: $plaid_result.response.result.accounts,
            retrieved_at: now
          }
        }

        // Update application with Plaid data
        db.patch application {
          field_name = "id"
          field_value = $input.application_id
          data = { plaid_cash_flow: $cash_flow_data }
        }

        // Audit log
        function.run "audit/write_audit_log" {
          input = {
            action: "plaid.cash_flow_retrieved",
            resource_type: "application",
            resource_id: $input.application_id,
            application_id: $input.application_id,
            new_state: "cash_flow_received"
          }
        }
      }
      catch {
        function.run "audit/write_audit_log" {
          input = {
            action: "plaid.cash_flow_error",
            resource_type: "application",
            resource_id: $input.application_id,
            application_id: $input.application_id,
            metadata: { error: "Plaid API call failed" }
          }
        }

        var $cash_flow_data {
          value = { error: "Plaid API call failed", retrieved_at: now }
        }
      }
    }
  }
  response = $cash_flow_data
  guid = "R2qZnLdpCsbZS95YXClEK8WlJSI"
}
---
// Send notifications via Twilio (SMS) or SendGrid (email)
function "notifications/send_notification" {
  description = "Dispatches notifications via Twilio SMS or SendGrid email"
  input {
    int application_id
    text template_id
    text channel?="email" {
      description = "Notification channel: email or sms"
    }
  }
  stack {
    db.get application {
      field_name = "id"
      field_value = $input.application_id
    } as $app

    precondition ($app != null) {
      error_type = "notfound"
      error = "Application not found"
    }

    db.get applicant {
      field_name = "id"
      field_value = $app.applicant_id
    } as $applicant

    var $provider { value = "sendgrid" }
    var $recipient { value = $applicant.email }
    var $subject { value = "Loan Application Update" }
    var $message_body { value = "Your loan application #" ~ ($app.id|to_text) ~ " has been updated." }

    // Build message based on template
    switch ($input.template_id) {
      case ("decision_approved") {
        var.update $subject { value = "Congratulations! Your Loan Application Has Been Approved" }
        var.update $message_body { value = "Your loan application #" ~ ($app.id|to_text) ~ " has been approved." }
      } break
      case ("decision_denied") {
        var.update $subject { value = "Update on Your Loan Application" }
        var.update $message_body { value = "We have completed our review of your loan application #" ~ ($app.id|to_text) ~ ". Unfortunately, we are unable to approve your application at this time. An adverse action notice with detailed reasons will follow." }
      } break
      case ("decision_conditionally_approved") {
        var.update $subject { value = "Your Loan Application - Conditional Approval" }
        var.update $message_body { value = "Your loan application #" ~ ($app.id|to_text) ~ " has been conditionally approved. Please review the conditions." }
      } break
      case ("adverse_action_notice") {
        var.update $subject { value = "Adverse Action Notice - Loan Application #" ~ ($app.id|to_text) }
        var.update $message_body { value = "This is a formal notice pursuant to the Equal Credit Opportunity Act regarding your loan application #" ~ ($app.id|to_text) ~ "." }
      } break
      case ("application_submitted") {
        var.update $subject { value = "Loan Application Received" }
        var.update $message_body { value = "Your loan application #" ~ ($app.id|to_text) ~ " has been submitted and is being processed." }
      } break
      case ("application_expiring") {
        var.update $subject { value = "Action Required: Your Loan Application Will Expire Soon" }
        var.update $message_body { value = "Your loan application #" ~ ($app.id|to_text) ~ " will expire soon. Please take action." }
      } break
      default {
        var.update $message_body { value = "Your loan application #" ~ ($app.id|to_text) ~ " status: " ~ $app.status }
      }
    }

    var $send_result { value = null }

    conditional {
      if ($input.channel == "sms" && $applicant.phone != null) {
        var.update $provider { value = "twilio" }
        var.update $recipient { value = $applicant.phone }

        try_catch {
          try {
            api.request {
              url = "https://api.twilio.com/2010-04-01/Accounts/" ~ $env.TWILIO_ACCOUNT_SID ~ "/Messages.json"
              method = "POST"
              params = {
                To: $applicant.phone,
                From: $env.TWILIO_PHONE_NUMBER,
                Body: $message_body
              }
              headers = [
                "Authorization: Basic " ~ (($env.TWILIO_ACCOUNT_SID ~ ":" ~ $env.TWILIO_AUTH_TOKEN)|base64_encode)
              ]
              timeout = 15
            } as $twilio_result

            var.update $send_result { value = $twilio_result.response.result }
          }
          catch {
            var.update $send_result { value = { error: "Twilio send failed" } }
          }
        }
      }
      else {
        // Send email via SendGrid
        try_catch {
          try {
            api.request {
              url = "https://api.sendgrid.com/v3/mail/send"
              method = "POST"
              params = {
                personalizations: [{ to: [{ email: $applicant.email }] }],
                from: { email: $env.SENDGRID_FROM_EMAIL, name: "Loan Services" },
                subject: $subject,
                content: [{ type: "text/plain", value: $message_body }]
              }
              headers = [
                "Content-Type: application/json",
                "Authorization: Bearer " ~ $env.SENDGRID_API_KEY
              ]
              timeout = 15
            } as $sg_result

            var.update $send_result { value = { status: "sent" } }
          }
          catch {
            var.update $send_result { value = { error: "SendGrid send failed" } }
          }
        }
      }
    }

    // Log notification
    var $notif_status { value = "sent" }
    var $error_msg { value = null }
    conditional {
      if ($send_result|has:"error") {
        var.update $notif_status { value = "failed" }
        var.update $error_msg { value = $send_result|get:"error" }
      }
    }

    db.add notification_log {
      data = {
        user_id: $app.broker_id,
        application_id: $input.application_id,
        channel: $input.channel,
        provider: $provider,
        recipient: $recipient,
        template_id: $input.template_id,
        subject: $subject,
        status: $notif_status,
        provider_message_id: $send_result|get:"sid":"",
        error_message: $error_msg
      }
    } as $notif_log
  }
  response = $notif_log
  guid = "KgOa49qik6y7LNNI4zDkjOkvlqU"
}
---
// Redact PII from applicant data before returning to client
function "pii/redact_applicant" {
  description = "Strips or masks PII fields from applicant records"
  input {
    json applicant_data
    bool full_redaction?=false {
      description = "If true, redacts all PII. If false, partial masking."
    }
  }
  stack {
    var $redacted { value = $input.applicant_data }

    conditional {
      if ($redacted|has:"ssn") {
        var.update $redacted { value = $redacted|set:"ssn":"***-**-****" }
      }
    }
    conditional {
      if ($redacted|has:"ssn_hash") {
        var.update $redacted { value = $redacted|set:"ssn_hash":"[REDACTED]" }
      }
    }
    conditional {
      if ($redacted|has:"date_of_birth") {
        conditional {
          if ($input.full_redaction == true) {
            var.update $redacted { value = $redacted|set:"date_of_birth":"****-**-**" }
          }
        }
      }
    }
    conditional {
      if ($redacted|has:"phone" && $input.full_redaction == true) {
        var $ph { value = $redacted|get:"phone" }
        conditional {
          if ($ph != null) {
            var.update $redacted { value = $redacted|set:"phone":"***-***-" ~ ($ph|substr:-4:4) }
          }
        }
      }
    }
  }
  response = $redacted
  guid = "ftCk-uhdR_1Ky961qVxo2YLcGYU"
}
---
// Check the Xano DB for a duplicate applicant by SSN hash or email
function "validation/check_duplicate_applicant" {
  description = "Detects duplicate applicants by SSN hash or email"
  input {
    text ssn_hash?
    email email? filters=trim|lower
    int exclude_id? {
      description = "Applicant ID to exclude (for updates)"
    }
  }
  stack {
    var $is_duplicate { value = false }
    var $duplicate_applicant_id { value = null }

    // Check by SSN hash first (strongest match)
    conditional {
      if ($input.ssn_hash != null) {
        db.query applicant {
          where = $db.applicant.ssn_hash == $input.ssn_hash && $db.applicant.id !=? $input.exclude_id
          return = { type: "single" }
        } as $ssn_match

        conditional {
          if ($ssn_match != null) {
            var.update $is_duplicate { value = true }
            var.update $duplicate_applicant_id { value = $ssn_match.id }
          }
        }
      }
    }

    // Check by email if no SSN match
    conditional {
      if ($is_duplicate == false && $input.email != null) {
        db.query applicant {
          where = $db.applicant.email == $input.email && $db.applicant.id !=? $input.exclude_id
          return = { type: "single" }
        } as $email_match

        conditional {
          if ($email_match != null) {
            var.update $is_duplicate { value = true }
            var.update $duplicate_applicant_id { value = $email_match.id }
          }
        }
      }
    }
  }
  response = { is_duplicate: $is_duplicate, existing_applicant_id: $duplicate_applicant_id }
  guid = "GbaRLUCN2ziR5P2aTEJb39VxYg4"
}
---
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
---
// Login and retrieve an authentication token
query "auth/login" verb=POST {
  api_group = "Authentication"

  input {
    email email? filters=trim|lower
    text password?
  }

  stack {
    db.get user {
      field_name = "email"
      field_value = $input.email
      output = ["id", "created_at", "name", "email", "password", "role"]
    } as $user
  
    precondition ($user != null) {
      error_type = "accessdenied"
      error = "Invalid Credentials."
    }
  
    security.check_password {
      text_password = $input.password
      hash_password = $user.password
    } as $pass_result
  
    precondition ($pass_result) {
      error_type = "accessdenied"
      error = "Invalid Credentials."
    }
  
    security.create_auth_token {
      table = "user"
      extras = { role: $user.role }
      expiration = 86400
      id = $user.id
    } as $authToken
  }

  response = {authToken: $authToken}
  guid = "aLivjsUUxQ7OEr0kTTRWg9Cki-U"
}
---
// Get the user record belonging to the authentication token
query "auth/me" verb=GET {
  api_group = "Authentication"
  auth = "user"

  input {
  }

  stack {
    db.get user {
      field_name = "id"
      field_value = $auth.id
      output = ["id", "created_at", "name", "email"]
    } as $user
  }

  response = $user
  guid = "biGXW-EyziOPdyC02YqJJoZyDuU"
}
---
// Signup and retrieve an authentication token
query "auth/signup" verb=POST {
  api_group = "Authentication"

  input {
    text name?
    email email? filters=trim|lower
    text password?
    text role?="applicant" {
      description = "User role: broker, underwriter, applicant"
    }
  }

  stack {
    db.get user {
      field_name = "email"
      field_value = $input.email
    } as $user
  
    precondition ($user == null) {
      error_type = "accessdenied"
      error = "This account is already in use."
    }
  
    db.add user {
      data = {
        created_at: "now"
        name      : $input.name
        email     : $input.email
        password  : $input.password
        role      : $input.role
      }
    } as $user
  
    security.create_auth_token {
      table = "user"
      extras = { role: $input.role }
      expiration = 86400
      id = $user.id
    } as $authToken
  }

  response = {authToken: $authToken}
  guid = "-Xcpv-BCuBYBRqODfXD4jApzyvo"
}
---
api_group Authentication {
  canonical = "BpEcuAp5"
  guid = "6PUOHA4eyrp1JSh5rpaVax7vjKE"
}
---
api_group LoanOrigination {
  canonical = "loan-origination"
  description = "Loan Origination API - Applications, Submissions, Status, and Webhooks"
  tags = ["loans", "origination", "compliance"]
  guid = "b5NrahUM79mHdL_YcS954FV49r8"
}
---
// POST /applications - Create a draft loan application (creates/links the applicant)
query "applications" verb=POST {
  api_group = "LoanOrigination"
  auth = "user"

  input {
    text first_name filters=trim
    text last_name filters=trim
    email email filters=trim|lower
    text phone? filters=trim
    text ssn? {
      sensitive = true
    }
    text date_of_birth?
    json address?
    text loan_type
    decimal loan_amount
    int loan_term_months?
    text purpose? filters=trim
    decimal annual_income?
    decimal monthly_debt?
  }

  stack {
    // Find an existing applicant by email, otherwise create one.
    function.run "validation/check_duplicate_applicant" {
      input = { email: $input.email }
    } as $dup

    var $applicant_id { value = null }
    conditional {
      if ($dup.is_duplicate == true) {
        var.update $applicant_id { value = $dup.existing_applicant_id }
      }
      else {
        db.add applicant {
          data = {
            first_name: $input.first_name,
            last_name: $input.last_name,
            email: $input.email,
            phone: $input.phone,
            ssn: $input.ssn,
            date_of_birth: $input.date_of_birth,
            address: $input.address
          }
        } as $new_applicant
        var.update $applicant_id { value = $new_applicant.id }
      }
    }

    // 30-day expiry window for stale-draft cleanup
    var $expires_at { value = now|add:2592000000 }

    db.add application {
      data = {
        applicant_id: $applicant_id,
        broker_id: $auth.id,
        status: "draft",
        loan_type: $input.loan_type,
        loan_amount: $input.loan_amount,
        loan_term_months: $input.loan_term_months,
        purpose: $input.purpose,
        annual_income: $input.annual_income,
        monthly_debt: $input.monthly_debt,
        expires_at: $expires_at
      }
    } as $application

    function.run "audit/write_audit_log" {
      input = {
        action: "application.created",
        resource_type: "application",
        resource_id: $application.id,
        application_id: $application.id,
        new_state: "draft",
        user_id: $auth.id
      }
    }
  }

  response = $application
  guid = "1PTJrv7M6MlfvUsh3wzHv1fRtR8"
}
---
// GET /applications/{id}/status - Get application status, decision, and details
query "applications/{application_id}/status" verb=GET {
  api_group = "LoanOrigination"
  description = "Retrieve current status, applicant (PII-redacted), and latest decision for a loan application"
  auth = "user"

  input {
    int application_id {
      table = "application"
    }
  }

  stack {
    function.run "auth/check_role" {
      input = { allowed_roles: ["broker", "underwriter", "applicant"] }
    } as $current_user

    db.get application {
      field_name = "id"
      field_value = $input.application_id
    } as $app

    precondition ($app != null) {
      error_type = "notfound"
      error = "Application not found"
    }

    db.get applicant {
      field_name = "id"
      field_value = $app.applicant_id
    } as $applicant

    // Applicants see fully-redacted PII; staff see partial masking.
    var $redact_full { value = true }
    conditional {
      if ($current_user.role == "broker" || $current_user.role == "underwriter") {
        var.update $redact_full { value = false }
      }
    }

    function.run "pii/redact_applicant" {
      input = { applicant_data: $applicant, full_redaction: $redact_full }
    } as $safe_applicant

    db.query decision {
      where = $db.decision.application_id == $input.application_id
      sort = { created_at: "desc" }
      return = { type: "single" }
    } as $latest_decision

    var $response_data {
      value = {
        application: {
          id: $app.id,
          status: $app.status,
          loan_type: $app.loan_type,
          loan_amount: $app.loan_amount,
          loan_term_months: $app.loan_term_months,
          interest_rate: $app.interest_rate,
          purpose: $app.purpose,
          dti_ratio: $app.dti_ratio,
          credit_score: $app.credit_score,
          kyc_status: $app.kyc_status,
          bureau_status: $app.bureau_status,
          submitted_at: $app.submitted_at,
          decided_at: $app.decided_at,
          expires_at: $app.expires_at,
          created_at: $app.created_at
        },
        applicant: $safe_applicant,
        decision: $latest_decision,
        compliance: {
          fcra_disclosure_id: $app.fcra_disclosure_id,
          ecoa_adverse_action_id: $app.ecoa_adverse_action_id,
          glba_privacy_notice_id: $app.glba_privacy_notice_id
        }
      }
    }
  }

  response = $response_data
  guid = "eQmiuXDY5EHKFOP6Gaylmy6CC9I"
}
---
// POST /applications/{id}/submit - Submit application; runs decisioning synchronously.
// Credential-free by default: internal deterministic scoring produces the credit
// score + KYC status, then the decisioning engine evaluates configured risk tiers.
// Optional credit_score / kyc_status inputs let a demo or test drive a specific
// scenario. Real bureau/KYC integration arrives via /webhooks/bureau + /webhooks/kyc.
query "applications/{application_id}/submit" verb=POST {
  api_group = "LoanOrigination"
  description = "Submit a draft application for underwriting and run decisioning."
  auth = "user"

  input {
    int application_id {
      table = "application"
    }
    int credit_score? {
      description = "Optional override for the derived credit score (demo/testing)"
    }
    text kyc_status? {
      description = "Optional KYC override: passed | failed | review_required (demo/testing)"
    }
  }

  stack {
    db.get application {
      field_name = "id"
      field_value = $input.application_id
    } as $app

    precondition ($app != null) {
      error_type = "notfound"
      error = "Application not found"
    }

    precondition ($app.status == "draft") {
      error_type = "inputerror"
      error = "Application must be in draft status to submit"
    }

    db.patch application {
      field_name = "id"
      field_value = $input.application_id
      data = {
        status: "submitted",
        submitted_at: now,
        updated_at: now
      }
    }

    function.run "audit/write_audit_log" {
      input = {
        action: "application.submitted",
        resource_type: "application",
        resource_id: $input.application_id,
        application_id: $input.application_id,
        previous_state: "draft",
        new_state: "submitted",
        user_id: $auth.id
      }
    }

    // Credential-free scoring (the default path).
    function.run "decisioning/derive_internal_signals" {
      input = {
        annual_income: $app.annual_income,
        monthly_debt: $app.monthly_debt,
        loan_amount: $app.loan_amount
      }
    } as $signals

    // Derived signals are the default; the optional inputs override only when set.
    // (Omitted optional inputs arrive as 0 / "" rather than null, so test explicitly.)
    var $credit_score { value = $signals.credit_score }
    conditional {
      if ($input.credit_score != null && $input.credit_score > 0) {
        var.update $credit_score { value = $input.credit_score }
      }
    }

    var $kyc_status { value = $signals.kyc_status }
    conditional {
      if ($input.kyc_status != null && $input.kyc_status != "") {
        var.update $kyc_status { value = $input.kyc_status }
      }
    }

    db.patch application {
      field_name = "id"
      field_value = $input.application_id
      data = {
        credit_score: $credit_score,
        kyc_status: $kyc_status,
        bureau_status: "received",
        updated_at: now
      }
    }

    // Run the decisioning engine against configured risk tiers.
    function.run "decisioning/run_decisioning" {
      input = { application_id: $input.application_id, decided_by: $auth.id }
    } as $decision
  }

  response = {
    application_id: $input.application_id,
    outcome: $decision.outcome,
    decision: $decision
  }
  guid = "foEc3uFLVCmVXdpIov-R8vWBGzA"
}
---
// POST /demo/run - Run a decisioning scenario from raw financials with no auth/setup.
// Powers the PoC demo UI's "try a scenario" buttons. Requires seed tiers to exist.
query "demo/run" verb=POST {
  api_group = "LoanOrigination"
  description = "Run the decisioning engine against ad-hoc financials and return the decision (demo convenience)."

  input {
    decimal annual_income?
    decimal monthly_debt?
    decimal loan_amount
    int credit_score?
    text kyc_status?
  }

  stack {
    function.run "decisioning/run_demo_scenario" {
      input = {
        annual_income: $input.annual_income,
        monthly_debt: $input.monthly_debt,
        loan_amount: $input.loan_amount,
        credit_score: $input.credit_score,
        kyc_status: $input.kyc_status
      }
    } as $decision
  }

  response = $decision
  guid = "RwX7vCeOyswXAK4Bv4TmRLEm5pY"
}
---
// POST /seed - Load demo reference data (risk tiers + demo users). Idempotent.
// This is the one-call loader that gives a forker a working demo out of the box.
query "seed" verb=POST {
  api_group = "LoanOrigination"
  description = "Loads demo risk tiers and demo users so the engine runs against seed data. Safe to call repeatedly."

  input {
  }

  stack {
    // --- Risk tiers (evaluated by priority ascending) ---
    var $tiers {
      value = [
        {
          name: "Prime",
          min_credit_score: 720,
          max_credit_score: 850,
          max_dti_ratio: 0.43,
          base_interest_rate: 6.5,
          max_loan_amount: 1000000,
          auto_decision_eligible: true,
          priority: 1
        },
        {
          name: "Near-Prime",
          min_credit_score: 660,
          max_credit_score: 719,
          max_dti_ratio: 0.45,
          base_interest_rate: 11.0,
          max_loan_amount: 150000,
          auto_decision_eligible: false,
          priority: 2
        },
        {
          name: "Subprime",
          min_credit_score: 580,
          max_credit_score: 659,
          max_dti_ratio: 0.5,
          base_interest_rate: 18.0,
          max_loan_amount: 40000,
          auto_decision_eligible: false,
          priority: 3
        }
      ]
    }

    var $tiers_created { value = 0 }
    foreach ($tiers) {
      each as $t {
        db.query risk_tier {
          where = $db.risk_tier.name == $t.name
          return = { type: "single" }
        } as $existing_tier
        conditional {
          if ($existing_tier == null) {
            db.add risk_tier {
              data = {
                name: $t.name,
                min_credit_score: $t.min_credit_score,
                max_credit_score: $t.max_credit_score,
                max_dti_ratio: $t.max_dti_ratio,
                base_interest_rate: $t.base_interest_rate,
                max_loan_amount: $t.max_loan_amount,
                auto_decision_eligible: $t.auto_decision_eligible,
                priority: $t.priority
              }
            } as $created_tier
            var.update $tiers_created { value = $tiers_created + 1 }
          }
        }
      }
    }

    // --- Demo users (password: Demo1234 for all) ---
    var $users {
      value = [
        { name: "Demo Broker", email: "broker@demo.test", role: "broker" },
        { name: "Demo Underwriter", email: "underwriter@demo.test", role: "underwriter" },
        { name: "Demo Applicant", email: "applicant@demo.test", role: "applicant" }
      ]
    }

    var $users_created { value = 0 }
    foreach ($users) {
      each as $u {
        db.get user {
          field_name = "email"
          field_value = $u.email
        } as $existing_user
        conditional {
          if ($existing_user == null) {
            db.add user {
              data = {
                name: $u.name,
                email: $u.email,
                password: "Demo1234",
                role: $u.role
              }
            } as $created_user
            var.update $users_created { value = $users_created + 1 }
          }
        }
      }
    }
  }

  response = {
    seeded: true,
    tiers_created: $tiers_created,
    users_created: $users_created,
    demo_credentials: {
      broker: "broker@demo.test / Demo1234",
      underwriter: "underwriter@demo.test / Demo1234",
      applicant: "applicant@demo.test / Demo1234"
    }
  }
  guid = "AkwWmTP7z_nWxYJB_7XeEH4Irvw"
}
---
// POST /webhooks/bureau - Receive credit bureau webhook callbacks
query "webhooks/bureau" verb=POST {
  api_group = "LoanOrigination"
  description = "Webhook endpoint for Experian/Equifax credit bureau report callbacks"

  input {
    text reference_id
    text event_type?
    int credit_score?
    json report_data?
    text status
  }

  stack {
    db.add webhook_event {
      data = {
        source: "bureau",
        event_type: $input.event_type ?? "credit_report",
        external_reference_id: $input.reference_id,
        payload: { credit_score: $input.credit_score, status: $input.status },
        processing_status: "received"
      }
    } as $webhook_log

    var $app_id { value = $input.reference_id|to_int }

    db.get application {
      field_name = "id"
      field_value = $app_id
    } as $app

    conditional {
      if ($app != null && $input.status == "completed") {
        db.patch application {
          field_name = "id"
          field_value = $app_id
          data = {
            credit_score: $input.credit_score,
            bureau_report: $input.report_data,
            bureau_status: "received",
            updated_at: now
          }
        } as $bureau_update

        function.run "audit/write_audit_log" {
          input = {
            action: "bureau.report_received",
            resource_type: "application",
            resource_id: $app_id,
            application_id: $app_id,
            new_state: "bureau_received"
          }
        } as $audit_entry
      }
    }

    db.patch webhook_event {
      field_name = "id"
      field_value = $webhook_log.id
      data = { processing_status: "processed", processed_at: now }
    } as $wh_final
  }

  response = { received: true }
  guid = "OcIG-_8bUYzL77Kj_8MvyTAUSbY"
}
---
// POST /webhooks/kyc - Receive KYC verification webhook callbacks
query "webhooks/kyc" verb=POST {
  api_group = "LoanOrigination"
  description = "Webhook endpoint for Alloy/Persona KYC verification callbacks"

  input {
    text external_entity_id
    text event_type?
    text outcome
    json verification_data?
  }

  stack {
    db.add webhook_event {
      data = {
        source: "kyc",
        event_type: $input.event_type ?? "kyc_verification",
        external_reference_id: $input.external_entity_id,
        payload: { outcome: $input.outcome },
        processing_status: "received"
      }
    } as $webhook_log

    var $app_id { value = $input.external_entity_id|to_int }

    db.get application {
      field_name = "id"
      field_value = $app_id
    } as $app

    var $kyc_status { value = "pending" }
    switch ($input.outcome) {
      case ("approved") {
        var.update $kyc_status { value = "passed" }
      } break
      case ("denied") {
        var.update $kyc_status { value = "failed" }
      } break
      case ("review") {
        var.update $kyc_status { value = "review_required" }
      } break
      default {
        var.update $kyc_status { value = "pending" }
      }
    }

    conditional {
      if ($app != null) {
        db.patch application {
          field_name = "id"
          field_value = $app_id
          data = {
            kyc_result: $input.verification_data,
            kyc_status: $kyc_status,
            updated_at: now
          }
        } as $kyc_update

        function.run "audit/write_audit_log" {
          input = {
            action: "kyc.verification_completed",
            resource_type: "application",
            resource_id: $app_id,
            application_id: $app_id,
            new_state: $kyc_status
          }
        } as $audit_entry
      }
    }

    db.patch webhook_event {
      field_name = "id"
      field_value = $webhook_log.id
      data = { processing_status: "processed", processed_at: now }
    } as $wh_final
  }

  response = { received: true }
  guid = "VXKOVhzY63cc9v3VAXQXcBDUBiI"
}
---
// Scheduled task to expire stale applications
// Runs daily to find applications past their expiry date
task "expire_stale_applications" {
  description = "Expires loan applications that have been stale past their expiry date. Sends notifications and logs audit trail."

  stack {
    // Find applications past expiry that are still in active states
    db.query application {
      where = $db.application.expires_at < now && ($db.application.status == "draft" || $db.application.status == "submitted" || $db.application.status == "pending_bureau" || $db.application.status == "pending_kyc")
      return = { type: "list" }
    } as $stale_apps

    var $expired_count { value = 0 }

    foreach ($stale_apps) {
      each as $app {
        try_catch {
          try {
            var $prev_status { value = $app.status }

            // Update status to expired
            db.patch application {
              field_name = "id"
              field_value = $app.id
              data = {
                status: "expired",
                updated_at: now
              }
            }

            // Audit log
            function.run "audit/write_audit_log" {
              input = {
                action: "application.expired",
                resource_type: "application",
                resource_id: $app.id,
                application_id: $app.id,
                previous_state: $prev_status,
                new_state: "expired",
                metadata: { expired_at: now, reason: "stale_application_expiry" }
              }
            }

            // Notify applicant
            function.run "notifications/send_notification" {
              input = {
                application_id: $app.id,
                template_id: "application_expiring",
                channel: "email"
              }
            }

            math.add $expired_count { value = 1 }
          }
          catch {
            debug.log { value = "Failed to expire application #" ~ ($app.id|to_text) }
          }
        }
      }
    }

    debug.log { value = "Expired " ~ ($expired_count|to_text) ~ " stale applications" }
  }

  schedule = [{starts_on: 2026-01-01 02:00:00+0000, freq: 86400}]
  guid = "PPl99SqwTXIxM7dn_be9xCa_KQo"
}
---
// Middleware to write audit log entries for every state transition
// Runs as post-middleware to capture the result of operations
middleware "audit_trail" {
  description = "Writes audit log entry to the Xano DB for SOC2 compliance"
  exception_policy = "silent"

  input {
    text action {
      description = "Action identifier e.g. application.created"
    }
    text resource_type {
      description = "Resource type: application, applicant, decision"
    }
    int resource_id?
    text previous_state?
    text new_state?
    json metadata?
  }

  stack {
    security.create_uuid as $correlation_id

    db.add audit_log {
      data = {
        user_id: $auth.id,
        action: $input.action,
        resource_type: $input.resource_type,
        resource_id: $input.resource_id,
        previous_state: $input.previous_state,
        new_state: $input.new_state,
        metadata: $input.metadata,
        ip_address: $env.$remote_ip,
        correlation_id: $correlation_id
      }
    } as $log_entry
  }

  response = null
  guid = "D1-TgVxEJShPA518BX2IpwT9bcU"
}
---
// Middleware to redact PII from API responses
// Strips sensitive fields before data leaves the system
middleware "pii_redaction" {
  description = "Redacts PII fields from response data for GLBA/SOC2 compliance"
  exception_policy = "silent"
  response_strategy = "replace"

  input {
    json original_response
  }

  stack {
    var $redacted { value = $input.original_response }

    // Redact SSN - replace with masked version
    conditional {
      if ($redacted|has:"ssn") {
        var.update $redacted { value = $redacted|set:"ssn":"***-**-****" }
      }
    }

    // Redact date of birth
    conditional {
      if ($redacted|has:"date_of_birth") {
        var.update $redacted { value = $redacted|set:"date_of_birth":"****-**-**" }
      }
    }

    // Redact phone if present
    conditional {
      if ($redacted|has:"phone") {
        var $phone_val { value = $redacted|get:"phone" }
        conditional {
          if ($phone_val != null) {
            var $masked_phone { value = "***-***-" ~ ($phone_val|substr:-4:4) }
            var.update $redacted { value = $redacted|set:"phone":$masked_phone }
          }
        }
      }
    }

    // Redact SSN hash
    conditional {
      if ($redacted|has:"ssn_hash") {
        var.update $redacted { value = $redacted|set:"ssn_hash":"[REDACTED]" }
      }
    }

    // Redact nested applicant data if present
    conditional {
      if ($redacted|has:"applicant") {
        var $app_data { value = $redacted|get:"applicant" }
        conditional {
          if ($app_data|has:"ssn") {
            var.update $app_data { value = $app_data|set:"ssn":"***-**-****" }
          }
        }
        conditional {
          if ($app_data|has:"date_of_birth") {
            var.update $app_data { value = $app_data|set:"date_of_birth":"****-**-**" }
          }
        }
        conditional {
          if ($app_data|has:"ssn_hash") {
            var.update $app_data { value = $app_data|set:"ssn_hash":"[REDACTED]" }
          }
        }
        var.update $redacted { value = $redacted|set:"applicant":$app_data }
      }
    }
  }

  response = $redacted
  guid = "WaV8cvt2ZnVXoVYCWByNqs-ttcs"
}
---
// Middleware to enforce role-based access control
// Checks that the authenticated user has one of the allowed roles
middleware "role_guard" {
  description = "Enforces role-based access control. Denies access if user role is not in allowed_roles."
  exception_policy = "rethrow"

  input {
    text[] allowed_roles {
      description = "List of roles permitted to access the endpoint"
    }
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "accessdenied"
      error = "Authentication required"
    }

    db.get user {
      field_name = "id"
      field_value = $auth.id
    } as $current_user

    precondition ($current_user != null) {
      error_type = "accessdenied"
      error = "User not found"
    }

    precondition ($input.allowed_roles|contains:$current_user.role) {
      error_type = "accessdenied"
      error = "Insufficient permissions. Required role: " ~ ($input.allowed_roles|join:", ")
    }
  }

  response = { user_role: $current_user.role }
  guid = "PnhzMn1xPUbTmUcrrz-ojukGBl0"
}
---
// Outcome test: an otherwise-prime borrower flagged for KYC review is referred.
workflow_test "decisioning_kyc_review_referred" {
  tags = ["decisioning", "e2e"]
  stack {
    api.call "seed" verb=POST {
      api_group = "LoanOrigination"
    } as $seed

    function.call "decisioning/run_demo_scenario" {
      input = { annual_income: 150000, monthly_debt: 800, loan_amount: 25000, kyc_status: "review_required" }
    } as $decision

    expect.to_not_be_null ($decision)
    expect.to_equal ($decision.outcome) { value = "referred" }
  }
  guid = "Eomr7c90dUT6SmPOGSsAD6QyBqE"
}
---
// Outcome test: a low-score / high-DTI borrower is denied with adverse action.
workflow_test "decisioning_low_score_denied" {
  tags = ["decisioning", "e2e", "critical"]
  stack {
    api.call "seed" verb=POST {
      api_group = "LoanOrigination"
    } as $seed

    function.call "decisioning/run_demo_scenario" {
      input = { annual_income: 30000, monthly_debt: 1400, loan_amount: 20000 }
    } as $decision

    expect.to_not_be_null ($decision)
    expect.to_equal ($decision.outcome) { value = "denied" }
    expect.to_be_true ($decision.adverse_action_required)
  }
  guid = "CXsuOP6jB_36_j2yGpUEOlXehQo"
}
---
// Outcome test: a prime borrower (derived score) is auto-approved end-to-end.
workflow_test "decisioning_prime_auto_approved" {
  tags = ["decisioning", "e2e", "critical"]
  stack {
    api.call "seed" verb=POST {
      api_group = "LoanOrigination"
    } as $seed

    function.call "decisioning/run_demo_scenario" {
      input = { annual_income: 150000, monthly_debt: 800, loan_amount: 25000 }
    } as $decision

    expect.to_not_be_null ($decision)
    expect.to_equal ($decision.outcome) { value = "approved" }
    expect.to_equal ($decision.decision_type) { value = "auto_approve" }
  }
  guid = "suMkhcjXXiKGF7mneoRJ8Hs-6zM"
}
---
// Outcome test: a subprime borrower in a non-auto tier is conditionally approved.
workflow_test "decisioning_subprime_conditional" {
  tags = ["decisioning", "e2e"]
  stack {
    api.call "seed" verb=POST {
      api_group = "LoanOrigination"
    } as $seed

    function.call "decisioning/run_demo_scenario" {
      input = { annual_income: 60000, monthly_debt: 900, loan_amount: 15000 }
    } as $decision

    expect.to_not_be_null ($decision)
    expect.to_equal ($decision.outcome) { value = "conditionally_approved" }
  }
  guid = "NCE56FgW3bSP66vpfNtHnzmS9Ts"
}
