// Outcome test: an otherwise-prime borrower flagged for KYC review is referred.
workflow_test "decisioning_kyc_review_referred" {
  tags = ["decisioning", "e2e"]
  stack {
    api.call "seed" verb=POST {
      api_group = "LoanOrigination"
    } as $seed

    function.call "decisioning/run_demo_scenario" {
      input = { annual_income: 150000, monthly_debt: 800, loan_amount: 25000, kyc_status: "review_required" }
    } as $decision

    expect.to_not_be_null ($decision)
    expect.to_equal ($decision.outcome) { value = "referred" }
  }
  guid = "Eomr7c90dUT6SmPOGSsAD6QyBqE"
}
