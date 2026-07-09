// Write an audit log entry to the Xano DB for SOC2 compliance
function "audit/write_audit_log" {
  description = "Records audit trail entry for every state transition"
  input {
    text action
    text resource_type
    int resource_id?
    int application_id?
    text previous_state?
    text new_state?
    json metadata?
    int user_id? {
      description = "Acting user id; pass $auth.id from authenticated endpoints, omit for system/webhook calls"
    }
  }
  stack {
    security.create_uuid as $correlation_id

    db.add audit_log {
      data = {
        user_id: $input.user_id,
        application_id: $input.application_id,
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
  response = $log_entry
  guid = "lLqMRdn5juxspnWTaZN5uCTYSSk"
}