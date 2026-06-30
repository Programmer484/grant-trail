# CI/CD & Workflow Audit — GrantTrail

Scope: `.github/workflows/{ci,deploy,deploy-staging,deploy-prod}.yml`,
`.github/scripts/edge-fn-ci-lib.sh`, `.githooks/pre-push`,
`scripts/{install-git-hooks,deploy_secrets,prune_functions,promote_admin}.js`,
`vercel.json`, `deno.lock`, `supabase/config.toml`, root + frontend `package.json`.

Read-only assessment. Nothing was modified except this file.

---

## Professional-CI score: 3 / 5

**Justification.** This is a genuinely above-average solo/small-team setup. CI
actually gates the important things on every PR: ESLint, Vitest unit tests, a
production build, Playwright e2e against a real local Supabase stack, a
migration-replay job that catches NOT-NULL/unique violations a from-scratch
reset misses, DB-trigger behaviour tests, and two tiers of edge-function tests.
The deploy path is factored cleanly into one reusable workflow with two thin
callers, secrets in `deploy_secrets.js` are passed over **stdin** (not argv) and
masked in logs, and the pre-push hook fails open by design so it never blocks on
a stopped Docker.

It loses two points for missing professional-hardening basics and one genuine
targeting bug:

- **No `permissions:` block in any workflow** → default (broad) `GITHUB_TOKEN`.
- **No `concurrency:` anywhere** → overlapping deploys can race migrations.
- **Third-party action + all CLI versions unpinned** (`supabase/setup-cli@v2`,
  `version: latest`, Stripe CLI "latest") → non-reproducible, supply-chain risk.
- **The reusable deploy always targets Vercel *production*** regardless of the
  `staging`/`production` input — a real correctness bug, not just hygiene.

Fix the ranked items below and this is a solid 4.5.

---

## Ranked findings

### Security

**S1 — No `permissions:` declared in any workflow.**
`ci.yml`, `deploy.yml`, `deploy-staging.yml`, `deploy-prod.yml` (all, top level).
Every job runs with the repo-default `GITHUB_TOKEN` scope. None of these jobs
need write scopes. Impact: a compromised dependency/action in any step inherits
whatever the default is (historically read/write on older repos). Least
privilege is the single highest-value missing control here.

**S2 — Reusable deploy interpolates secrets directly into shell command lines.**
`deploy.yml:35-44` (`supabase secrets set STRIPE_SECRET_KEY="${{ secrets... }}"`),
also `:96`, `:102`, `:115` (`--token=${{ secrets.VERCEL_TOKEN }}`).
GitHub masks these in logs, but they land in the runner's process argv (visible
to any concurrent step via `ps`/`/proc`) and the `${{ }}` template is expanded by
the runner *before* the shell sees it, so a metacharacter in a value would be a
script-injection vector. Contrast with `deploy_secrets.js:411`, which correctly
pipes secret values over stdin. Pass tokens/secrets via `env:` and reference
`"$VAR"` inside the script instead of inlining `${{ }}`.

**S3 — `vars`/SQL interpolated into a `run` block (injection-shaped).**
`deploy.yml:62-63` builds a SQL string with `${{ vars.STRIPE_PRODUCT_BASIC }}`
and `${{ vars.STRIPE_PRODUCT_FISCAL_AGENT }}` and runs it via `supabase db query`.
`vars` are admin-controlled so real risk is low, but it's a textbook
untrusted-input-into-command / SQL-injection pattern. Move the values into `env:`
and reference them as bound `$VARS`, or run the seed from a checked-in `.sql`
file with parameters.

**S4 — Third-party action not SHA-pinned; CLI versions float.**
`supabase/setup-cli@v2` (`ci.yml:54,103,141,187,226`; `deploy.yml:26`) is pinned
only to a moving major tag, and every invocation uses `version: latest` for the
Supabase CLI. The Stripe CLI install (`ci.yml:241-250`) fetches "latest" from the
GitHub API with a hardcoded `1.21.8` fallback and **no checksum verification** of
the downloaded tarball. Impact: a malicious/broken upstream release reaches your
deploy + secret-bearing jobs with no code change. Pin `supabase/setup-cli` to a
commit SHA and pin a concrete CLI `version:`. (First-party `actions/*` tags are
lower risk but pinning them too is the consistent move.)

