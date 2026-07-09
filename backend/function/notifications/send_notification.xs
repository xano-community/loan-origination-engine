// Send notifications via Twilio (SMS) or SendGrid (email)
function "notifications/send_notification" {
  description = "Dispatches notifications via Twilio SMS or SendGrid email"
  input {
    int application_id
    text template_id
    text channel?="email" {
      description = "Notification channel: email or sms"
    }
  }
  stack {
    db.get application {
      field_name = "id"
      field_value = $input.application_id
    } as $app

    precondition ($app != null) {
      error_type = "notfound"
      error = "Application not found"
    }

    db.get applicant {
      field_name = "id"
      field_value = $app.applicant_id
    } as $applicant

    var $provider { value = "sendgrid" }
    var $recipient { value = $applicant.email }
    var $subject { value = "Loan Application Update" }
    var $message_body { value = "Your loan application #" ~ ($app.id|to_text) ~ " has been updated." }

    // Build message based on template
    switch ($input.template_id) {
      case ("decision_approved") {
        var.update $subject { value = "Congratulations! Your Loan Application Has Been Approved" }
        var.update $message_body { value = "Your loan application #" ~ ($app.id|to_text) ~ " has been approved." }
      } break
      case ("decision_denied") {
        var.update $subject { value = "Update on Your Loan Application" }
        var.update $message_body { value = "We have completed our review of your loan application #" ~ ($app.id|to_text) ~ ". Unfortunately, we are unable to approve your application at this time. An adverse action notice with detailed reasons will follow." }
      } break
      case ("decision_conditionally_approved") {
        var.update $subject { value = "Your Loan Application - Conditional Approval" }
        var.update $message_body { value = "Your loan application #" ~ ($app.id|to_text) ~ " has been conditionally approved. Please review the conditions." }
      } break
      case ("adverse_action_notice") {
        var.update $subject { value = "Adverse Action Notice - Loan Application #" ~ ($app.id|to_text) }
        var.update $message_body { value = "This is a formal notice pursuant to the Equal Credit Opportunity Act regarding your loan application #" ~ ($app.id|to_text) ~ "." }
      } break
      case ("application_submitted") {
        var.update $subject { value = "Loan Application Received" }
        var.update $message_body { value = "Your loan application #" ~ ($app.id|to_text) ~ " has been submitted and is being processed." }
      } break
      case ("application_expiring") {
        var.update $subject { value = "Action Required: Your Loan Application Will Expire Soon" }
        var.update $message_body { value = "Your loan application #" ~ ($app.id|to_text) ~ " will expire soon. Please take action." }
      } break
      default {
        var.update $message_body { value = "Your loan application #" ~ ($app.id|to_text) ~ " status: " ~ $app.status }
      }
    }

    var $send_result { value = null }

    conditional {
      if ($input.channel == "sms" && $applicant.phone != null) {
        var.update $provider { value = "twilio" }
        var.update $recipient { value = $applicant.phone }

        try_catch {
          try {
            api.request {
              url = "https://api.twilio.com/2010-04-01/Accounts/" ~ $env.TWILIO_ACCOUNT_SID ~ "/Messages.json"
              method = "POST"
              params = {
                To: $applicant.phone,
                From: $env.TWILIO_PHONE_NUMBER,
                Body: $message_body
              }
              headers = [
                "Authorization: Basic " ~ (($env.TWILIO_ACCOUNT_SID ~ ":" ~ $env.TWILIO_AUTH_TOKEN)|base64_encode)
              ]
              timeout = 15
            } as $twilio_result

            var.update $send_result { value = $twilio_result.response.result }
          }
          catch {
            var.update $send_result { value = { error: "Twilio send failed" } }
          }
        }
      }
      else {
        // Send email via SendGrid
        try_catch {
          try {
            api.request {
              url = "https://api.sendgrid.com/v3/mail/send"
              method = "POST"
              params = {
                personalizations: [{ to: [{ email: $applicant.email }] }],
                from: { email: $env.SENDGRID_FROM_EMAIL, name: "Loan Services" },
                subject: $subject,
                content: [{ type: "text/plain", value: $message_body }]
              }
              headers = [
                "Content-Type: application/json",
                "Authorization: Bearer " ~ $env.SENDGRID_API_KEY
              ]
              timeout = 15
            } as $sg_result

            var.update $send_result { value = { status: "sent" } }
          }
          catch {
            var.update $send_result { value = { error: "SendGrid send failed" } }
          }
        }
      }
    }

    // Log notification
    var $notif_status { value = "sent" }
    var $error_msg { value = null }
    conditional {
      if ($send_result|has:"error") {
        var.update $notif_status { value = "failed" }
        var.update $error_msg { value = $send_result|get:"error" }
      }
    }

    db.add notification_log {
      data = {
        user_id: $app.broker_id,
        application_id: $input.application_id,
        channel: $input.channel,
        provider: $provider,
        recipient: $recipient,
        template_id: $input.template_id,
        subject: $subject,
        status: $notif_status,
        provider_message_id: $send_result|get:"sid":"",
        error_message: $error_msg
      }
    } as $notif_log
  }
  response = $notif_log
  guid = "KgOa49qik6y7LNNI4zDkjOkvlqU"
}