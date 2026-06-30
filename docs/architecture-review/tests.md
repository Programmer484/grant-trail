# Test Suite Review — Real Safety Net or AI Confirming AI?

Scope: read-only assessment of whether GrantTrail's tests catch real regressions
in the load-bearing logic (RLS, billing gating, role redirects, read-only-on-lapse,
webhook projection) — or merely re-assert what the code already says.

## Verdict / Score

**Professional safety-net score: 4 / 5.**

This is materially better than the "AI tests confirming AI code" failure mode the
brief anticipated. The security- and money-critical paths are protected by *real
integration tests* that exercise the actual boundary, not mocks:

- **RLS** is proven against an authenticated attacker by driving live Postgres
  with PostgREST-equivalent role/claims simulation
  (`supabase/tests/rls-adversarial.test.sh`) — positive AND negative assertions,
  including forged `tenant_id`, self-escalation, tenant-hop, storage path scoping,
  invite token enumeration, and super_admin read-only ops.
- **Stripe → DB projection** is proven by driving *real* Stripe events through a
  live `stripe listen` forwarder and asserting DB end-state
  (`supabase/functions/tests/webhook-matrix.test.sh`) — idempotency,
  lapse→reactivate, waiver orthogonality, and `past_due` via Stripe test clocks.
- **Edge-function identity** is proven by spoofing another user's id in the request
  body and asserting the token's identity wins
  (`supabase/functions/tests/authz-identity.test.sh`).
- **Route/billing policy** (`lib/policy.js`, `lib/guards.js`, `lib/useWriteGuard.js`)
  is covered by pure-function matrix tests that are genuinely mutation-resistant.
- **Tenant isolation through the real UI** is covered by Playwright e2e
  (`tests/e2e/authz-negative.spec.js`) seeding two tenants and asserting one
  admin cannot see/open the other's grant.

Points deducted (1 full point) for: one pure tautology file shipped in the suite,
a cluster of ~8 redundant low-value "Sentry wiring" tests, **zero** unit coverage
of the client-side billing security logic in `lib/billing.js`, and the structural
fact that the strongest tests (shell + e2e) need a manually-stood-up local
Supabase + Stripe and are **not** part of the default `vitest` run — so day-to-day
CI safety relies on the weaker tier.

`npx vitest run`: 17 files, 79 tests passing (the shell/e2e tiers were not
executed here as they need a live local stack).

---

## What's genuinely strong (don't touch)

- `frontend/src/lib/policy.test.js` — tests pure decisions
  (`hasRequiredSubscription`, `needsSubscription`, `canMutate`, `isReadOnlyAdmin`,
  `canViewDirectory`, `canOwnListing`) across the full role × billing matrix.
  These assert behavior, not implementation, and would fail on a flipped boolean
  or a cross-granting bug (e.g. it explicitly checks `premium` alone does NOT
  unlock directory browsing, `policy.test.js:110`).
- `frontend/src/lib/guards.test.js` — full redirect matrix
  (role × route × billing-state → destination). Catches role/billing axis
  collapse and the #40 read-only change.
- `frontend/src/lib/useWriteGuard.test.js` — verifies a lapsed admin write is
  blocked AND navigates to `/subscription`, paid admin passes, non-admin passes.
- `supabase/tests/rls-adversarial.test.sh`, `webhook-matrix.test.sh`,
  `authz-identity.test.sh`, `checkout-sessions.test.sh`,
  `tests/e2e/authz-negative.spec.js` — real boundary tests, with sanity
  (positive-control) assertions alongside the attack assertions so a blanket
  "deny everything" RLS bug would also be caught.

---

## Ranked gaps (most dangerous first)

### 1. `lib/billing.js` has NO unit test — and it carries client-side security logic
`frontend/src/lib/` contains tests only for `policy`, `guards`, `useWriteGuard`.
There is no `billing.test.js`. Untested logic includes:
- `getRequiredAccessToken` (`billing.js:74-98`): decodes the JWT, compares its
  `ref` claim to the expected Supabase project ref, and **signs the user out** on
  mismatch. A regression here (wrong comparison, swallowed mismatch) is a
  cross-project auth leak with zero test coverage.