**S5 — `environment: ci` secrets exposed on `pull_request` runs.**
`ci.yml:207-209` — `stripe-edge-function-tests` carries `environment: ci` and
runs on `pull_request`. For a single-owner private repo this is fine (fork PRs
don't receive secrets without approval), but if the repo ever takes outside
contributors, add `if: github.event.pull_request.head.repo.fork == false` (or an
environment approval gate) so the `STRIPE_*_TEST` secrets can't be exfiltrated by
a malicious PR.

### Correctness

**C1 — Reusable deploy always deploys to Vercel PRODUCTION, even for staging.**
`deploy.yml:96` (`vercel pull --environment=production`), `:102`
(`vercel build --prod`), `:115` (`vercel deploy --prebuilt --prod`) are hardcoded
and ignore `inputs.environment` (`:19`). So `deploy-staging.yml` switches the
GitHub Environment (Supabase project ref, secrets, `VITE_*`) but still publishes
the frontend to the **production** Vercel target. A "staging" deploy can ship a
staging-built bundle to the prod Vercel project. Drive the Vercel environment
from the input (e.g. map `staging`→`preview`/a staging project, `production`→
`production`) instead of hardcoding `--prod`.

**C2 — Nothing deploys automatically; "temporary" disable is a latent footgun.**
`deploy-staging.yml:9-11` has the `push: branches: [main]` trigger commented out
("TEMPORARILY DISABLED"); `deploy-prod.yml` is `workflow_dispatch` only;
`vercel.json:6-10` also disables git deploys for `main`. Net: **everything is
manual.** That's a defensible choice, but the staging safety-net is off and the
comment says "temporarily" with no tracking — classic drift. Either re-enable the
staging push trigger (with concurrency, see H3) or delete the comment and
document the manual-only policy so it's a decision, not an accident.

**C3 — Two divergent definitions of "which edge functions exist."**
`deploy.yml:73-79` deploys **every `supabase/functions/*/` dir that has an
`index.ts`**, while `config.toml` ([functions.*], 7 declared) and
`scripts/prune_functions.js:46-56` use the **declared list**. The inline prune in
`deploy.yml:81-88` also duplicates `prune_functions.js`. These can diverge: a dir
with an `index.ts` not declared in `config.toml` gets deployed by CI but is
invisible to the script-based prune, and vice-versa. Pick one source of truth
(config.toml) and have the workflow call `prune_functions.js` rather than
re-implementing it.

### Hygiene / reproducibility

**H1 — No `concurrency:` on deploy workflows.** `deploy.yml`,
`deploy-staging.yml`, `deploy-prod.yml`. Two manual prod dispatches (or a future
push trigger) can run `supabase db push` / `functions deploy` concurrently against
the same project. Add `concurrency: { group: deploy-${{ inputs.environment }},
cancel-in-progress: false }`.

**H2 — No `concurrency:` on CI either.** `ci.yml:1-7`. A push to `main` plus its
PR run the full (slow, Supabase+Playwright) matrix twice in parallel. Add
`concurrency: { group: ci-${{ github.ref }}, cancel-in-progress: true }`.

**H3 — No `timeout-minutes` on any job.** A hung `stripe listen`, `supabase
start`, or Playwright run defaults to the 6-hour cap and burns minutes. Add a
`timeout-minutes` (e.g. 15–20) to each job.

**H4 — `setup-node` version drift.** `ci.yml:22` uses `actions/setup-node@v5`;
`deploy.yml:91` uses `@v4`. Align them.

**H5 — Node pinned to major only.** `node-version: 20` (`ci.yml:24`,
`deploy.yml:93`). For full reproducibility pin a minor (e.g. `20.17.0`) or use an
`.nvmrc` + `node-version-file`. Lower priority — `npm ci` against the committed
lockfile already gives most of the determinism.

**H6 — Supabase CLI version unpinned (reproducibility half of S4).** Same
`version: latest` calls. A CLI release changing `db diff`/`db push`/`functions
deploy` behaviour can break deploy with no repo change. Pin a concrete version
once and bump deliberately.

**H7 — Pre-push hook only checks schema drift.** `.githooks/pre-push` runs
`supabase db diff` and nothing else; lint/test/build only run in CI. That's a
reasonable speed trade-off (fail-open, documented), not a defect — noting it so
the gap is intentional: the first real gate is CI, so branch protection must
require the CI checks (see H8).

**H8 — Gating depends on branch protection that isn't in the repo.** All the good
CI jobs only *block* a merge if they're configured as required status checks in
GitHub branch-protection settings (not visible in-repo). Confirm
`build-and-test`, `migration-replay`, `edge-function-tests`, `db-trigger-tests`,
and `stripe-edge-function-tests` are all marked required on `main`. Note that the
"skip if not present" guards (`ci.yml:214-222`, `edge-fn-ci-lib.sh:68-72`) make a
missing test file a **green no-op**, so a required check can pass while testing
nothing — fine as a migration aid, but worth removing once the files have landed.

---

## Remediation plan (actionable, per file)

### `.github/workflows/ci.yml`
1. Add at top level (after `on:`):
   ```yaml
   permissions:
     contents: read
   concurrency:
     group: ci-${{ github.ref }}
     cancel-in-progress: true
   ```
2. Add `timeout-minutes: 20` to each job.
3. Pin the CLI: replace every `version: latest` under `supabase/setup-cli` with a
   concrete version (e.g. `version: 2.106.0`, matching the frontend devDep).
4. SHA-pin `supabase/setup-cli@v2` → `supabase/setup-cli@<sha>  # v2.x`.
5. Stripe CLI install (`:241-250`): pin the version and verify the tarball
   SHA256 before `install` (Stripe publishes checksums on each release).
6. For S5, gate `stripe-edge-function-tests` with
   `if: github.event.pull_request.head.repo.fork == false || github.event_name == 'push'`.
7. Once sibling test files have all landed, drop the "skip if not present"
   guards so required checks can't pass vacuously (H8).

### `.github/workflows/deploy.yml`
1. Add top-level `permissions: { contents: read }` and
   `concurrency: { group: deploy-${{ inputs.environment }}, cancel-in-progress: false }`.
2. **C1**: stop hardcoding `--prod`. Derive the Vercel environment from
   `inputs.environment` — e.g. set a step output `vercel_env` (`production` vs
   `preview`/staging project) and use it in `vercel pull --environment=`,
   `vercel build`, `vercel deploy`. Confirm `VERCEL_PROJECT_ID` differs per
   GitHub Environment so staging can't publish to the prod project.
3. **S2/S3**: move `${{ secrets.* }}` / `${{ vars.* }}` out of `run` command
   lines into `env:` and reference `"$VAR"`; pass the seed SQL values as bound
   env vars or run a checked-in `.sql` file.
4. **C3**: replace the inline deploy-all/prune loop (`:65-88`) with a call to a
   config.toml-driven deploy + `node scripts/prune_functions.js --project-ref
   "$REF" --yes`, so there's one source of truth.
5. Align `actions/setup-node@v4` → `@v5` (H4); pin Node minor or use
   `node-version-file` (H5); add `timeout-minutes`.
6. SHA-pin `supabase/setup-cli` and pin its `version` (S4/H6).

### `.github/workflows/deploy-staging.yml` / `deploy-prod.yml`
1. Decide on C2: either uncomment the staging `push` trigger (with concurrency)
   or remove the "TEMPORARILY DISABLED" comment and document the manual policy.
2. `secrets: inherit` is acceptable for same-repo reusable workflows; no change
   required, but be aware it forwards all repo secrets.

### Repo / GitHub settings (not a file)
1. Mark all CI jobs as **required status checks** on `main` (H8).
2. Keep `production` (and `staging`) as protected GitHub Environments with
   required reviewers — `deploy_secrets.js:381-395` already avoids clobbering
   those rules, so don't regress that.

### Nice-to-have
- Split the monolithic `build-and-test` job (lint/unit/build are fast; the
  Supabase+Playwright e2e is slow) so a lint failure doesn't wait on the stack
  boot. Optional.

---

## Notes on things that are already good (don't "fix" these)
- e2e **does** run in CI against a real Supabase stack (contradicts the common
  "e2e never runs" failure mode).
- `npm ci` (not `npm install`) in CI with `cache: npm` keyed on the lockfile.
- `deno.lock` is committed and integrity-pinned for edge-function deps.
- `deploy_secrets.js` passes secret values over **stdin** (`:411`), masks them in
  output (`:170-173`), checks-before-create to preserve env protection rules
  (`:381-395`), and refuses to deploy when Basic == Pro price (`:370-378`).
- `promote_admin.js` / `prune_functions.js` escape SQL and write queries to temp
  files instead of inlining (avoids the `shell:true` word-split trap).
- `vercel.json` ships a sensible security-header set (HSTS, nosniff, frame-deny,
  CSP report-only).
- `npm audit` is intentionally advisory (`|| true`) with a documented follow-up.
