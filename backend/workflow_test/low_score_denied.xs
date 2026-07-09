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
