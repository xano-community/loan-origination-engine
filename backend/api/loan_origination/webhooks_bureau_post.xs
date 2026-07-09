// POST /webhooks/bureau - Receive credit bureau webhook callbacks
query "webhooks/bureau" verb=POST {
  api_group = "LoanOrigination"
  description = "Webhook endpoint for Experian/Equifax credit bureau report callbacks"

  input {
    text reference_id
    text event_type?
    int credit_score?
    json report_data?
    text status
  }

  stack {
    db.add webhook_event {
      data = {
        source: "bureau",
        event_type: $input.event_type ?? "credit_report",
        external_reference_id: $input.reference_id,
        payload: { credit_score: $input.credit_score, status: $input.status },
        processing_status: "received"
      }
    } as $webhook_log

    var $app_id { value = $input.reference_id|to_int }

    db.get application {
      field_name = "id"
      field_value = $app_id
    } as $app

    conditional {
      if ($app != null && $input.status == "completed") {
        db.patch application {
          field_name = "id"
          field_value = $app_id
          data = {
            credit_score: $input.credit_score,
            bureau_report: $input.report_data,
            bureau_status: "received",
            updated_at: now
          }
        } as $bureau_update

        function.run "audit/write_audit_log" {
          input = {
            action: "bureau.report_received",
            resource_type: "application",
            resource_id: $app_id,
            application_id: $app_id,
            new_state: "bureau_received"
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
  guid = "OcIG-_8bUYzL77Kj_8MvyTAUSbY"
}