// Check the Xano DB for a duplicate applicant by SSN hash or email
function "validation/check_duplicate_applicant" {
  description = "Detects duplicate applicants by SSN hash or email"
  input {
    text ssn_hash?
    email email? filters=trim|lower
    int exclude_id? {
      description = "Applicant ID to exclude (for updates)"
    }
  }
  stack {
    var $is_duplicate { value = false }
    var $duplicate_applicant_id { value = null }

    // Check by SSN hash first (strongest match)
    conditional {
      if ($input.ssn_hash != null) {
        db.query applicant {
          where = $db.applicant.ssn_hash == $input.ssn_hash && $db.applicant.id !=? $input.exclude_id
          return = { type: "single" }
        } as $ssn_match

        conditional {
          if ($ssn_match != null) {
            var.update $is_duplicate { value = true }
            var.update $duplicate_applicant_id { value = $ssn_match.id }
          }
        }
      }
    }

    // Check by email if no SSN match
    conditional {
      if ($is_duplicate == false && $input.email != null) {
        db.query applicant {
          where = $db.applicant.email == $input.email && $db.applicant.id !=? $input.exclude_id
          return = { type: "single" }
        } as $email_match

        conditional {
          if ($email_match != null) {
            var.update $is_duplicate { value = true }
            var.update $duplicate_applicant_id { value = $email_match.id }
          }
        }
      }
    }
  }
  response = { is_duplicate: $is_duplicate, existing_applicant_id: $duplicate_applicant_id }
  guid = "GbaRLUCN2ziR5P2aTEJb39VxYg4"
}