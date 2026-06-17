-- ==========================================
-- Drop hard-coded Stripe product ID defaults
-- ==========================================
-- The initial schema seeded platform_settings.basic_membership_product_id /
-- premium_membership_product_id with literal `prod_...` IDs as NOT NULL defaults.
-- Those IDs are environment-specific and must not be baked into the schema.
--
-- Product IDs are now sourced at runtime from the configured Stripe price env
-- vars (STRIPE_PRICE_BASIC / STRIPE_PRICE_PRO) via the Edge Functions
-- (ensurePlatformMembershipProductIds), or set by a super_admin.
--
-- This migration brings any database already created from the old baseline in
-- line: it removes the column defaults and the NOT NULL constraint. It does NOT
-- touch existing row values, so a live environment that already resolved its
-- real product IDs keeps them.
-- ==========================================

ALTER TABLE public.platform_settings
  ALTER COLUMN basic_membership_product_id DROP DEFAULT,
  ALTER COLUMN basic_membership_product_id DROP NOT NULL,
  ALTER COLUMN premium_membership_product_id DROP DEFAULT,
  ALTER COLUMN premium_membership_product_id DROP NOT NULL;

-- Clear values that match the old hard-coded placeholders so they don't masquerade
-- as real configuration; environments with genuine product IDs are left untouched.
UPDATE public.platform_settings
SET basic_membership_product_id = NULL
WHERE basic_membership_product_id = 'prod_UKEACUGjIeg3MU';

UPDATE public.platform_settings
SET premium_membership_product_id = NULL
WHERE premium_membership_product_id = 'prod_UDClBMtvFLKyNW';
