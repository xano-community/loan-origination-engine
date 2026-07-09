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
