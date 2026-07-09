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
