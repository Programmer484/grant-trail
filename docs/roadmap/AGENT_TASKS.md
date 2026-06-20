# GrantTrail — Agent Task List

A working task list for AI agents. Human (Ryan) provides high-level oversight: makes 🔴 decisions and does 🟠 external setup; agents do everything else and report back.

**Conventions**
- 🔴 **Decision** — STOP and ask the human; do not guess.
- 🟠 **External** — needs a human action outside the repo (purchase, dashboard, DNS, key). Surface it, then continue on what isn't blocked.
- 🟢 **Autonomous** — do it end-to-end, then request review.
- Check a box only when the work is merged-ready (code + tests + verification), not when drafted.
- Companion doc with rationale, concepts, and time estimates: `grant-trail-production-breakdown.md` (kept in Ryan's home dir).

**Decisions resolved (2026-06-19)** — these were open 🔴 questions, now settled:
- **#40 lapsed admin → read-only degrade.** View everywhere, all mutations blocked → billing nudge.
- **#29 tenant-agnosticism → do it now.** Make platform-root tenant config/flag-driven; drop the `'tfac'` literal before prod.
- **Pay-before-signup → fully pay-first (anonymous checkout).** Fiscal-agent org pays with no account; on payment they get an admin-signup link, then invite their agents/non-profits.
- **Security pass → basic cyber-hygiene baseline** (OWASP basics, no formal framework). Scheduled last.
- **Staging Stripe → test keys are fine** (2026-06-20). Staging runs Stripe **test-mode** keys; real/live keys are a production-only concern.
- **Out of agent scope** (a team member owns these): Payment Confirmation & Receipt Emails; Paywall for Registered Charities List.

---

## 🎯 Launch Sprint — ship by Mon 2026-06-22

Plan set 2026-06-20. Foundation + safety-net *build* is done (see "Completed" below); the
remaining work is **end-to-end validation** and **standing up the real deploy line**.

### LS1 — Full role test run (AI agents as users) 🟢 *today's main task*
The Playwright role specs exist; this is about *exercising* them as real users and proving
features behave correctly **and are visible to the right other people**.
- [ ] 🟢 Audit current coverage: which workflows/roles the existing specs already cover vs. the walkthrough docs (`docs/tutorials/*-Walkthrough.md`)
- [ ] 🟢 Run multiple agents, one per role (`super_admin`, `admin`, `grantee`), through each walkthrough **step by step**
- [ ] 🟢 For every feature: confirm it works for the actor **and** shows up correctly for the other roles/users who should see it (cross-user visibility, not just self-view)
- [ ] 🟢 Log any gaps/regressions; fix or file them

### LS2 — Manual payment re-test (staging, test-mode) 🟠
- [ ] 🟠 Human smoke test on staging with **test** Stripe keys: click through one full purchase per tier; confirm checkout, webhook → DB sync, and UX/receipt path
- [ ] 🔴 Confirm remaining edge cases behave as expected: waiver/exemption × live subscription, lapse→reactivate, webhook idempotency

### LS3 — Connect the real domain 🟠
- [ ] 🟠 Point the purchased domain at the deployed app (DNS + Vercel domain config + auth redirect/allowed URLs)

### LS4 — Stand up the real dev → staging → prod line from scratch 🟠🟢
Goal: prove deployment is genuinely easy by building it clean, end to end.
- [ ] 🟠 Wipe the local working copy and re-clone fresh; bootstrap from scratch (validates onboarding/deploy docs)
- [ ] 🟠 Create a **separate staging GitHub repo** + its own Vercel project + its own Supabase project
- [ ] 🟠 Create the **production** GitHub repo; promotion = PR from staging → prod (prod merges deploy to prod)
- [ ] 🟢 Walk one change all the way through dev → staging → prod; document any friction and fix the docs

---

## Phase 3 — Deploy-line hardening (#39 #29 #27 #8)

Model decided (Option A: Supabase GitHub integration owns migrations + edge functions; merge to `main` = deploy to staging). Remaining hardening (feeds LS4):
- [ ] 🟠 Verify PITR is on; document restore runbook; do one **test restore** to a scratch project (#17 — #1 risk)
- [ ] 🟢 Finish edge-function pruning (`npm run functions:prune`); wire into deploy so removed functions get deleted (#29)
- [ ] 🟠 Branch protection: require CI + Supabase status check before merge to `main` (#8)
- [ ] 🟢 CI migration safety w/o prod access: base-branch migrations on a fresh DB, then PR migrations on top; synthetic fixtures only, never a prod dump (#39; partly done via migration-replay job)
- [ ] 🟢 `config.toml` tenant-agnosticism (#29) — DECIDED: do it now. Remove hard-coded `'tfac'` slug from SECURITY DEFINER logic; make platform-root tenant flag/config-driven (e.g. `platform_root_slug()`). Propose the config shape in the PR.
- [ ] 🟢 Define + document the staging→prod promotion flow; prod auth/secrets/domain bootstrap (#39)
- [ ] 🟠 Buy paid tiers as needed: Supabase Pro (PITR/daily backups), Vercel, GitHub Pro **or** make repo public (branch protection)

---

## Phase 4 — Feature roadmap (each needs its own mini-spec first)

Depends on the launch sprint + deploy line being solid (don't paywall on a shaky billing path).

- [ ] 🔴 **Pay-First Fiscal-Agent Flow** — DECIDED: fully pay-first (anonymous checkout). Needs a dedicated design pass first. Shape:
  1. Org runs Stripe checkout with **no account existing** (Fiscal Agent subscription)
  2. On successful payment → email an **admin-signup link**; account creation **reconciles** the Stripe customer/subscription to the new admin user
  3. Handle the **paid-but-unprovisioned** state (subscription exists, no user yet) safely in RLS
  4. Provisioned admin then issues invite links to their downstream agents/non-profits (existing invite system)
- [ ] 🔴 **Fiscal Agent Listing — Subscription-Based Charity Profiles** — new listing/profile entity for charities acting as fiscal agents; ties to the pay-first subscription. Needs a data-model spec (relates to the pay-first flow above).
- [ ] 🟠 **Upgrade Supabase & test 1,000+ users** — scale validation; k6 script in `tests/load/k6-load-test.js` (needs paid tier)

**Owned by a team member (NOT agent scope):**
- ~~Payment Confirmation & Receipt Emails~~
- ~~Paywall for Registered Charities List~~ — note: viewing the fiscal-agent charities list requires a subscription (team member implements)

---

## Completed (build work, 2026-06-19/20)

Pruned from the active list — code + tests merged. Kept here as a record.

- **Phase 0 — Stripe test-mode**: test keys + prices (basic + fiscal-agent) staged in gitignored `supabase/functions/.env`; webhook secret generated.
- **WS3 — Subscription-vs-authz refactor (#41)**: `frontend/src/lib/guards.js` (+ `guards.test.js`); routes migrated; subscription policy centralized.
- **WS2 — Role distinctions**: `docs/roadmap/role-matrix.md` (route + RLS-table × role, derived from source); human-confirmed and reconciled (D1 — grant/expense surfaces made grantee-only); billing-exemption documented as orthogonal to role.
- **WS4 — Billing-lapse policy (#40)**: read-only degrade implemented (admin reads open, mutations gated → billing nudge); documented in walkthroughs; E2E tested.
- **WS5 — Payment testing (automated lanes)**: `supabase/functions/tests/` — `webhook-matrix.test.sh`, `checkout-sessions.test.sh`, `portal-and-sync.test.sh`, `authz-identity.test.sh`; wired into the Stripe payment-flow CI runner. *(Human smoke test → LS2.)*
- **WS6 — UI flow specs**: `frontend/tests/e2e/` — `admin-flows`, `grantee-flows`, `super-admin-flows`, `authz-negative` (+ existing onboarding/review/reporting/notifications/subscription/workspace/smoke). *(Full agent-driven run → LS1.)*
- **WS7 — Security baseline**: RLS adversarial audit (`rls-audit.md`, tenant-isolation fixes D4/D5/D7, storage tenant-scoping, token-scoped invites); edge-function authz review + identity-spoofing test (`edge-function-authz-review.md`); secure headers + hygiene pass (`security-hygiene.md`); data-protection baseline (`data-protection-baseline.md`).

---

## Decisions — status

**Resolved:** #40 (read-only degrade) · #29 (config-driven now) · pay-first (anonymous checkout) · security level (basic baseline) · staging Stripe = test keys · emails + charities-paywall (team member owns).

**Still owed (specs, not yes/no — defer until Phase 4):**
1. 🔴 Pay-first flow: detailed design pass (checkout-with-no-user, customer reconciliation, paid-but-unprovisioned RLS state)
2. 🔴 Fiscal Agent Listing: charity-profile data model
