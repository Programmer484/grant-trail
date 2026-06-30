# GrantTrail — Modularity Review

Scope: can an AI agent work locally on a small, well-bounded piece without
loading half the repo? Read-only assessment. No code changed.

## Score: 3 / 5 — above average, one structural gap holds it back

What is genuinely good (do not "fix" these):

- **Clean domain folders.** `components/{admin,grant,fiscalAgent,auth,billing,
  layout,common,landing}` with almost no cross-domain reaching. The only
  cross-folder imports are through `common/` (`StatusBadge` ×4,
  `ReadOnlyBanner` ×6) and one legitimate reuse (`admin/AdminGrantReview` →
  `grant/GrantAttachments`). No sibling tangle, no circular smell.
- **Policy / authz / billing are centralized.** `lib/policy.js` (roles,
  subscription gating, `canMutate`, `canViewDirectory`), `lib/guards.js`
  (declarative `<Guard>`), and `lib/billing.js` (checkout, portal, membership,
  `fetchSessionContext`) are cohesive single-domain modules with tests. An
  agent editing access rules touches exactly one file. This is the strongest
  part of the codebase.
- **Edge `_shared/` is used well.** `validation.ts` (7 callers), `stripe.ts`
  (7), `email.ts` (2). The Stripe webhook (201 lines) is thin — it delegates
  to `provisionFiscalAgentFromCheckout` / `upsertSubscriptionFromStripe`. No
  logic duplicated across functions.

What drags the score down:

1. **No data-access layer.** 104 `.from()` calls scattered across 23
   components; 31 files import `supabaseClient` directly. The same tables are
   re-queried inline everywhere: `expenses` ×13, `budget_items` ×10,
   `grant_record` ×9, `users` ×9, `receipts` ×6. `lib/` has billing,
   inquiries, invites — but **no grants/expenses/tenants modules**. This is the
   single biggest thing forcing whole-context work: to touch the budget feature
   an agent must re-derive the schema and query shape from JSX.
2. **A handful of god components** mix 4–6 responsibilities each (table below).
3. **Business logic buried in JSX handlers** — status transitions, the
   "reset linked expenses to pending when a budget item is rejected" cascade
   (`AdminGrantReview` line ~291), completeness scoring, etc. live inside
   component event handlers, not in testable modules.

Net: domain *folders* are well-bounded, but *data and business rules* are not.
An agent can safely edit a UI tweak or an access rule in isolation today; it
cannot safely edit "how budget items work" without reading several large files.

## Worst offenders

| File | Lines | Distinct responsibilities that should be separate |
|------|-------|---------------------------------------------------|
| `components/admin/AdminGrantReview.js` | 772 | 17 `.from()` calls in one file. Loads grant+grantee+history+comments+budget+expenses+receipts; approve/reject/changes action; comment post; disbursed-funds update; budget-item approve/reject (+cascade); expense approve/reject; receipt signed-URL. → split data load into a hook, the 4 mutation groups into a data module, keep JSX. |
| `components/grant/ExpenseReports.js` | 717 | Expense list + filtering + CSV/Excel export + add/edit + receipt handling. Data access + export logic + UI in one. |
| `components/fiscalAgent/FiscalAgentDirectory.js` | 681 | Directory fetch + search/sort/paginate + paywall gate + save/contact + modal orchestration. |
| `components/admin/TenantManagement.js` | 633 | 12 `.from()` calls. Tenant CRUD + settings + member admin in one super-admin screen. |
| `components/grant/GrantBreakdown.js` | 548 | Budget vs actual computation + charts + receipt signed-URLs + data fetch. |
| `components/admin/AdminUserList.js` | 542 | User list + role/active mutations + invites + filtering. |
| `supabase/functions/_shared/stripe.ts` | 516 | Backend god module: customer create/lookup + subscription upsert/sync + listing publication sync + **fiscal-agent provisioning** + `slugify`. Four unrelated jobs. |
| `components/grant/AddExpenseModal.js` | 439 | Form + validation + budget lookup + receipt upload + insert. |
| `App.js` | 456 | Route table (fine) + session bootstrap effects + login/profile/logout handlers (~120 lines, should be a `useSession` hook) + two full-screen inline-styled error/disabled views (~115 lines, belong in `common/`). |

