# GrantTrail — Master Task Checklist

> **Single place for everything still open.** The current push: make the **setup &
> deploy instructions complete and gap-free** for all three environments — dev (local),
> staging, production — so the owner can supply secrets and run each deploy without
> hitting an undocumented step.
>
> **Division of labour:** the agent completes/verifies the *instructions* (docs + the
> pipeline files they describe). **The owner supplies all real secrets and runs the
> actual deploys** — agents never hold prod/staging credentials.
>
> **Key/secret policy (decided):**
> - **Resend:** real API key in **all three** (local, staging, production).
> - **Stripe:** **test** keys for **local + staging**; **live** keys for **production** only.
>
> **Detail docs:** local Stripe/email → `docs/how_to/local_stripe_testing.md` ·
> prod deploy → `docs/how_to/prod_setup.md` · load test → `docs/how_to/load_testing.md`.
>
> **Legend:** 🟢 agent end-to-end (docs/code) · 🟠 owner action (secrets/deploy) · 🔴 owner decision

---

## 0. Prerequisite — Git remote

The staging/prod pipelines deploy via **GitHub Environments** (`deploy-staging.yml` /
`deploy-prod.yml` → reusable `deploy.yml`) and `scripts/deploy_secrets.js`. The remote
was deleted 2026-06-30, so the repo is **local-only** — none of that can run until a
remote exists again.

- [ ] 🟠 Re-create a GitHub remote and push `main` (needed for CI + staging/prod deploys)
- [ ] 🟢 Once a remote exists, document the branch-protection + required-checks setup in `docs/`

---

## 1. Dev (local) from scratch

Goal: a clean machine → working local app with Stripe test billing **and** real Resend
email, by following the docs verbatim. Instructions must omit nothing.

- [ ] 🟢 Verify `npm run setup` → `db:start` → `db:reset` → `dev` works clean and the docs match (squashed-baseline migrations apply; see `supabase/migrations/README.md`)
- [ ] 🟢 Document local **Stripe test** flow end-to-end (keys → `supabase/functions/.env` → `functions serve --env-file` → `stripe listen`); confirm `docs/how_to/local_stripe_testing.md` is complete
- [ ] 🟢 Add local **email** to the dev flow — **audit gap #10:** `local_stripe_testing.md`'s dotenv block (lines ~80–86) lists only `STRIPE_*` + `APP_URL`; add real `RESEND_API_KEY=` + `EMAIL_FROM=` (verified-domain address) and a "trigger a checkout/inquiry → confirm the email in Resend → Emails" step. Without it `_shared/email.ts` silently no-ops.
- [ ] 🟠 Supply the real Resend key + Stripe test keys locally and run the smoke test (purchase lifts paywall + receipt/inquiry email lands)

---

## 2. Staging

Its own Supabase project + Vercel project + GitHub `staging` Environment. Stripe **test**,
Resend **real**. Instructions live in the docs; owner fills `.deploy/staging.env` and deploys.

