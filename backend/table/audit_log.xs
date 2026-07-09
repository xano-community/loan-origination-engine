table audit_log {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int user_id? {
      table = "user"
      description = "User who triggered the action"
    }
    int application_id? {
      table = "application"
    }
    text action {
      description = "Action performed: e.g. application.created, status.changed, decision.made"
    }
    text resource_type {
      description = "Resource type: application, applicant, decision"
    }
    int resource_id? {
      description = "ID of the affected resource"
    }
    text previous_state? {
      description = "Previous state/value before change"
    }
    text new_state? {
      description = "New state/value after change"
    }
    json metadata? {
      description = "Additional context for the audit entry"
    }
    text ip_address?
    text user_agent?

    // SOC2 compliance fields
    text session_id? {
      description = "Session identifier for SOC2 traceability"
    }
    text correlation_id? {
      description = "Request correlation ID for distributed tracing"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "user_id"}]}
    {type: "btree", field: [{name: "application_id"}]}
    {type: "btree", field: [{name: "action"}]}
    {type: "btree", field: [{name: "resource_type"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "btree", field: [{name: "correlation_id"}]}
  ]
  guid = "CjuN8c9QXyLbhZD82xUYBum4Z8s"
}