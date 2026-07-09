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
