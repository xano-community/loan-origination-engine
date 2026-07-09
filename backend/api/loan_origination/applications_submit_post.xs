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
