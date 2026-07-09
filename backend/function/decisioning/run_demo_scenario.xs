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
