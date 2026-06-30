#!/usr/bin/env bash
#
# verify:full — the security-critical tier on top of the fast `npm run verify`.
#
# Fast tier (lint + typecheck + format:check + unit) always runs. The stack tier
# (RLS adversarial, grant triggers, charity-directory RLS, platform-root config,
# edge-fn identity, Stripe webhook/checkout/portal matrix, Playwright e2e) needs
# a local Supabase stack and — for the billing tests — Stripe TEST keys.
#
# Fail-open by design: if Docker is unavailable the stack tier is SKIPPED with a
# warning (mirrors the pre-push hook), so this stays runnable on machines that
# can't boot the stack. CI should run it where Docker + Stripe secrets exist.
#
# Reuses the existing runners — it does not reinvent them:
#   supabase/tests/*.test.sh                 (RLS / triggers / config; no Stripe)
#   supabase/functions/tests/authz-identity.test.sh + run-all.sh (edge-fn + Stripe)
#   frontend playwright (npm run e2e)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> fast tier (npm run verify)"
npm run verify --prefix frontend || exit 1

if ! docker info >/dev/null 2>&1; then
  echo "WARN: Docker unavailable — SKIPPING stack tier (RLS, edge-fn, webhook, e2e)."
  echo "      Run on a machine with Docker + Stripe TEST keys for full coverage."
  exit 0
fi

echo "==> booting local Supabase stack"
npx --prefix frontend supabase start || exit 1
npx --prefix frontend supabase db reset || exit 1

fail=0

echo "==> RLS / trigger / config SQL tier (no Stripe needed)"
for t in supabase/tests/*.test.sh; do
  echo "--- $t"
  bash "$t" || fail=1
done

echo "==> edge-function identity"
bash supabase/functions/tests/authz-identity.test.sh || fail=1

# Stripe-dependent tier: only if TEST secrets are present (fail-open otherwise).
if [ -f supabase/functions/.env ] && grep -q STRIPE_SECRET_KEY supabase/functions/.env; then
  echo "==> Stripe payment-flow matrix (run-all.sh)"
  bash supabase/functions/tests/run-all.sh || fail=1
else
  echo "WARN: supabase/functions/.env with STRIPE_SECRET_KEY not found — SKIPPING Stripe matrix."
fi

echo "==> Playwright e2e"
npm run e2e --prefix frontend || fail=1

exit $fail
