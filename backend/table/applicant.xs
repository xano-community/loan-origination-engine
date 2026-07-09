table applicant {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    timestamp updated_at?

    text first_name filters=trim
    text last_name filters=trim
    email email filters=trim|lower {
      sensitive = true
    }
    text phone? filters=trim {
      sensitive = true
    }
    text ssn? {
      description = "Social Security Number - PoC stores as provided; encrypt at rest before production use"
      sensitive = true
    }
    date date_of_birth? {
      sensitive = true
    }
    json address? {
      description = "Structured address: street, city, state, zip"
    }
    text ssn_hash? {
      description = "Reserved for SSN-hash dedup; the shipped flow dedups applicants by email"
    }
    int user_id? {
      table = "user"
      description = "Linked user account if applicant has login"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "btree|unique", field: [{name: "email"}]}
    {type: "btree", field: [{name: "ssn_hash"}]}
    {type: "btree", field: [{name: "user_id"}]}
  ]
  guid = "nl1rZT5LccTJ9sQOWqeSSNAlvm8"
}