// Scheduled task to expire stale applications
// Runs daily to find applications past their expiry date
task "expire_stale_applications" {
  description = "Expires loan applications that have been stale past their expiry date. Sends notifications and logs audit trail."

  stack {
    // Find applications past expiry that are still in active states
    db.query application {
      where = $db.application.expires_at < now && ($db.application.status == "draft" || $db.application.status == "submitted" || $db.application.status == "pending_bureau" || $db.application.status == "pending_kyc")
      return = { type: "list" }
    } as $stale_apps

    var $expired_count { value = 0 }

    foreach ($stale_apps) {
      each as $app {
        try_catch {
          try {
            var $prev_status { value = $app.status }

            // Update status to expired
            db.patch application {
              field_name = "id"
              field_value = $app.id
              data = {
                status: "expired",
                updated_at: now
              }
            }

            // Audit log
            function.run "audit/write_audit_log" {
              input = {
                action: "application.expired",
                resource_type: "application",
                resource_id: $app.id,
                application_id: $app.id,
                previous_state: $prev_status,
                new_state: "expired",
                metadata: { expired_at: now, reason: "stale_application_expiry" }
              }
            }

            // Notify applicant
            function.run "notifications/send_notification" {
              input = {
                application_id: $app.id,
                template_id: "application_expiring",
                channel: "email"
              }
            }

            math.add $expired_count { value = 1 }
          }
          catch {
            debug.log { value = "Failed to expire application #" ~ ($app.id|to_text) }
          }
        }
      }
    }

    debug.log { value = "Expired " ~ ($expired_count|to_text) ~ " stale applications" }
  }

  schedule = [{starts_on: 2026-01-01 02:00:00+0000, freq: 86400}]
  guid = "PPl99SqwTXIxM7dn_be9xCa_KQo"
}