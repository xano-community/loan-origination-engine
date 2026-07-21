# Loan Origination Decision Engine

A **self-contained Xano template** for a consumer-loan origination backend: an applicant applies, the engine scores them and runs a configurable **risk-tier waterfall**, and produces an auditable **approve / conditionally-approve / refer / deny** decision with ECOA adverse-action tracking.

It is **self-contained** — the whole `submit → decision → status` flow runs end-to-end on the seed data this repo ships, with **no third-party credentials**. Real credit-bureau, KYC, cash-flow, and notification providers are supported as **optional enrichment** (see [Going live](#going-live-optional-real-integrations)).

---

## Why this exists

Consumer lending has two hard parts a demo usually skips: making a *consistent* credit decision, and being able to *defend* it afterward. Hand-coded approval logic drifts between loan officers, and when a regulator asks why an applicant was denied, "the system said no" isn't an answer — ECOA requires a specific adverse-action reason on the record.

This template is a working decision engine that does both. A deterministic score feeds a configurable risk-tier waterfall to produce an approve / conditionally-approve / refer / deny outcome, every state change is written to an audit log, and every denial carries an ECOA adverse-action id and timestamp. It runs end-to-end on the seed data this repo ships with no credentials, so you can trace the whole decision path before wiring in a real credit bureau — bureau, KYC, and cash-flow providers are optional enrichment, not prerequisites.

## What you get

| Layer | Contents |
|---|---|
| **Data** | Xano-internal tables: `user`, `applicant`, `application`, `risk_tier`, `decision`, `audit_log`, `notification_log`, `webhook_event` |
| **Auth** | JWT signup / login / me on the internal `user` table, roles `broker · underwriter · applicant` |
| **Decision engine** | Deterministic credit scoring + configurable risk-tier evaluation → decision record |
| **Compliance** | Audit log on every state change; ECOA adverse-action id + timestamp on every denial; PII redaction on read |
| **Demo** | One-call `/seed`, a no-auth `/demo/run` scenario runner, and a single-file frontend |

### Decision outcomes

The engine returns one of four outcomes, driven entirely by the seeded `risk_tier` rows:

- **approved** — matched an auto-decision tier with passing KYC
- **conditionally_approved** — matched a tier that isn't auto-decision-eligible
- **referred** — matched a tier but KYC needs manual review
- **denied** — no tier matched (credit/DTI/loan-amount out of range); an ECOA adverse-action id is recorded

---

## Quickstart (credential-free)

1. **Create a Xano workspace** and push this repo's `backend/` into it (Xano CLI):
   ```bash
   xano workspace push -w <your-workspace-id> -d backend --force
   ```
2. **Seed** the demo risk tiers + users (idempotent):
   ```bash
   curl -X POST "https://<your-instance>.xano.io/api:loan-origination/seed"
   ```
   This creates three tiers (Prime / Near-Prime / Subprime) and three demo users.
3. **Open the frontend** — `frontend/index.html` in a browser. Enter your instance base URL + the two API-group canonicals, click **Seed demo data**, then try the decision engine.

Demo logins (password `Demo1234`): `broker@demo.test`, `underwriter@demo.test`, `applicant@demo.test`.

### The core flow (curl)

```bash
BASE=https://<your-instance>.xano.io
LOAN=$BASE/api:loan-origination
AUTH=$BASE/api:<your-auth-group-canonical>

# log in as the seeded broker
TOKEN=$(curl -s -X POST "$AUTH/auth/login" -H "Content-Type: application/json" \
  -d '{"email":"broker@demo.test","password":"Demo1234"}' | jq -r .authToken)

# create a draft application (creates/links the applicant)
APP=$(curl -s -X POST "$LOAN/applications" -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"first_name":"Ada","last_name":"Prime","email":"ada@demo.test",
       "loan_type":"personal","loan_amount":25000,"loan_term_months":36,
       "annual_income":150000,"monthly_debt":800}')
ID=$(echo "$APP" | jq .id)

# submit → runs scoring + decisioning synchronously
curl -s -X POST "$LOAN/applications/$ID/submit" -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" -d '{}'

# read status (application + decision + PII-masked applicant)
curl -s "$LOAN/applications/$ID/status" -H "Authorization: Bearer $TOKEN"
```

`POST /applications/{id}/submit` also accepts optional `credit_score` and `kyc_status` overrides to force a specific scenario for demos/tests.

---

## How decisioning works

1. **Scoring** (`function/decisioning/derive_internal_signals`) — a deterministic, credential-free credit score (300–850) derived from the applicant's income, debt-to-income, and loan-to-income. **This is a demo heuristic, not a real credit bureau.** It's a pure function, so it's fully unit-tested.
2. **Waterfall** (`function/decisioning/run_decisioning`) — evaluates the applicant's score, DTI, loan amount, and KYC status against active `risk_tier` rows in `priority` order, picks the first eligible tier, and maps it to an outcome. Denials record ECOA adverse-action reasons.

Because tiers live in the `risk_tier` table (not in code), you tune thresholds, rates, and auto-decision eligibility by editing data — no redeploy.

---

## Going live (optional real integrations)

The credential-free scorer is the **default**. To use real providers, set the relevant workspace env vars and feed results in through the webhook endpoints (which overwrite the derived score/KYC before decisioning):

| Provider | Function | Env vars | Entry point |
|---|---|---|---|
| Experian / Equifax | `function/external/call_credit_bureau` | `EXPERIAN_API_URL/KEY`, `EQUIFAX_API_URL/KEY` | `POST /webhooks/bureau` |
| Alloy / Persona (KYC) | `function/external/call_kyc` | `ALLOY_API_URL/KEY/SECRET`, `PERSONA_API_URL/KEY` | `POST /webhooks/kyc` |
| Plaid (cash flow) | `function/external/call_plaid` | `PLAID_BASE_URL`, `PLAID_CLIENT_ID`, `PLAID_SECRET` | `submit` with `plaid_access_token` |
| Twilio / SendGrid | `function/notifications/send_notification` | `TWILIO_*`, `SENDGRID_*` | called on decision |

All external calls are wrapped in `try_catch`, so missing credentials never break the flow — they simply leave that enrichment unpopulated.

---

## Testing

- **Unit tests** (embedded in `derive_internal_signals`) — verify the scoring bands. `xano unit_test run_all -w <id>`
- **Workflow tests** (`backend/workflow_test/`) — drive the full decisioning path end-to-end for each outcome. `xano workflow_test run_all -w <id>`
- All `.xs` validate against the XanoScript language server.

The four decision outcomes were also verified against a live deployment through the real API endpoints (`create → submit → status`, plus the no-auth `/demo/run`).

---

## Notes & limitations

- This is a **proof-of-concept template**. The credit score is a heuristic; SSNs are stored as provided (encrypt at rest before any production use); the three `role_guard` / `audit_trail` / `pii_redaction` middlewares are shipped as reusable helpers but are not auto-attached.
- The scheduled `expire_stale_applications` task expires draft applications past their 30-day `expires_at`.
