// Call Experian/Equifax for credit bureau report
function "external/call_credit_bureau" {
  description = "Initiates credit pull from Experian/Equifax with FCRA disclosure"
  input {
    int application_id
    int applicant_id
    text bureau?="experian" {
      description = "Bureau to query: experian or equifax"
    }
  }
  stack {
    db.get applicant {
      field_name = "id"
      field_value = $input.applicant_id
    } as $applicant

    precondition ($applicant != null) {
      error_type = "notfound"
      error = "Applicant not found"
    }

    // Generate FCRA disclosure ID
    security.create_uuid as $fcra_disclosure_id

    // Record FCRA disclosure before pulling credit
    db.patch application {
      field_name = "id"
      field_value = $input.application_id
      data = {
        fcra_disclosure_id: $fcra_disclosure_id,
        fcra_disclosed_at: now,
        bureau_status: "pending"
      }
    }

    function.run "audit/write_audit_log" {
      input = {
        action: "fcra.disclosure_issued",
        resource_type: "application",
        resource_id: $input.application_id,
        application_id: $input.application_id,
        metadata: { fcra_disclosure_id: $fcra_disclosure_id, bureau: $input.bureau }
      }
    }

    // Determine bureau URL
    var $bureau_url { value = $env.EXPERIAN_API_URL }
    var $bureau_key { value = $env.EXPERIAN_API_KEY }
    conditional {
      if ($input.bureau == "equifax") {
        var.update $bureau_url { value = $env.EQUIFAX_API_URL }
        var.update $bureau_key { value = $env.EQUIFAX_API_KEY }
      }
    }

    try_catch {
      try {
        api.request {
          url = $bureau_url ~ "/credit-report"
          method = "POST"
          params = {
            first_name: $applicant.first_name,
            last_name: $applicant.last_name,
            ssn: $applicant.ssn,
            date_of_birth: $applicant.date_of_birth,
            address: $applicant.address,
            reference_id: $input.application_id|to_text,
            webhook_url: $env.APP_BASE_URL ~ "/api:loan-origination/webhooks/bureau"
          }
          headers = [
            "Content-Type: application/json",
            "Authorization: Bearer " ~ $bureau_key
          ]
          timeout = 30
        } as $bureau_result

        var $initiated { value = true }

        // Update application status
        db.patch application {
          field_name = "id"
          field_value = $input.application_id
          data = { status: "pending_bureau", updated_at: now }
        }

        function.run "audit/write_audit_log" {
          input = {
            action: "bureau.pull_initiated",
            resource_type: "application",
            resource_id: $input.application_id,
            application_id: $input.application_id,
            previous_state: "submitted",
            new_state: "pending_bureau",
            metadata: { bureau: $input.bureau }
          }
        }
      }
      catch {
        var $initiated { value = false }

        db.patch application {
          field_name = "id"
          field_value = $input.application_id
          data = { bureau_status: "error", updated_at: now }
        }

        function.run "audit/write_audit_log" {
          input = {
            action: "bureau.pull_error",
            resource_type: "application",
            resource_id: $input.application_id,
            application_id: $input.application_id,
            metadata: { bureau: $input.bureau, error: "Bureau API call failed" }
          }
        }
      }
    }
  }
  response = { initiated: $initiated, fcra_disclosure_id: $fcra_disclosure_id }
  guid = "mxmAJXyC7hHuAVNr1SHbS7PoOHI"
}