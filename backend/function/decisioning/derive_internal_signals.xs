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
