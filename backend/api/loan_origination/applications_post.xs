// POST /applications - Create a draft loan application (creates/links the applicant)
query "applications" verb=POST {
  api_group = "LoanOrigination"
  auth = "user"

  input {
    text first_name filters=trim
    text last_name filters=trim
    email email filters=trim|lower
    text phone? filters=trim
    text ssn? {
      sensitive = true
    }
    text date_of_birth?
    json address?
    text loan_type
    decimal loan_amount
    int loan_term_months?
    text purpose? filters=trim
    decimal annual_income?
    decimal monthly_debt?
  }

  stack {
    // Find an existing applicant by email, otherwise create one.
    function.run "validation/check_duplicate_applicant" {
      input = { email: $input.email }
    } as $dup

    var $applicant_id { value = null }
    conditional {
      if ($dup.is_duplicate == true) {
        var.update $applicant_id { value = $dup.existing_applicant_id }
      }
      else {
        db.add applicant {
          data = {
            first_name: $input.first_name,
            last_name: $input.last_name,
            email: $input.email,
            phone: $input.phone,
            ssn: $input.ssn,
            date_of_birth: $input.date_of_birth,
            address: $input.address
          }
        } as $new_applicant
        var.update $applicant_id { value = $new_applicant.id }
      }
    }

    // 30-day expiry window for stale-draft cleanup
    var $expires_at { value = now|add:2592000000 }

    db.add application {
      data = {
        applicant_id: $applicant_id,
        broker_id: $auth.id,
        status: "draft",
        loan_type: $input.loan_type,
        loan_amount: $input.loan_amount,
        loan_term_months: $input.loan_term_months,
        purpose: $input.purpose,
        annual_income: $input.annual_income,
        monthly_debt: $input.monthly_debt,
        expires_at: $expires_at
      }
    } as $application

    function.run "audit/write_audit_log" {
      input = {
        action: "application.created",
        resource_type: "application",
        resource_id: $application.id,
        application_id: $application.id,
        new_state: "draft",
        user_id: $auth.id
      }
    }
  }

  response = $application
  guid = "1PTJrv7M6MlfvUsh3wzHv1fRtR8"
}
