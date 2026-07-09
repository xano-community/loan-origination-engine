// POST /webhooks/kyc - Receive KYC verification webhook callbacks
query "webhooks/kyc" verb=POST {
  api_group = "LoanOrigination"
  description = "Webhook endpoint for Alloy/Persona KYC verification callbacks"

  input {
    text external_entity_id
    text event_type?
    text outcome
    json verification_data?
  }

  stack {
    db.add webhook_event {
      data = {
        source: "kyc",
        event_type: $input.event_type ?? "kyc_verification",
        external_reference_id: $input.external_entity_id,
        payload: { outcome: $input.outcome },
        processing_status: "received"
      }
    } as $webhook_log

    var $app_id { value = $input.external_entity_id|to_int }

    db.get application {
      field_name = "id"
      field_value = $app_id
    } as $app

    var $kyc_status { value = "pending" }
    switch ($input.outcome) {
      case ("approved") {
        var.update $kyc_status { value = "passed" }
      } break
      case ("denied") {
        var.update $kyc_status { value = "failed" }
      } break
      case ("review") {
        var.update $kyc_status { value = "review_required" }
      } break
      default {
        var.update $kyc_status { value = "pending" }
      }
    }

    conditional {
      if ($app != null) {
        db.patch application {
          field_name = "id"
          field_value = $app_id
          data = {
            kyc_result: $input.verification_data,
            kyc_status: $kyc_status,
            updated_at: now
          }
        } as $kyc_update

        function.run "audit/write_audit_log" {
          input = {
            action: "kyc.verification_completed",
            resource_type: "application",
            resource_id: $app_id,
            application_id: $app_id,
            new_state: $kyc_status
          }
        } as $audit_entry
      }
    }

    db.patch webhook_event {
      field_name = "id"
      field_value = $webhook_log.id
      data = { processing_status: "processed", processed_at: now }
    } as $wh_final
  }

  response = { received: true }
  guid = "VXKOVhzY63cc9v3VAXQXcBDUBiI"
}