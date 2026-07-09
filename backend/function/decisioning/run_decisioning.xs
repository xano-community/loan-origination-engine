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