Webhook `stripe-webhook/index.ts` (201) is **not** an offender structurally —
its only smell is ~60 lines of inline payment-confirmation email assembly
(tier→plan-name mapping, `PLAN_NAMES`) that belongs in `_shared/email.ts`.

## Duplication (small but real)

- `formatDate` defined **6×** across components; `toLocaleDateString` inline 6×;
  currency `Intl.NumberFormat` inline in 3 admin files. → one `lib/format.js`.
- `supabase.storage.from('receipts').createSignedUrl(...)` repeated in 3 files
  (`AdminGrantReview`, `GrantBreakdown`, `GrantAttachments`). → one helper.
- The loading/error/data `useState` triad repeats throughout (283 `useState`
  calls total). Not worth a generic abstraction, but per-entity load hooks
  (below) absorb most of it.

## Remediation plan (incremental, behavior-preserving)

Each step is mechanical, reviewable alone, and changes no behavior. Adopt the
new modules in *new* code immediately; migrate callers file-by-file. Do **not**
build a generic repository/ORM abstraction — thin per-entity function modules
that wrap the exact queries already in use. The win is locality, not layering.

**Phase 1 — shared utilities (1 PR, pure extraction, lowest risk)**
- Create `lib/format.js`: `formatDate`, `formatCurrency`. Replace the 6 inline
  `formatDate` copies and 3 `Intl.NumberFormat` copies with imports.
- Create `lib/receipts.js` with `getReceiptSignedUrl(path)`; replace the 3
  inline `createSignedUrl` calls.

**Phase 2 — data-access modules (the high-value step)**
Add `lib/data/` with one thin module per entity, each just exporting the async
query functions already inlined today (copy-move, no logic change):
- `lib/data/grants.js` — `getGrant(id)`, `listGrants(filter)`,
  `updateGrantStatus(id, status, notes)`, `setDisbursedFunds(id, value)`.
- `lib/data/expenses.js` — `listExpenses(grantId)`, `setExpenseStatus`,
  `addExpense(...)`.
- `lib/data/budgetItems.js` — `listBudgetItems(grantId)`,
  `setBudgetItemStatus` (incl. the reject→expenses-pending cascade, so the
  business rule lives in one tested place).
- `lib/data/tenants.js`, `lib/data/users.js`, `lib/data/fiscalAgents.js` for
  the super-admin and directory screens.
Migrate one component per PR. Target the heaviest first: `AdminGrantReview`,
`TenantManagement`, `GrantBreakdown`.

**Phase 3 — load hooks (absorbs the state triads)**
- `hooks/useGrantReview(id)` returns `{grant, grantee, history, comments,
  budgetItems, expenses, receiptMap, loading, error, reload}` — lifts the
  155-line `load()` out of `AdminGrantReview`, leaving it a presentational
  component plus handler wiring. Same pattern for `useExpenseReports`,
  `useGrantBreakdown`.
- Note: `hooks/useGrantee.js` `useUser()` queries `users` by `user_id` while
  the app elsewhere uses the `get_session_context` RPC — verify it is not stale
  before reusing; reconcile or delete.

**Phase 4 — App.js slim-down**
- Extract session bootstrap + `handleLogin`/`handleProfileComplete`/
  `handleLogout` into `hooks/useSession.js`.
- Move the inline "Account Disabled" and "Something went wrong" full-screen
  views into `components/common/FullScreenNotice.js`. App.js drops to ~the
  route table.

**Phase 5 — backend `_shared/stripe.ts` split**
- Split into `_shared/stripe-customer.ts` (client, customer create/lookup),
  `_shared/subscriptions.ts` (`upsertSubscriptionFromStripe`,
  `syncListingPublicationFromSubscription`), and
  `_shared/fiscal-agent-provisioning.ts` (`provisionFiscalAgentFromCheckout`,
  `slugify`). Re-export from `stripe.ts` so the 7 callers keep working, then
  migrate imports.
- Move the webhook's inline payment-confirmation email assembly into
  `_shared/email.ts` as `buildPaymentConfirmation(session, subscription)`.

Order rationale: Phases 1–2 are pure copy-move (safe, immediately useful);
3–4 are confined to one file each; 5 is backend and isolated by re-exports.
Stop after Phase 2 if time is short — it removes the biggest barrier to local
work on its own.
