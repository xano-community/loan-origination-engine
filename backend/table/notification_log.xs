table notification_log {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    int user_id? {
      table = "user"
    }
    int application_id? {
      table = "application"
    }
    enum channel {
      values = ["sms", "email", "push"]
    }
    enum provider {
      values = ["twilio", "sendgrid"]
    }
    text recipient {
      description = "Email address or phone number"
      sensitive = true
    }
    text template_id? {
      description = "Template identifier for the notification"
    }
    text subject?
    enum status?="pending" {
      values = ["pending", "sent", "delivered", "failed", "bounced"]
    }
    text provider_message_id? {
      description = "Message ID from Twilio/SendGrid"
    }
    text error_message?
    json metadata?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "user_id"}]}
    {type: "btree", field: [{name: "application_id"}]}
    {type: "btree", field: [{name: "status"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]
  guid = "ErtwezswqpA7U7VWFQbAjZ0pq9o"
}