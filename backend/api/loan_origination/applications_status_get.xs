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
