# GrantTrail — Temporary Test Checklist

> **Temporary working doc.** Tracks manual + automated verification of the core
> paid flows ahead of the prod cutover. Delete once these are folded into the
> permanent test suite / CI.
>
> **Source of truth** for expected behavior:
> - `docs/tutorials/Grantee-Walkthrough.md`
> - `docs/tutorials/Admin-Walkthrough.md`
> - `docs/tutorials/Super-Admin-Walkthrough.md`
> - `docs/tutorials/payment-and-deployment-guide.md` (payment + email flow)

**Legend:** 🟢 agent does it end-to-end · 🟠 needs a human action · 🔴 needs a human decision

---

## Payment Confirmation Email (Resend)

- [ ] 🟢 **Email sends on successful checkout** — complete a test-mode subscription checkout; confirm `sendPaymentConfirmationEmail` fires from the `checkout.session.completed` webhook branch and a receipt arrives.
- [ ] 🟢 **Receipt contents correct** — plan name, amount, currency, payment date, next-renewal date, and subscription id all match the Stripe session/subscription.
- [ ] 🟢 **Recipient + first name resolve** — email goes to `customer_details.email`; first name is looked up via `billing_customers → users.firstname` (falls back to "there").
- [ ] 🟢 **Failure isolation** — with email forced to fail, the webhook still returns 200, the subscription is still written, and a `payment_confirmation_email_failure` row lands in `system_logs` (Stripe does not retry).
- [ ] 🟢 **Disabled-without-key** — with `RESEND_API_KEY` unset, checkout succeeds and the send is skipped (warning logged, no error).
- [ ] 🟠 **`RESEND_FROM_EMAIL` is a verified Resend domain** — current value is a Gmail address; Resend requires a verified domain as the `From` or sends will be rejected. Verify a domain or use the `GrantTrail <noreply@granttrail.ca>` default.
- [ ] 🟠 **Prod secrets present** — `RESEND_API_KEY` (secret) + `RESEND_FROM_EMAIL` (variable) set in the GitHub `production` environment and forwarded by `deploy-prod.yml` to Supabase. *(set; pending PR #54 merge for the workflow wiring.)*

## Paywall

- [ ] 🟢 **Unsubscribed user is gated** — a grantee/admin without an active subscription cannot reach the paid surfaces; they see the paywall / upgrade prompt.
- [ ] 🟢 **Subscribed user has access** — after a successful checkout + webhook upsert, the same user’s `user_memberships` reflects the tier and the paywall lifts.
- [ ] 🟢 **Tier mapping correct** — Basic vs Premium (Fiscal Agents) entitlements resolve per `upsertSubscriptionFromStripe` and match the walkthroughs’ role/permission matrix.
- [ ] 🟢 **Lapse re-gates** — on `customer.subscription.deleted`/past-due, access is revoked and the paywall returns.
- [ ] 🟢 **Server-side enforcement (not just UI)** — paywalled data is protected by RLS, not only hidden in the frontend; a direct query without entitlement is denied.
- [ ] 🟢 **Local seed bypass is local-only** — confirm the seed-data paywall bypass does not leak into staging/prod.

## Cross-cutting

- [ ] 🟢 **Webhook idempotency** — replaying the same Stripe event is deduped via `billing_webhook_events` (no double email, no double membership write).
- [ ] 🟠 **Human smoke test** — one full real test-mode purchase end-to-end: checkout → receipt email → paywall lifts.
