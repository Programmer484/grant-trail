-- ============================================================================
-- D4 — super_admin has no read on billing/membership/notifications (ops gap)
-- ============================================================================
-- `is_super_admin()` was never OR'd into the SELECT policies for these tables,
-- so a super_admin (who manages tenants/users) could not inspect a tenant's
-- billing, memberships, notifications, or grant comments via the API.
--
-- Fix: add NEW, additive, READ-ONLY (SELECT) policies that grant super_admin
-- visibility. RLS is permissive (policies OR together), so adding a SELECT
-- policy keyed on is_super_admin() is exactly an OR with the existing owner /
-- admin read policies — no historical policy is edited.
--
-- WRITE access is intentionally NOT granted: inserts/updates/deletes on
-- subscriptions / user_memberships / billing_customers stay on the
-- service_role (Stripe) path, and notifications/grant_comments writes stay on
-- their existing role policies.
-- ============================================================================

CREATE POLICY "Super admins can read all subscriptions"
  ON "public"."subscriptions" FOR SELECT
  USING ("public"."is_super_admin"());

CREATE POLICY "Super admins can read all memberships"
  ON "public"."user_memberships" FOR SELECT
  USING ("public"."is_super_admin"());

CREATE POLICY "Super admins can read all billing customers"
  ON "public"."billing_customers" FOR SELECT
  USING ("public"."is_super_admin"());

CREATE POLICY "Super admins can read all notifications"
  ON "public"."notifications" FOR SELECT
  USING ("public"."is_super_admin"());

CREATE POLICY "Super admins can read all grant comments"
  ON "public"."grant_comments" FOR SELECT
  USING ("public"."is_super_admin"());
