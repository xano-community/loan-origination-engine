// POST /seed - Load demo reference data (risk tiers + demo users). Idempotent.
// This is the one-call loader that gives a forker a working demo out of the box.
query "seed" verb=POST {
  api_group = "LoanOrigination"
  description = "Loads demo risk tiers and demo users so the engine runs against seed data. Safe to call repeatedly."

  input {
  }

  stack {
    // --- Risk tiers (evaluated by priority ascending) ---
    var $tiers {
      value = [
        {
          name: "Prime",
          min_credit_score: 720,
          max_credit_score: 850,
          max_dti_ratio: 0.43,
          base_interest_rate: 6.5,
          max_loan_amount: 1000000,
          auto_decision_eligible: true,
          priority: 1
        },
        {
          name: "Near-Prime",
          min_credit_score: 660,
          max_credit_score: 719,
          max_dti_ratio: 0.45,
          base_interest_rate: 11.0,
          max_loan_amount: 150000,
          auto_decision_eligible: false,
          priority: 2
        },
        {
          name: "Subprime",
          min_credit_score: 580,
          max_credit_score: 659,
          max_dti_ratio: 0.5,
          base_interest_rate: 18.0,
          max_loan_amount: 40000,
          auto_decision_eligible: false,
          priority: 3
        }
      ]
    }

    var $tiers_created { value = 0 }
    foreach ($tiers) {
      each as $t {
        db.query risk_tier {
          where = $db.risk_tier.name == $t.name
          return = { type: "single" }
        } as $existing_tier
        conditional {
          if ($existing_tier == null) {
            db.add risk_tier {
              data = {
                name: $t.name,
                min_credit_score: $t.min_credit_score,
                max_credit_score: $t.max_credit_score,
                max_dti_ratio: $t.max_dti_ratio,
                base_interest_rate: $t.base_interest_rate,
                max_loan_amount: $t.max_loan_amount,
                auto_decision_eligible: $t.auto_decision_eligible,
                priority: $t.priority
              }
            } as $created_tier
            var.update $tiers_created { value = $tiers_created + 1 }
          }
        }
      }
    }

    // --- Demo users (password: Demo1234 for all) ---
    var $users {
      value = [
        { name: "Demo Broker", email: "broker@demo.test", role: "broker" },
        { name: "Demo Underwriter", email: "underwriter@demo.test", role: "underwriter" },
        { name: "Demo Applicant", email: "applicant@demo.test", role: "applicant" }
      ]
    }

    var $users_created { value = 0 }
    foreach ($users) {
      each as $u {
        db.get user {
          field_name = "email"
          field_value = $u.email
        } as $existing_user
        conditional {
          if ($existing_user == null) {
            db.add user {
              data = {
                name: $u.name,
                email: $u.email,
                password: "Demo1234",
                role: $u.role
              }
            } as $created_user
            var.update $users_created { value = $users_created + 1 }
          }
        }
      }
    }
  }

  response = {
    seeded: true,
    tiers_created: $tiers_created,
    users_created: $users_created,
    demo_credentials: {
      broker: "broker@demo.test / Demo1234",
      underwriter: "underwriter@demo.test / Demo1234",
      applicant: "applicant@demo.test / Demo1234"
    }
  }
  guid = "AkwWmTP7z_nWxYJB_7XeEH4Irvw"
}
