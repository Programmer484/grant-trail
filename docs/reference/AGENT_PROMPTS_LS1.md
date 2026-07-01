# LS1 — Full Role Test Run (Agent Launch Prompts)

Implements **LS1** in `docs/roadmap/AGENT_TASKS.md`: drive each role through its
walkthrough **step by step**, prove every feature works for the actor **and shows
up correctly for the other people who should see it**.

Source of truth for what to test = the walkthroughs:
- `docs/tutorials/Grantee-Walkthrough.md`
- `docs/tutorials/Admin-Walkthrough.md`
- `docs/tutorials/Super-Admin-Walkthrough.md`

Four lanes. Each opens its own PR; file footprints are partitioned so they run in
parallel. **Every lane must:** (1) read its walkthrough, (2) check the coverage map
below + read the cited existing specs so it doesn't duplicate, (3) **review the
relevant `frontend/src` source for real selectors/behavior before writing**, (4) add
only the NEW spec file it owns, reuse `frontend/tests/e2e/fixtures.js`, keep specs
deterministic (web-first assertions, no arbitrary sleeps), and run `npm run e2e`
(needs the local Supabase stack) until green.

## Lane ownership (who writes what)

| Lane | New spec file it owns | Must NOT touch |
|---|---|---|
| G — Grantee | `frontend/tests/e2e/grantee-walkthrough.spec.js` | any other spec; `frontend/src`, `supabase/` |
| A — Admin | `frontend/tests/e2e/admin-walkthrough.spec.js` | any other spec; `frontend/src`, `supabase/` |
| S — Super-admin | `frontend/tests/e2e/super-admin-walkthrough.spec.js` | any other spec; `frontend/src`, `supabase/` |
| X — Cross-role visibility | `frontend/tests/e2e/cross-role-visibility.spec.js` | any other spec; `frontend/src`, `supabase/` |

> **Only shared file: `frontend/tests/e2e/fixtures.js`.** Lanes G/A/S must NOT edit it —
> seed inside your own spec's `beforeAll` using the existing service-role patterns
> (see `grantee-flows.spec.js`). **Lane X owns `fixtures.js`** and may *append* new
> multi-actor helpers (e.g. a managed tenant + admin + grantee in one tenant); it must
> only add methods, never change existing ones or the teardown order.

Auth in-browser: go to `/login`, fill `#email` / `#password`, submit, wait for redirect
(pattern proven in `grantee-flows.spec.js`). Seed users with
`supabase.auth.admin.createUser` + `provision_self_service_tenant` (self-service) or
`createManagedTenant` + `createUserRecord` + `createInvite` (managed).

Routes (from `frontend/src/App.js`): grantee `/`, `/grants`, `/grants/new`,
`/grants/:id`, `/grants/:id/edit`, `/grants/:id/breakdown`, `/expenses`,
`/subscription`; admin `/admin`, `/admin/grants`, `/admin/grants/:id`, `/admin/users`,
`/admin/settings`, `/admin/audit`; super-admin `/super/tenants`.

---

## Coverage map (already covered → focus the gaps)

**Grantee** (`Grantee-Walkthrough.md`)
- Covered: signup self-service (`onboarding.spec.js`) & invite (`invite-onboarding.spec.js`); status-history timeline, grant-document attachment upload, expense CSV export (`grantee-flows.spec.js`); subscription purchase w/ Stripe mock (`subscription.spec.js`); Excel export (`reporting.spec.js`); expense tracking (`workspace.spec.js`); grantee notifications (`notifications-audit.spec.js`).
- **Gaps to add:** dashboard stat cards + charts + tax-month reminder (§3); grants list search/status-tabs/sort/card-table-toggle/pagination (§4); create grant via UI form (§5); grant-detail budget donut + admin-comments render (§6); edit/resubmit a "needs_changes" grant + self-service edit (§7); budget items add/edit/delete via UI (§8); expense add/edit/delete + receipt upload + view-receipt signed URL (§9); expense-report filtering (search/grant/status/date presets) (§11); footer support-contact fallback (§13); subscription status-chip states — waived / tenant-exempt (§14).

**Admin** (`Admin-Walkthrough.md`)
- Covered: approve a pending grant (`admin-review.spec.js`); request-changes, generate invite, promote grantee→admin, toggle approval setting, audit-log render+filter, grant CSV export (`admin-flows.spec.js`); read-only lapse (`subscription.spec.js`).
- **Gaps to add:** admin dashboard stat cards + charts + review queue + support-nudge banner (§2); all-grants search/pending-toggles/sort/columns (§3); review page **reject** path + status history + disbursed-funds card + **add comment** (§4); approve/reject **budget items** (§5); approve/reject **expenses** + view receipt + budget-reject→expenses-reset-to-pending cascade (§6); disable/re-enable a user (§7); approval-settings each toggle effect on new records (§9); support-contact config (§12); **waive / remove-waiver** a grantee subscription (§13).

