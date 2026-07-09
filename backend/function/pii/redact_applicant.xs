// Redact PII from applicant data before returning to client
function "pii/redact_applicant" {
  description = "Strips or masks PII fields from applicant records"
  input {
    json applicant_data
    bool full_redaction?=false {
      description = "If true, redacts all PII. If false, partial masking."
    }
  }
  stack {
    var $redacted { value = $input.applicant_data }

    conditional {
      if ($redacted|has:"ssn") {
        var.update $redacted { value = $redacted|set:"ssn":"***-**-****" }
      }
    }
    conditional {
      if ($redacted|has:"ssn_hash") {
        var.update $redacted { value = $redacted|set:"ssn_hash":"[REDACTED]" }
      }
    }
    conditional {
      if ($redacted|has:"date_of_birth") {
        conditional {
          if ($input.full_redaction == true) {
            var.update $redacted { value = $redacted|set:"date_of_birth":"****-**-**" }
          }
        }
      }
    }
    conditional {
      if ($redacted|has:"phone" && $input.full_redaction == true) {
        var $ph { value = $redacted|get:"phone" }
        conditional {
          if ($ph != null) {
            var.update $redacted { value = $redacted|set:"phone":"***-***-" ~ ($ph|substr:-4:4) }
          }
        }
      }
    }
  }
  response = $redacted
  guid = "ftCk-uhdR_1Ky961qVxo2YLcGYU"
}