-- ==========================================
-- Enforce subscription gating at the database layer (RLS)
-- ==========================================
-- Closes Critical Flaw #1 (issue #10): subscription access control was enforced
-- only in the React router (App.js -> hasRequiredSubscription). A client with a
-- forged JWT or manipulated state could still create/modify grant data, because
-- the grantee write policies checked ownership only, never membership.
--
-- The helper functions already existed but were unused by any policy:
--   * is_membership_exempt(user)  -> super_admin, TFAC admins, or tenants with
--                                    tenant_settings.require_subscription = false
--   * has_basic_membership(user)  -> exempt OR an active basic/premium membership
--
-- has_basic_membership() (no-arg) resolves the caller via auth.uid() and returns
-- true for every exempt user, so adding it to the grantee write policies mirrors
-- the frontend gate (grantee needs Basic+; super_admins / exempt admins pass)
-- without breaking managed-tenant or super-admin flows.
--
-- Scope decision: this gates writes only (INSERT / UPDATE). SELECT and DELETE are
-- intentionally left ungated so a grantee whose subscription has lapsed can still
-- view and export their existing data and reach the billing/subscription page to
-- resubscribe. Admin/super_admin policies are separate permissive policies and
-- are unaffected. Each gated table's write path has a single permissive grantee
-- policy, so there is no alternate policy that could bypass the gate.

-- grant_record ---------------------------------------------------------------
ALTER POLICY "Users can insert their own grants" ON "public"."grant_record"
  WITH CHECK (
    "public"."has_basic_membership"()
    AND ("user_id" IN ( SELECT "users"."id"
       FROM "public"."users"
      WHERE ("users"."user_id" = "auth"."uid"())))
  );

ALTER POLICY "Users can update their own grants" ON "public"."grant_record"
  USING (
    "public"."has_basic_membership"()
    AND (("tenant_id" = "public"."current_tenant_id"()) AND ("user_id" IN ( SELECT "users"."id"
       FROM "public"."users"
      WHERE ("users"."user_id" = "auth"."uid"()))))
  );

-- expenses -------------------------------------------------------------------
ALTER POLICY "Users can insert expenses for their grants" ON "public"."expenses"
  WITH CHECK (
    "public"."has_basic_membership"()
    AND ("grant_id" IN ( SELECT "gr"."id"
       FROM ("public"."grant_record" "gr"
         JOIN "public"."users" "u" ON (("gr"."user_id" = "u"."id")))
      WHERE ("u"."user_id" = "auth"."uid"())))
  );

ALTER POLICY "Users can update expenses for their grants" ON "public"."expenses"
  USING (
    "public"."has_basic_membership"()
    AND (("tenant_id" = "public"."current_tenant_id"()) AND ("grant_id" IN ( SELECT "gr"."id"
       FROM ("public"."grant_record" "gr"
         JOIN "public"."users" "u" ON (("gr"."user_id" = "u"."id")))
      WHERE ("u"."user_id" = "auth"."uid"()))))
  );

-- budget_items ---------------------------------------------------------------
ALTER POLICY "Users can insert budget items for their grants" ON "public"."budget_items"
  WITH CHECK (
    "public"."has_basic_membership"()
    AND ("grant_id" IN ( SELECT "gr"."id"
       FROM ("public"."grant_record" "gr"
         JOIN "public"."users" "u" ON (("gr"."user_id" = "u"."id")))
      WHERE ("u"."user_id" = "auth"."uid"())))
  );

ALTER POLICY "Users can update budget items for their grants" ON "public"."budget_items"
  USING (
    "public"."has_basic_membership"()
    AND (("tenant_id" = "public"."current_tenant_id"()) AND ("grant_id" IN ( SELECT "gr"."id"
       FROM ("public"."grant_record" "gr"
         JOIN "public"."users" "u" ON (("gr"."user_id" = "u"."id")))
      WHERE ("u"."user_id" = "auth"."uid"()))))
  );

-- receipts -------------------------------------------------------------------
ALTER POLICY "Users can insert their own receipts" ON "public"."receipts"
  WITH CHECK (
    "public"."has_basic_membership"()
    AND ("user_id" IN ( SELECT "users"."id"
       FROM "public"."users"
      WHERE ("users"."user_id" = "auth"."uid"())))
  );

-- grant_attachments ----------------------------------------------------------
ALTER POLICY "Users can upload attachments for their grants" ON "public"."grant_attachments"
  WITH CHECK (
    "public"."has_basic_membership"()
    AND ("grant_id" IN ( SELECT "gr"."id"
       FROM ("public"."grant_record" "gr"
         JOIN "public"."users" "u" ON (("gr"."user_id" = "u"."id")))
      WHERE ("u"."user_id" = "auth"."uid"())))
  );
