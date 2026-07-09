table risk_tier {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    timestamp updated_at?

    text name filters=trim {
      description = "Tier name: e.g. Prime, Near-Prime, Subprime"
    }
    int min_credit_score filters=min:300
    int max_credit_score filters=max:850
    decimal max_dti_ratio {
      description = "Maximum debt-to-income ratio (e.g. 0.43)"
    }
    decimal base_interest_rate {
      description = "Base APR for this tier"
    }
    decimal max_loan_amount {
      description = "Maximum loan amount for this tier"
    }
    bool auto_decision_eligible?=false {
      description = "Whether applications in this tier can be auto-decided"
    }
    bool is_active?=true
    int priority?=0 {
      description = "Lower number = evaluated first"
    }
    json additional_criteria? {
      description = "Additional criteria like min income, employment length"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "is_active"}]}
    {type: "btree", field: [{name: "priority"}]}
    {type: "btree|unique", field: [{name: "name"}]}
  ]
  guid = "WTzkxQeLbJl0dKW1rekYzYE7m0w"
}