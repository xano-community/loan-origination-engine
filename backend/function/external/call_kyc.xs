// Call Alloy or Persona for KYC/AML verification
function "external/call_kyc" {
  description = "Initiates KYC/AML verification via Alloy or Persona"
  input {
    int application_id
    int applicant_id
    text provider?="alloy" {
      description = "KYC provider: alloy or persona"
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

    var $kyc_url { value = $env.ALLOY_API_URL }
    var $kyc_key { value = $env.ALLOY_API_KEY }
    var $kyc_secret { value = $env.ALLOY_API_SECRET }

    conditional {
      if ($input.provider == "persona") {
        var.update $kyc_url { value = $env.PERSONA_API_URL }
        var.update $kyc_key { value = $env.PERSONA_API_KEY }
        var.update $kyc_secret { value = "" }
      }
    }

    try_catch {
      try {
        api.request {
          url = $kyc_url ~ "/evaluations"
          method = "POST"
          params = {
            name_first: $applicant.first_name,
            name_last: $applicant.last_name,
            email_address: $applicant.email,
            phone_number: $applicant.phone,
            birth_date: $applicant.date_of_birth,
            document_ssn: $applicant.ssn,
            address_line_1: $applicant.address|get:"street",
            address_city: $applicant.address|get:"city",
            address_state: $applicant.address|get:"state",
            address_postal_code: $applicant.address|get:"zip",
            external_entity_id: $input.application_id|to_text,
            webhook_url: $env.APP_BASE_URL ~ "/api:loan-origination/webhooks/kyc"
          }
          headers = [
            "Content-Type: application/json",
            "Authorization: Bearer " ~ $kyc_key
          ]
          timeout = 30
        } as $kyc_result

        var $initiated { value = true }

        db.patch application {
          field_name = "id"
          field_value = $input.application_id
          data = { kyc_status: "pending", updated_at: now }
        }

        function.run "audit/write_audit_log" {
          input = {
            action: "kyc.verification_initiated",
            resource_type: "application",
            resource_id: $input.application_id,
            application_id: $input.application_id,
            metadata: { provider: $input.provider }
          }
        }
      }
      catch {
        var $initiated { value = false }

        function.run "audit/write_audit_log" {
          input = {
            action: "kyc.verification_error",
            resource_type: "application",
            resource_id: $input.application_id,
            application_id: $input.application_id,
            metadata: { provider: $input.provider, error: "KYC API call failed" }
          }
        }
      }
    }
  }
  response = { initiated: $initiated }
  guid = "CTPOuW-7kkFtJbwdxU8X93FgP-Q"
}