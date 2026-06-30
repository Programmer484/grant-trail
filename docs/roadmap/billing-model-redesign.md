# Billing model redesign — optional future direction

> **Status:** not planned. Design direction only — no implementation scheduled.
> Grounded in: `supabase/migrations/20260616000000_initial_schema.sql`,
> `frontend/src/lib/{billing,policy}.js`, `stripe-webhook`, `_shared/stripe.ts`.

---

## Root mismatch

Membership is billed **per user** (`user_memberships.user_id`) but the business
operates **per tenant** (a fiscal agent's org). The "Fiscal Agents Plan" is sold
as multi-org/multi-user but billed per seat, and the only org-level lever today
is the all-or-nothing exemption flag (`tenant_settings.require_subscription =
false`, checked in `is_membership_exempt`), which frees **every** grantee and
co-admin in the tenant. Fix the billing unit and the exemption flag stops being
load-bearing.

---

## Target design — three user types, two SKUs

| Type | Who | Billing | What they get |
|---|---|---|---|
| **Seeker** | Charity hunting for a sponsor | Free (account only) | Browse + contact fiscal agents; spam-filtered by account gating, not paywall |
| **Self-service grantee** | Solo grantee, no sponsor | Basic subscription (recurring) | Grant tracking app |
| **Fiscal agent** | Sponsor org | Premium subscription (recurring) | Charity directory listing + all grantees/co-admins in the tenant covered |

**Basic = self-service grant tracking only.** It decouples entirely from the
directory. A seeker never needs to pay basic — they just need a free account.

**Seeking is free.** The fiscal agent side carries all revenue. This is the
standard two-sided marketplace move: subsidize the demand side (seekers) so the
supply side (agents) has a pool worth paying to access. Free seekers → more
seekers → agents have a reason to pay.

**Spam guard** on directory contact is account-gating (must be logged in), not a
paywall. Optionally a small one-time verification fee if spam becomes a real
problem — not a revenue line, just friction reduction.

---

## How the mismatch gets fixed (Phase A)

**Move the paid entitlement from the person to the org.**

- New tenant-level subscription record (e.g. `tenant_subscriptions`): one active
  plan per tenant.
- `has_premium_membership(user)` reads tenant coverage first — if the user's org
  has an active plan, every member is covered. No seat cap, no individual
  assignment.
- `user_memberships` stays only for self-service grantees paying basic on their
  own. Org members under a premium tenant don't need a personal row.
- `tenant_settings.require_subscription = false` becomes a rare manual override
  ("we cut this org a deal"), not the normal coverage path.

Everything above the entitlement functions — `policy.js` (`canOwnListing`,
`canViewDirectory`, `canMutate`, read-only lapse) — stays conceptually unchanged.
It's a source-swap behind existing flags, not a logic rewrite.

**`canViewDirectory` decouples from `has_basic_membership`.** Free authenticated
users (seekers) pass it. Basic only gates self-service grant tracking.

---

## The seeker → onboarded transition (upgrade path, do later)

Today: seeker cancels their basic sub (if any), agent invites them fresh.
Manual, fine at low volume.

Future (#2): accept agent invite → absorbed into agent's managed tenant →
personal basic sub auto-cancels. Requires users changing tenants, which isn't
supported today. Build only when the self-service → managed upgrade flow has
clear demand.

---

## What this is NOT doing

- **No individually-assigned seats.** Flat per-tenant coverage; every org member
  is covered while the org's plan is active.
- **No seat cap** on day one. Add only when pricing-by-headcount is an explicit
  product requirement.
- **No one-time "finder's pass"** for seekers. Free account is simpler and avoids
  expiry/cancel mechanics.
- **Not monetizing the seeker side** (beyond optional spam-filter fee). Revenue
  lives on the agent side.

---

## Checklist (if/when this gets scheduled)

### Phase A — tenant-level billing (do first)

- [ ] 🔴 Confirm pricing model doesn't require per-seat billing (validates the no-cap choice)
- [ ] 🟢 Schema: `tenant_subscriptions` table; re-point `has_basic/premium_membership` to read tenant coverage first
- [ ] 🟢 Replace exemption sledgehammer: tenant plan covers grantees/co-admins; keep `require_subscription = false` as manual-override only
- [ ] 🟢 Checkout/webhook: `provisionFiscalAgentFromCheckout` + `upsertSubscriptionFromStripe` write to tenant, not user. Preserve idempotency, partial-failure behavior, duplicate-event guard
- [ ] 🟢 Policy: `canViewDirectory` decouples from `has_basic_membership` (free authenticated users pass); `canOwnListing` reads tenant entitlement; confirm `get_session_context` still returns keys `policy.js` expects
- [ ] 🟢 Tests/seed: update fixtures to tenant-level shape; keep `charity-directory-rls.test.sh` green

### Phase B — two-sided directory: seeker listings (do after A)

- [ ] 🔴 Confirm seeker-discovery is in scope
- [ ] 🟢 Schema + RLS: seeker "seeking sponsorship" listing type with its own ownership/visibility policies
- [ ] 🟢 Frontend: seeker creates/edits profile; agents browse + inquire the other direction
- [ ] 🟢 Signup flow: intent prompt ("looking for a sponsor" vs "manage grants") routes seeker vs self-service correctly
- [ ] 🟢 Upgrade path (#2): accept agent invite → migrate to managed tenant → cancel personal basic sub (low priority, do when demand is clear)
