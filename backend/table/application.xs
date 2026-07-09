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