// Check if authenticated user has one of the required roles
function "auth/check_role" {
  description = "Validates that the current user has an allowed role"
  input {
    text[] allowed_roles
  }
  stack {
    precondition ($auth.id != null) {
      error_type = "accessdenied"
      error = "Authentication required"
    }

    db.get user {
      field_name = "id"
      field_value = $auth.id
    } as $user

    precondition ($user != null) {
      error_type = "accessdenied"
      error = "User not found"
    }

    var $role_matches { value = $input.allowed_roles|intersect:[$user.role] }
    precondition (($role_matches|count) > 0) {
      error_type = "accessdenied"
      error = "Insufficient permissions"
    }
  }
  response = $user
  guid = "rqjKym0UeeXpwRjs2wv-ibOSwPI"
}