- `decodeJwtPayload` / `getExpectedProjectRef` (`billing.js:50-72`) — base64url
  padding and host parsing, classic off-by-one/edge-case territory, untested.
- `invokeFirstAvailable` fallback ordering (`billing.js:136-154`) — the
  candidate-function fallback that the whole checkout flow depends on.
- `hasFeature` / `isOrgAdminSubscriptionRequired` (`billing.js:321-336`) — gating
  helpers consumed by components, untested at the unit level.
**Why weak:** these run in the browser before any edge function or RLS sees the
request; the server tests cannot catch a client-side ref-check regression.

### 2. `frontend/src/App.test.js` is a pure tautology
```js
test('App component mounting is tested via E2E Playwright tests', () => {
  expect(true).toBe(true);
});
```
`App.test.js:1-3`. It can never fail. It exists to make the file count look
covered. Either delete it or replace it with a real mount/route-table assertion
(the App route declarations — which roles/billingModes each route uses — are
load-bearing and currently only checked indirectly via `guards.test.js` mirrors,
not against `App.js` itself).

### 3. ~8 near-identical "Sentry wiring" tests are low-value and fully mocked
`*.sentry.test.js` across `App`, `useGrantee`, and `components/grant/*`,
`components/admin/AdminGrantReview` all follow one template: mock Supabase to
force an error, assert `captureException` was called with it and `console.error`
fired (e.g. `AddExpenseModal.sentry.test.js:33-34`,
`CreateGrant.sentry.test.js:36-37`, `useGrantee.sentry.test.js:29-30`).
**Why weak:** Supabase is mocked end-to-end, so they prove nothing about the
query, the data shape, or whether the mutation was even correct — only that the
catch block calls Sentry. They re-assert a hardcoded string the component itself
contains (`'Error saving grant:'`), so they break on a harmless log-message
reword but would *not* catch a logic bug in the same handler. Acceptable as
error-reporting smoke checks, but they inflate the apparent coverage of the grant
mutation paths, which have **no behavioral test of the success path** at the unit
level (only e2e covers happy-path writes).

### 4. The real safety net (shell + e2e) is not in the default test command
`webhook-matrix`, `rls-adversarial`, `authz-identity`, `checkout-sessions`,
`portal-and-sync`, `email-resilience`, and all Playwright specs require a manually
started local Supabase stack and (for billing) live Stripe test keys +
`stripe listen` (`run-all.sh` header; `playwright.config.js` webServer). They are
the strongest tests in the repo but are **opt-in**. A regression merged without
running them lands. The continuous tier (`vitest`, 79 tests) does not touch RLS,
the webhook, or any edge function.
**Why weak:** a safety net that only catches you when you remember to deploy it.

### 5. No negative test for webhook signature rejection at the integration tier
`stripe-webhook/index.ts:13-20` rejects requests with a missing/invalid
`stripe-signature`. `webhook-matrix.test.sh` only sends *validly signed* events
(via the forwarder). There is no assertion that a forged/unsigned event is
rejected with the right status. `email-resilience.test.sh` POSTs hand-signed
events, so the harness exists — a bad-signature case should be added there.

### 6. Edge-function business logic is only covered end-to-end, never in isolation
`upsertSubscriptionFromStripe` (the `is_active` ↔ status mapping in
`_shared/stripe.ts`) and `provisionFiscalAgentFromCheckout` are exercised only
through the full Stripe round-trip. That round-trip is excellent but slow and
flaky-prone (test clocks, async). The status→`is_active` table
(active/trialing/past_due → true; else false) is pure logic that deserves a fast
unit test so a mapping regression is caught without the full forwarder.

---

## Mutation-resistance spot checks

