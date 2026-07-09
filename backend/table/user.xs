table user {
  auth = true

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }

    text name filters=trim
    email? email filters=trim|lower
    password? password filters=min:8|minAlpha:1|minDigit:1 {
      visibility = "internal"
    }
    enum role?="applicant" {
      values = ["broker", "underwriter", "applicant"]
    }
    bool is_active?=true
    timestamp updated_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "btree|unique", field: [{name: "email", op: "asc"}]}
    {type: "btree", field: [{name: "role"}]}
  ]

  guid = "tNqKWPuTmV9e1htoqdhA9JxE_UA"
}