# Architecture Review — Outstanding Follow-ups

Tracked work deferred from the 2026-06-30 architecture-review + refactoring effort.
Source audits: `tests.md`, `workflows.md`, `modularity.md`, `security.md` (same folder).
The PRs that landed: #77 (CI), #78 (security audit docs), #79 (tests + modularity + type infra),
#81 (RLS escalation fix).

## Security (from `security.md` / PR #78) — highest priority
- [ ] **F4 (MED/LOW) — storage IDOR.** Storage SELECT scopes by tenant but not by grant owner →
      intra-tenant access to receipts/attachments via guessable sequential paths. Needs an
      owner-scoped storage policy. Left for human review (risky policy rewrite).
- [x] **F5 (LOW) — `xlsx` advisory.** Reviewed 2026-06-30: `xlsx` is used write-only in this
      codebase (`ExpenseReports.js` builds/downloads a workbook; no `XLSX.read`/parsing of
      untrusted input anywhere). The known CVEs are in the parsing path, so actual exposure here
      is much lower than the advisory implies — no swap or sandboxing needed. `npm audit` stays
      advisory-only (`|| true`) by design.
- [ ] **F6 (LOW) — CSP is Report-Only.** Reviewed 2026-06-30: no `report-uri`/`report-to` endpoint
      is configured at all, and `vercel.json` has `deploymentEnabled.main: false` (not deployed) —
      there is no telemetry to confirm "no violations" against. Still blocked on having a live
      deployment with reporting wired up before flipping to enforcing.
- [x] **F7 (LOW) — `notify-inquiry` unrate-limited.** Fixed: added a `notified_at` column
      (`20260630150000_inquiry_notified_at.sql`) and an atomic `UPDATE ... WHERE notified_at IS
      NULL` claim-and-skip guard in the function — one notification per inquiry, ever, race-safe.
      Closes the actual abuse vector (repeated POSTs against one `inquiryId` email-bombing a
      charity's inbox) rather than just slowing it down.
- [x] **RLS perf nit.** Fixed (`20260630191700_rls_wrap_helpers_in_select_for_initplan.sql`): 65
      policies rewritten to wrap `current_tenant_id()` / `is_admin()` / `is_super_admin()` /
      `has_basic_membership()` / `has_premium_membership()` in `(SELECT ...)` for initplan
      caching. Predicate logic unchanged (mechanical rewrite); `storage_object_tenant_id(name)`
      calls deliberately left unwrapped (correlated to the row, can't be hoisted). RLS adversarial
      suite stays at 46/46.

## Resolved during #81 verification
- [x] **Seed breakage from the F1 guard** — the BEFORE INSERT guard initially rejected `seed.sql`'s
      direct user inserts (run as `postgres`, no `auth.uid()`), breaking `db reset`. Fixed
      (commit c1e7b2c) by exempting the no-end-user-identity context (`auth.uid() IS NULL`). On a
      fresh `db:reset` the seed succeeds and `rls-adversarial.test.sh` is **46/46** — including the
      `"grantee cannot plant a grant into another tenant"` case the agent had seen fail on its
      non-fresh stack (a seed/membership artifact, not a real hole).

## Modularity (from `modularity.md` / PR #79) — Phases not completed
- [x] **Phase 2 remainder:** Done 2026-06-30. Added `lib/data/tenants.js` (12 functions) and
      `lib/data/users.js` (6 functions); `TenantManagement` and `AdminUserList` no longer call
      `supabase.from(...)` directly.
- [x] **Phase 3:** Done 2026-06-30. Extracted `useGrantReview`, `useExpenseReports`,
      `useGrantBreakdown` hooks (own the load-state triad + fetch effect) out of
      `AdminGrantReview`, `ExpenseReports`, `GrantBreakdown`; added supporting `lib/data/`
      helpers (`receipts.js`, `grantReview.js`, plus additions to `grants.js`/`expenses.js`/
      `budgetItems.js`). Pure structural extraction, no behavior change.
- [x] **Reconcile `hooks/useGrantee.js` `useUser()`** — Done 2026-06-30: confirmed zero callers
      anywhere in the app (only its own dedicated test exercised it). Deleted the hook, its test,
      and the stale README mention.
- [ ] **Phases 4/5 (untouched by design):** `App.js` session-hook split; `_shared/stripe.ts`
      (516 lines, 4 jobs) split via re-exports.

## Type safety (PR #79)
- [ ] **Widen typecheck scope.** `checkJs` is enforced only over the load-bearing closure
      (`src/lib`, `src/hooks`, `supabaseClient`); full-src has ~187 legacy errors. Ratchet outward
      as files get annotated (TODO in `frontend/tsconfig.json`).
- [x] **Refresh `.claude/agents/*` for the new norms.** Checked 2026-06-30: all three defs
      (`component-builder`, `migration-author`, `rls-reviewer`) already cite `npm run verify` /
      `verify:full` and the `lib/data/` layer — this was already done in a prior session, item
      was stale.

## Verification / CI
- [x] **Run `npm run verify:full` end-to-end.** Done 2026-06-30 with the combined Phase 2/3 +
      F7 + RLS-perf changes applied together: fast tier 117/117 tests green; SQL stack tier
      (RLS adversarial, charity-directory RLS, grant-trigger-behaviors, platform-root-config) all
      green at full counts, zero `FAIL` lines. Edge-fn identity and Playwright e2e tiers fail in
      this sandbox only on missing `STRIPE_SECRET_KEY` / `SUPABASE_SERVICE_ROLE_KEY` env vars —
      pre-existing local-env gap, not a regression; needs real local secrets to close out fully.
- [ ] **Wire CI to call `npm run verify`** — skipped 2026-06-30: repo currently has no GitHub
      remote (local-only), so there's no CI to wire. Revisit once a remote exists.
- [x] **#77 C1 — Vercel staging/prod target.** Confirmed `VERCEL_PROJECT_ID` differs per GitHub
      Environment (owner-confirmed 2026-06-30).

## Repo hygiene
- [x] **Prune stale agent worktrees** under `.claude/worktrees/` — checked 2026-06-30, directory
      doesn't exist; already clean.
- [ ] **Stray PR #80 ("Add test.txt")** — skipped 2026-06-30: repo has no GitHub remote right now,
      so there's no PR to close via `gh`. Revisit once a remote exists.