- [ ] 🟢 Write `docs/how_to/staging_setup.md` (**audit gap #8 — none exists today; `ci.env.example` even points staging readers at `prod_setup.md`**). Must cover what prod's doesn't: separate staging **Supabase** project (own ref + token); separate **Vercel** project with a **distinct `VERCEL_PROJECT_ID`** (deploy.yml only *warns* — same ID → staging publishes into prod); the webhook-create command with the **test** key against `https://<staging-ref>.supabase.co/functions/v1/stripe-webhook`; test `price_`/`prod_` IDs; **real** Resend key + verified `EMAIL_FROM`; `APP_URL` = staging URL; note staging deploys as a Vercel **preview** (no `--prod`) and how to reach/alias it; point at prod_setup Part A step 6 (already loops the staging preview env vars).
- [ ] 🟠 Fill `.deploy/staging.env`, then **`npm run deploy:secrets:staging`** (**audit gap #9 — do NOT run `node scripts/deploy_secrets.js staging`; the positional arg is ignored and it defaults to `--env production`, pushing to PROD**)
- [ ] 🟠 Run **Deploy to Staging** (`workflow_dispatch`); verify migrations push, edge functions deploy, Vercel preview is live
- [ ] 🟢 **Staging gets the fake seed data (accounts/grants/expenses); prod does NOT.** `supabase/seed.sql` is self-contained (creates its own `auth.users` + public rows), so seeding staging = load it against the staging DB — `seed_auth.mjs` is not needed remotely. Add a **guarded** `db:seed:staging` script + document it: it must refuse to run against the **production** project ref (seed.sql is **not idempotent** — plain INSERTs — so it's a fresh-DB-only operation; re-running errors on duplicate keys). `db push` never runs seed.sql, so prod stays clean automatically.
- [ ] 🟠 Seed staging once (after the staging DB is fresh): run `npm run db:seed:staging`
- [ ] 🟠 Staging smoke test: log in as a seeded account (`password123`), Stripe **test** purchase lifts paywall + Resend email lands

---

## 3. Production

Prod Supabase project already exists (`danufmurtwqlmbiyfdih`). Stripe **live**, Resend
**real**. Full steps: `docs/how_to/prod_setup.md`.

> **Prod stays clean — no fake seed data.** `deploy.yml` only runs `db push` (migrations)
> + the real `bootstrap_data.sql` rows (tenant, settings, buckets). Never run `seed.sql`
> against prod; the `db:seed:staging` guard must hard-refuse the prod ref.

- [ ] 🟢 Fix `prod_setup.md` blockers found by the audit (each hard-stops `deploy:secrets`):
  - **#1** `STRIPE_WEBHOOK_SECRET` is documented as auto-derived but isn't — `deploy_secrets.js` only auto-fetches Supabase URL/key + Vercel org id. Move it from `=== AUTOFILLED ===` to **MANDATORY** in both `deploy/*.env.example`, and reword prod_setup lines 108/111 to "paste the `whsec_…` from Part A step 3."
  - **#2** Drop the "email is optional / Turning on email later" framing (lines ~116–118) — `RESEND_API_KEY` + `EMAIL_FROM` are required by the script and by policy; treat both as mandatory.
  - **#3** Broken link: prod_setup line 56 references `EMAIL-DNS-SETUP.md`, which **does not exist**. Create it (Resend domain + DNS records) or inline those steps into Part A step 4.
  - **#4** Squash + existing prod project: prod ref `danufmurtwqlmbiyfdih` already exists; because history was squashed, its `supabase_migrations.schema_migrations` must be cleared before the first `db push` or it diverges/fails. Add this line to "Clearing the database."
  - **#5** (cleanup) Step 3's manual `UPDATE platform_settings` is redundant — `deploy.yml` already seeds it from `STRIPE_PRODUCT_*`; relabel as optional verify/repair.
  - **#6/#7** (cleanup) Stale `Programmer484/grant-trail` Actions URL (line 122) + README line 10 says `.deploy/prod.env` (real: `.deploy/production.env`).
- [ ] 🔴 Confirm production uses **live** Stripe keys (vs. test in local/staging)
- [ ] 🟠 Fill `.deploy/production.env`; create the **live** Stripe webhook + the Resend key; push via **`npm run deploy:secrets`** (defaults to production)
- [ ] 🟠 Run **Deploy to Production** (`workflow_dispatch`)
- [ ] 🟠 End-to-end smoke test: one real purchase (live card, refund after) → paywall lifts **and** receipt email lands
- [ ] 🟠 After upgrading the prod Supabase instance, re-run the load test (`tests/load/k6-load-test.js`) at expected concurrency
- [ ] 🟢 Run security overview

---

## 4. Known issues / cleanup

- [x] 🟢 Fix `supabase/tests/platform-root-config.test.sh` 5/1 failure — re-targeted the assertion at a greenleaf user with no exemption path (was the bright-horizons admin, who legitimately has premium). Now 6/6; other DB suites unaffected.
- [ ] 🟢 **Audit gap #11** (low pri): `load_testing.md` references indexes on `audit_log`/`grant_record`/`expenses` "in the initial schema" — verify those table names still match the squashed baseline (e.g. `grant_record` vs `grants`).

---

> **Charity-directory review** (can wait) — see project memory `charity-directory-followups`.
> **Billing model redesign** (future, optional) → `docs/roadmap/billing-model-redesign.md`