- **`policy.canMutate`** — flip `hasRequiredSubscription` to `||` an extra
  truthy, or invert the admin check: **CAUGHT** by `policy.test.js:74-78` and
  `useWriteGuard.test.js:32-37`. Verdict: protected.
- **`guards.resolveGuard` role-vs-billing ordering** — if a refactor consulted
  billing before role on admin routes (sending a wrong-role user to the billing
  nudge instead of `/`): **CAUGHT** by `guards.test.js:122-127`. Verdict: protected.
- **RLS `tenant_id` force-derivation trigger** — if the trigger stopped
  overriding a forged `tenant_id` on insert: **CAUGHT** by
  `rls-adversarial.test.sh:142-146` (POISON grant assertion). Verdict: protected
  *if the shell suite is run*.
- **`getRequiredAccessToken` project-ref mismatch sign-out** — if the `!==`
  became `===` or the mismatch branch were dropped: **NOT CAUGHT** anywhere.
  Verdict: unprotected (gap #1).
- **`upsertSubscriptionFromStripe` past_due→is_active mapping** — if `past_due`
  flipped to `is_active=false`: **CAUGHT** by `webhook-matrix.test.sh:145-146`,
  but only in the opt-in tier. Verdict: protected-but-not-continuous.

---

## Remediation plan (prioritized, actionable)

1. **Add `frontend/src/lib/billing.test.js`** (highest value, fastest). Unit-test,
   with Supabase auth mocked at the boundary:
   - `decodeJwtPayload` round-trips a known payload incl. base64url padding edge
     cases; returns `null` on garbage.
   - `getRequiredAccessToken` signs out + throws when the token `ref` ≠ project
     ref, and returns the token when they match. This closes the only untested
     security path in the client.
   - `invokeFirstAvailable` falls through to the second candidate when the first
     throws / returns no `url`, and surfaces the last error when all fail.
   - `hasFeature`, `isOrgAdminSubscriptionRequired` truth tables.

2. **Delete or rewrite `App.test.js`.** Replace the `expect(true)` tautology with
   a test that asserts `App.js`'s route table wires the expected
   `requireRole`/`billingMode` per route (import the route config, or render
   `<App>` with seeded sessions and assert redirects) so the guard matrix is
   checked against the *actual* routes, not just a hand-copied mirror in
   `guards.test.js`.

3. **Collapse the 8 `*.sentry.test.js` into one shared helper-driven test** (or a
   `describe.each`) and stop asserting on the exact console string — assert only
   that the error path reports to Sentry. Reclaim the saved effort by adding a
   **success-path** behavioral test for at least `CreateGrant`, `AddExpenseModal`,
   `BudgetItemModal` (assert the correct row payload is sent to
   `supabase.from(...).insert/update`), which currently has no unit coverage.

4. **Wire the shell + e2e tiers into CI** (even if gated/nightly). At minimum run
   `rls-adversarial.test.sh` and `authz-identity.test.sh` on every PR against a
   throwaway local stack — they are the repo's real security net and are
   deterministic (no Stripe needed for RLS). Document the one-command bring-up in
   `run-all.sh`'s spirit so it's not "remember to run it."

5. **Add a bad-signature negative case to `email-resilience.test.sh`** (it already
   hand-signs events): POST an event with a tampered body / wrong secret and
   assert the webhook returns the rejection status and writes nothing.

6. **Add a fast unit test for `upsertSubscriptionFromStripe`'s status→is_active
   mapping** (`_shared/stripe.ts`) using a Deno test or a thin extracted pure
   function, so the grace-window invariant is caught continuously, not only in the
   slow forwarder run.

## Bottom line

The premise "AI tests confirming AI code" does **not** hold for the parts that
matter: RLS, webhook projection, edge-function identity, and the policy/guard
layer are all defended by real boundary tests with positive and negative
assertions. The weaknesses are concentrated in the continuously-run `vitest`
tier — one tautology, a redundant Sentry cluster, and a genuine hole in
client-side billing security — plus the operational fact that the best tests are
opt-in. Fix items 1, 2, and 4 and this is a solid 5/5 net.
