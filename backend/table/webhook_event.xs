table webhook_event {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    text source {
      description = "Webhook source: experian, equifax, alloy, persona"
    }
    text event_type {
      description = "Event type from the provider"
    }
    int application_id? {
      table = "application"
    }
    text external_reference_id? {
      description = "External provider reference ID"
    }
    json payload {
      description = "Raw webhook payload"
    }
    json headers? {
      description = "Incoming request headers for signature verification"
    }
    enum processing_status?="received" {
      values = ["received", "processing", "processed", "failed", "ignored"]
    }
    text error_message?
    bool signature_valid?
    timestamp processed_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "source"}]}
    {type: "btree", field: [{name: "application_id"}]}
    {type: "btree", field: [{name: "external_reference_id"}]}
    {type: "btree", field: [{name: "processing_status"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]
  guid = "4QxeX66G5KvjP2iB5q1XbhXpPL4"
}