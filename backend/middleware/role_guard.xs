// Middleware to enforce role-based access control
// Checks that the authenticated user has one of the allowed roles
middleware "role_guard" {
  description = "Enforces role-based access control. Denies access if user role is not in allowed_roles."
  exception_policy = "rethrow"

  input {
    text[] allowed_roles {
      description = "List of roles permitted to access the endpoint"
    }
  }

  stack {
    precondition ($auth.id != null) {
      error_type = "accessdenied"
      error = "Authentication required"
    }

    db.get user {
      field_name = "id"
      field_value = $auth.id
    } as $current_user

    precondition ($current_user != null) {
      error_type = "accessdenied"
      error = "User not found"
    }

    precondition ($input.allowed_roles|contains:$current_user.role) {
      error_type = "accessdenied"
      error = "Insufficient permissions. Required role: " ~ ($input.allowed_roles|join:", ")
    }
  }

  response = { user_role: $current_user.role }
  guid = "PnhzMn1xPUbTmUcrrz-ojukGBl0"
}