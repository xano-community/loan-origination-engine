// Middleware to write audit log entries for every state transition
// Runs as post-middleware to capture the result of operations
middleware "audit_trail" {
  description = "Writes audit log entry to the Xano DB for SOC2 compliance"
  exception_policy = "silent"

  input {
    text action {
      description = "Action identifier e.g. application.created"
    }
    text resource_type {
      description = "Resource type: application, applicant, decision"
    }
    int resource_id?
    text previous_state?
    text new_state?
    json metadata?
  }

  stack {
    security.create_uuid as $correlation_id

    db.add audit_log {
      data = {
        user_id: $auth.id,
        action: $input.action,
        resource_type: $input.resource_type,
        resource_id: $input.resource_id,
        previous_state: $input.previous_state,
        new_state: $input.new_state,
        metadata: $input.metadata,
        ip_address: $env.$remote_ip,
        correlation_id: $correlation_id
      }
    } as $log_entry
  }

  response = null
  guid = "D1-TgVxEJShPA518BX2IpwT9bcU"
}