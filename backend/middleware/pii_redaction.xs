// Middleware to redact PII from API responses
// Strips sensitive fields before data leaves the system
middleware "pii_redaction" {
  description = "Redacts PII fields from response data for GLBA/SOC2 compliance"
  exception_policy = "silent"
  response_strategy = "replace"

  input {
    json original_response
  }

  stack {
    var $redacted { value = $input.original_response }

    // Redact SSN - replace with masked version
    conditional {
      if ($redacted|has:"ssn") {
        var.update $redacted { value = $redacted|set:"ssn":"***-**-****" }
      }
    }

    // Redact date of birth
    conditional {
      if ($redacted|has:"date_of_birth") {
        var.update $redacted { value = $redacted|set:"date_of_birth":"****-**-**" }
      }
    }

    // Redact phone if present
    conditional {
      if ($redacted|has:"phone") {
        var $phone_val { value = $redacted|get:"phone" }
        conditional {
          if ($phone_val != null) {
            var $masked_phone { value = "***-***-" ~ ($phone_val|substr:-4:4) }
            var.update $redacted { value = $redacted|set:"phone":$masked_phone }
          }
        }
      }
    }

    // Redact SSN hash
    conditional {
      if ($redacted|has:"ssn_hash") {
        var.update $redacted { value = $redacted|set:"ssn_hash":"[REDACTED]" }
      }
    }

    // Redact nested applicant data if present
    conditional {
      if ($redacted|has:"applicant") {
        var $app_data { value = $redacted|get:"applicant" }
        conditional {
          if ($app_data|has:"ssn") {
            var.update $app_data { value = $app_data|set:"ssn":"***-**-****" }
          }
        }
        conditional {
          if ($app_data|has:"date_of_birth") {
            var.update $app_data { value = $app_data|set:"date_of_birth":"****-**-**" }
          }
        }
        conditional {
          if ($app_data|has:"ssn_hash") {
            var.update $app_data { value = $app_data|set:"ssn_hash":"[REDACTED]" }
          }
        }
        var.update $redacted { value = $redacted|set:"applicant":$app_data }
      }
    }
  }

  response = $redacted
  guid = "WaV8cvt2ZnVXoVYCWByNqs-ttcs"
}