**Super-admin** (`Super-Admin-Walkthrough.md`)
- Covered: lands on `/super/tenants`, sees cross-tenant data, disable/re-enable tenant, save platform defaults (`super-admin-flows.spec.js`); tenant isolation (`authz-negative.spec.js`).
- **Gaps to add:** tenant stat cards + search/type/status/date filters (§2); **create a managed tenant** → invite link shown (§3); platform-defaults footer fallback precedence (§9); **exempt / require** a tenant's subscription toggle, incl. self-service waiver auto-removal on re-require (§10).

**Cross-role visibility** (the LS1 differentiator — *prove changes by one actor show up for another*; none of this is covered today)
- Grantee submits grant → admin sees it in `/admin/grants`, review queue, dashboard pending count.
- Admin approve / request-changes / reject / **comment** / **set disbursed funds** → grantee sees new status, status-history entry, comment, disbursed amount, **notification**.
- Admin approve/reject budget item & expense → grantee sees status badge change + notification; rejecting a budget item resets its expenses to pending on the grantee side.
- Admin **waive** a grantee's subscription → that grantee gains access (status chip "waived"); **remove waiver** → grantee redirected to `/subscription`.
- Super-admin **exempt** a tenant → grantee in it gains access; **re-require** → grantee gated.
- Super-admin **disable** a tenant → that tenant's users locked out on next load; **re-enable** → restored.
- Tenant isolation while logged in: actor in tenant A never sees tenant B rows in any list (extends `authz-negative.spec.js`, don't edit it).

---

## Lane G — Grantee walkthrough

```
/goal Add an end-to-end Playwright spec frontend/tests/e2e/grantee-walkthrough.spec.js that drives a grantee through docs/tutorials/Grantee-Walkthrough.md step by step and proves each feature works. FIRST read that walkthrough, then read the coverage map in docs/roadmap/AGENT_PROMPTS_LS1.md plus the already-covered specs (grantee-flows, onboarding, workspace, reporting, subscription, notifications-audit) so you do NOT duplicate them, then REVIEW the actual frontend/src components/pages for the real selectors and behavior before writing any assertions (do not guess selectors). Cover the gaps listed for the grantee in that map: dashboard stat cards/charts/tax reminder; grants-list search/status-tabs/sort/card-table toggle/pagination; create-grant via the /grants/new form; grant-detail budget donut + admin-comments; edit & resubmit a needs_changes grant and self-service edit; budget items add/edit/delete; expense add/edit/delete + receipt upload + view-receipt signed URL; expense-report filtering; footer support-contact fallback; subscription status-chip waived/exempt states. Seed data with the service-role patterns in fixtures.js inside your own beforeAll (a self-service grantee with an active subscription; a managed-tenant grantee where approval workflow matters). Log in via /login (#email/#password) per grantee-flows.spec.js. Web-first assertions, no arbitrary sleeps, register every seeded row for teardown. Write ONLY frontend/tests/e2e/grantee-walkthrough.spec.js; do not touch fixtures.js, other specs, frontend/src, or supabase/. Bring up the local stack and run `npm run e2e` (in frontend) for your spec until green. Work in a git worktree and open a PR titled "LS1-G: grantee walkthrough e2e". Context: docs/roadmap/AGENT_TASKS.md (LS1) and docs/roadmap/AGENT_PROMPTS_LS1.md.
```

## Lane A — Admin walkthrough

```
/goal Add an end-to-end Playwright spec frontend/tests/e2e/admin-walkthrough.spec.js that drives a tenant admin through docs/tutorials/Admin-Walkthrough.md step by step. FIRST read that walkthrough, then the coverage map in docs/roadmap/AGENT_PROMPTS_LS1.md plus the already-covered specs (admin-review, admin-flows, subscription read-only-lapse) so you don't duplicate, then REVIEW the actual frontend/src admin pages/components for real selectors and behavior before writing assertions. Cover the admin gaps in that map: admin dashboard stat cards/charts/review-queue/support-nudge banner; all-grants search/pending-toggles/sort/columns; grant review REJECT path + status history + disbursed-funds card + add-comment; approve/reject budget items; approve/reject expenses + view receipt + the budget-reject-resets-linked-expenses-to-pending cascade; disable/re-enable a user; approval-settings toggle effects on newly created records; support-contact config; waive and remove-waiver on a grantee subscription. Seed a managed tenant with an admin + a grantee + a grant with pending budget items/expenses using the service-role patterns in fixtures.js inside your own beforeAll. Log in via /login (#email/#password). Web-first assertions, no sleeps, full teardown. Write ONLY frontend/tests/e2e/admin-walkthrough.spec.js; do not touch fixtures.js, other specs, frontend/src, or supabase/. Run `npm run e2e` (in frontend) against the local stack until green. Work in a git worktree and open a PR titled "LS1-A: admin walkthrough e2e". Context: docs/roadmap/AGENT_TASKS.md (LS1) and docs/roadmap/AGENT_PROMPTS_LS1.md.
```

## Lane S — Super-admin walkthrough

```
/goal Add an end-to-end Playwright spec frontend/tests/e2e/super-admin-walkthrough.spec.js that drives a super_admin through docs/tutorials/Super-Admin-Walkthrough.md step by step. FIRST read that walkthrough, then the coverage map in docs/roadmap/AGENT_PROMPTS_LS1.md plus the covered spec (super-admin-flows, and authz-negative for isolation) so you don't duplicate, then REVIEW the actual frontend/src super-admin pages/components for real selectors and behavior before writing assertions. Cover the super-admin gaps in that map: tenant stat cards + search/type/status/date-range filters; CREATE a managed tenant and assert the invite link is shown and the tenant appears with approvals "Required"; platform-defaults footer fallback precedence; exempt/require a tenant's subscription toggle including the self-service waiver auto-removal when toggling back to Required. A super_admin is created by inserting a users row with role 'super_admin' (per the walkthrough it has no UI); seed with the service-role patterns in fixtures.js inside your own beforeAll. Log in via /login (#email/#password); super-admins land on /super/tenants. Web-first assertions, no sleeps, full teardown (delete any tenants your test created). Write ONLY frontend/tests/e2e/super-admin-walkthrough.spec.js; do not touch fixtures.js, other specs, frontend/src, or supabase/. Run `npm run e2e` (in frontend) against the local stack until green. Work in a git worktree and open a PR titled "LS1-S: super-admin walkthrough e2e". Context: docs/roadmap/AGENT_TASKS.md (LS1) and docs/roadmap/AGENT_PROMPTS_LS1.md.
```

## Lane X — Cross-role visibility

```
/goal Add an end-to-end Playwright spec frontend/tests/e2e/cross-role-visibility.spec.js that proves changes made by one role show up correctly for the other roles/users who should see them — the core LS1 goal. FIRST read all three walkthroughs in docs/tutorials/ and the "Cross-role visibility" section of docs/roadmap/AGENT_PROMPTS_LS1.md, then REVIEW the relevant frontend/src pages so you assert on real UI and notifications, not guesses. Use multiple browser contexts (one per actor) seeded into the SAME managed tenant. Prove: grantee submits a grant -> admin sees it in /admin/grants + review queue + dashboard pending count; admin approve/request-changes/reject/comment/set-disbursed-funds -> grantee sees the new status, a status-history entry, the comment, the disbursed amount, and a notification; admin approve/reject a budget item and an expense -> grantee sees the badge change + notification, and rejecting a budget item resets its expenses to pending for the grantee; admin waive a grantee subscription -> that grantee gains access (status chip "waived"), remove-waiver -> grantee is gated to /subscription; super-admin exempt a tenant -> grantee in it gains access, re-require -> gated; super-admin disable a tenant -> its users are locked out on next load, re-enable -> restored. You OWN frontend/tests/e2e/fixtures.js for this lane: you may APPEND new multi-actor seed helpers (e.g. a managed tenant pre-populated with an admin + grantee + a grant), but only add methods — never change existing helpers or the teardown order. Web-first assertions, no arbitrary sleeps, register everything for teardown. Write ONLY frontend/tests/e2e/cross-role-visibility.spec.js and appended helpers in fixtures.js; do not touch other specs, frontend/src, or supabase/. Run `npm run e2e` (in frontend) against the local stack until green. Work in a git worktree and open a PR titled "LS1-X: cross-role visibility e2e". Context: docs/roadmap/AGENT_TASKS.md (LS1) and docs/roadmap/AGENT_PROMPTS_LS1.md.
```

---

## Notes for the orchestrator

- **Order:** G, A, S, X are independent and can run fully in parallel — each writes one new spec file. The only shared file is `fixtures.js`, owned by Lane X (append-only); G/A/S seed inside their own `beforeAll`.
- **Prereq for the run:** local Supabase stack up (`npm run db:start` / `db:reset`) and the frontend dev server, per `docs/tutorials/local_onboarding.md`. Playwright browsers via `npm run e2e:install`.
- **These are additive, doc-driven test lanes — no app-source or migration changes.** If a lane discovers a real bug (feature broken, or not visible to the right role), it should report it in its PR rather than patching app source.
