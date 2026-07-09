// Issue GLBA privacy notice for the application
function "compliance/issue_glba_notice" {
  description = "Generates and records GLBA privacy notice for compliance"
  input {
    int application_id
  }
  stack {
    security.create_uuid as $glba_notice_id

    db.patch application {
      field_name = "id"
      field_value = $input.application_id
      data = { glba_privacy_notice_id: $glba_notice_id }
    }

    function.run "audit/write_audit_log" {
      input = {
        action: "glba.privacy_notice_issued",
        resource_type: "application",
        resource_id: $input.application_id,
        application_id: $input.application_id,
        metadata: { glba_notice_id: $glba_notice_id }
      }
    }
  }
  response = { glba_notice_id: $glba_notice_id }
  guid = "KJSfaUk0fU5RT8GCkVePi-MOnhQ"
}