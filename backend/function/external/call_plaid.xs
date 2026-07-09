// Call Plaid API for cash flow verification
function "external/call_plaid" {
  description = "Calls Plaid API to verify applicant cash flow data"
  input {
    int application_id
    text access_token {
      description = "Plaid access token for the applicant's bank"
      sensitive = true
    }
  }
  stack {
    try_catch {
      try {
        api.request {
          url = $env.PLAID_BASE_URL ~ "/transactions/get"
          method = "POST"
          params = {
            client_id: $env.PLAID_CLIENT_ID,
            secret: $env.PLAID_SECRET,
            access_token: $input.access_token,
            start_date: now|transform_timestamp:"-90 days"|format_timestamp:"Y-m-d":"UTC",
            end_date: now|format_timestamp:"Y-m-d":"UTC"
          }
          headers = ["Content-Type: application/json"]
          timeout = 30
        } as $plaid_result

        precondition ($plaid_result.response.status >= 200 && $plaid_result.response.status < 300) {
          error_type = "standard"
          error = "Plaid API error: " ~ ($plaid_result.response.status|to_text)
        }

        var $cash_flow_data {
          value = {
            total_inflows: 0,
            total_outflows: 0,
            net_cash_flow: 0,
            transaction_count: $plaid_result.response.result.transactions|count,
            accounts: $plaid_result.response.result.accounts,
            retrieved_at: now
          }
        }

        // Update application with Plaid data
        db.patch application {
          field_name = "id"
          field_value = $input.application_id
          data = { plaid_cash_flow: $cash_flow_data }
        }

        // Audit log
        function.run "audit/write_audit_log" {
          input = {
            action: "plaid.cash_flow_retrieved",
            resource_type: "application",
            resource_id: $input.application_id,
            application_id: $input.application_id,
            new_state: "cash_flow_received"
          }
        }
      }
      catch {
        function.run "audit/write_audit_log" {
          input = {
            action: "plaid.cash_flow_error",
            resource_type: "application",
            resource_id: $input.application_id,
            application_id: $input.application_id,
            metadata: { error: "Plaid API call failed" }
          }
        }

        var $cash_flow_data {
          value = { error: "Plaid API call failed", retrieved_at: now }
        }
      }
    }
  }
  response = $cash_flow_data
  guid = "R2qZnLdpCsbZS95YXClEK8WlJSI"
}