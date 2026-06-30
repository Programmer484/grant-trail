-- ============================================================================
-- RLS perf nit: wrap helper-function calls in policy predicates with
-- (SELECT ...) so Postgres caches them as an InitPlan (one evaluation per
-- query) instead of re-evaluating the STABLE function once per row.
--
-- Followup from docs/architecture-review/FOLLOWUPS.md:
--   "Policies call helpers (current_tenant_id(), is_admin(), ...) directly
--    rather than wrapped as (SELECT ...) for initplan caching."
--
-- This is the same fix Supabase's own RLS performance advisor recommends for
-- auth.uid()-style calls: `tenant_id = current_tenant_id()` forces a per-row
-- function call in the planner; `tenant_id = (SELECT current_tenant_id())`
-- lets Postgres prove the subquery has no correlation to the outer row and
-- hoist it into an InitPlan computed once for the whole query.
--
-- Scope:
--   * Every CREATE POLICY in the squashed baseline (20260630130000) whose
--     USING/WITH CHECK calls public.current_tenant_id(), public.is_admin(),
--     public.is_super_admin(), public.has_basic_membership(), or
--     public.has_premium_membership() directly gets DROP POLICY + CREATE
--     POLICY here with those calls wrapped in (SELECT ...). Postgres has no
--     ALTER POLICY for changing a predicate, so drop+recreate is the only way.
--   * Also covers the storage.objects policies (grant-documents, receipts)
--     that call public.current_tenant_id() directly.
--
-- Deliberately left UNCHANGED (not a perf gap, see reasoning below):
--   * public.storage_object_tenant_id("name") calls are NOT wrapped — that
--     function takes the per-row "name" column as an argument, so it is
--     correlated to the outer row and Postgres cannot (and should not) hoist
--     it into an InitPlan; wrapping it would not change behavior but also
--     would not provide the caching benefit, so it is left as-is for clarity.
--   * Policies with NO direct call to the five helpers above (e.g. "Users can
--     view their own user record" — auth.uid() only; "Service role can
--     manage ..." — auth.role() only; policies that only reference these
--     helpers inside an already-uncorrelated `IN (SELECT ...)` subquery that
--     Postgres can already hoist on its own) are left untouched. Wrapping
--     auth.uid()/auth.role() is a separate, already-known Supabase pattern
--     not covered by this followup's wording ("helpers... current_tenant_id,
--     is_admin, ...") and is out of scope here to keep this a narrowly
--     targeted, easy-to-review perf change.
--
-- Every predicate below is byte-for-byte equivalent to the original modulo
-- the (SELECT ...) wrapping — no security semantics change. This is a pure
-- performance rewrite; do not read it as a policy review.
-- ============================================================================

DROP POLICY IF EXISTS "Admins can create invites for their tenant" ON "public"."invites";

CREATE POLICY "Admins can create invites for their tenant" ON "public"."invites" FOR INSERT WITH CHECK (((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ( SELECT "public"."is_admin"() )) OR ( SELECT "public"."is_super_admin"() )));


DROP POLICY IF EXISTS "Admins can delete all budget items in their tenant" ON "public"."budget_items";

CREATE POLICY "Admins can delete all budget items in their tenant" ON "public"."budget_items" FOR DELETE USING (((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ( SELECT "public"."is_admin"() )) OR ( SELECT "public"."is_super_admin"() )));


DROP POLICY IF EXISTS "Admins can delete all expenses in their tenant" ON "public"."expenses";

CREATE POLICY "Admins can delete all expenses in their tenant" ON "public"."expenses" FOR DELETE USING (((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ( SELECT "public"."is_admin"() )) OR ( SELECT "public"."is_super_admin"() )));


DROP POLICY IF EXISTS "Admins can insert comments in their tenant" ON "public"."grant_comments";

CREATE POLICY "Admins can insert comments in their tenant" ON "public"."grant_comments" FOR INSERT WITH CHECK (( SELECT "public"."is_admin"() ));


DROP POLICY IF EXISTS "Admins can manage memberships in their tenant" ON "public"."user_memberships";

CREATE POLICY "Admins can manage memberships in their tenant" ON "public"."user_memberships" USING ((( SELECT "public"."is_admin"() ) AND ("user_id" IN ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."tenant_id" = ( SELECT "public"."current_tenant_id"() )))))) WITH CHECK ((( SELECT "public"."is_admin"() ) AND ("user_id" IN ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."tenant_id" = ( SELECT "public"."current_tenant_id"() ))))));


DROP POLICY IF EXISTS "Admins can update all budget items in their tenant" ON "public"."budget_items";

CREATE POLICY "Admins can update all budget items in their tenant" ON "public"."budget_items" FOR UPDATE USING (((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ( SELECT "public"."is_admin"() )) OR ( SELECT "public"."is_super_admin"() )));


DROP POLICY IF EXISTS "Admins can update all expenses in their tenant" ON "public"."expenses";

CREATE POLICY "Admins can update all expenses in their tenant" ON "public"."expenses" FOR UPDATE USING (((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ( SELECT "public"."is_admin"() )) OR ( SELECT "public"."is_super_admin"() )));


DROP POLICY IF EXISTS "Admins can update all grants in their tenant" ON "public"."grant_record";

CREATE POLICY "Admins can update all grants in their tenant" ON "public"."grant_record" FOR UPDATE USING (((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ( SELECT "public"."is_admin"() )) OR ( SELECT "public"."is_super_admin"() )));


DROP POLICY IF EXISTS "Admins can update their tenant settings" ON "public"."tenant_settings";

CREATE POLICY "Admins can update their tenant settings" ON "public"."tenant_settings" FOR UPDATE USING (((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ( SELECT "public"."is_admin"() )) OR ( SELECT "public"."is_super_admin"() ))) WITH CHECK (((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ( SELECT "public"."is_admin"() )) OR ( SELECT "public"."is_super_admin"() )));


DROP POLICY IF EXISTS "Admins can update users in their tenant" ON "public"."users";

CREATE POLICY "Admins can update users in their tenant" ON "public"."users" FOR UPDATE USING (((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ( SELECT "public"."is_admin"() )) OR ( SELECT "public"."is_super_admin"() ))) WITH CHECK (((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ( SELECT "public"."is_admin"() )) OR ( SELECT "public"."is_super_admin"() )));


DROP POLICY IF EXISTS "Admins can view all audit logs in their tenant" ON "public"."audit_log";

CREATE POLICY "Admins can view all audit logs in their tenant" ON "public"."audit_log" FOR SELECT USING (((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ( SELECT "public"."is_admin"() )) OR ( SELECT "public"."is_super_admin"() )));


DROP POLICY IF EXISTS "Admins can view all budget items in their tenant" ON "public"."budget_items";

CREATE POLICY "Admins can view all budget items in their tenant" ON "public"."budget_items" FOR SELECT USING (((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ( SELECT "public"."is_admin"() )) OR ( SELECT "public"."is_super_admin"() )));


DROP POLICY IF EXISTS "Admins can view all expenses in their tenant" ON "public"."expenses";

CREATE POLICY "Admins can view all expenses in their tenant" ON "public"."expenses" FOR SELECT USING (((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ( SELECT "public"."is_admin"() )) OR ( SELECT "public"."is_super_admin"() )));


DROP POLICY IF EXISTS "Admins can view all grant attachments in their tenant" ON "public"."grant_attachments";

CREATE POLICY "Admins can view all grant attachments in their tenant" ON "public"."grant_attachments" FOR SELECT USING (((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ( SELECT "public"."is_admin"() )) OR ( SELECT "public"."is_super_admin"() )));


DROP POLICY IF EXISTS "Admins can view all grant status history in their tenant" ON "public"."grant_status_history";

CREATE POLICY "Admins can view all grant status history in their tenant" ON "public"."grant_status_history" FOR SELECT USING (((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ( SELECT "public"."is_admin"() )) OR ( SELECT "public"."is_super_admin"() )));


DROP POLICY IF EXISTS "Admins can view all grants in their tenant" ON "public"."grant_record";

CREATE POLICY "Admins can view all grants in their tenant" ON "public"."grant_record" FOR SELECT USING (((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ( SELECT "public"."is_admin"() )) OR ( SELECT "public"."is_super_admin"() )));


DROP POLICY IF EXISTS "Admins can view all receipts in their tenant" ON "public"."receipts";

CREATE POLICY "Admins can view all receipts in their tenant" ON "public"."receipts" FOR SELECT USING (((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ( SELECT "public"."is_admin"() )) OR ( SELECT "public"."is_super_admin"() )));


DROP POLICY IF EXISTS "Admins can view all users in their tenant" ON "public"."users";

CREATE POLICY "Admins can view all users in their tenant" ON "public"."users" FOR SELECT USING (((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ( SELECT "public"."is_admin"() )) OR ( SELECT "public"."is_super_admin"() )));


DROP POLICY IF EXISTS "Admins can view invites for their tenant" ON "public"."invites";

CREATE POLICY "Admins can view invites for their tenant" ON "public"."invites" FOR SELECT USING (((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ( SELECT "public"."is_admin"() )) OR ( SELECT "public"."is_super_admin"() )));


DROP POLICY IF EXISTS "Authenticated users can read their tenant settings" ON "public"."tenant_settings";

CREATE POLICY "Authenticated users can read their tenant settings" ON "public"."tenant_settings" FOR SELECT USING ((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) OR ( SELECT "public"."is_super_admin"() )));


DROP POLICY IF EXISTS "Owners can insert their listing" ON "public"."fiscal_agent_listings";

CREATE POLICY "Owners can insert their listing" ON "public"."fiscal_agent_listings" FOR INSERT WITH CHECK ((( SELECT "public"."has_premium_membership"() ) AND ("owner_user_id" IN ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."user_id" = "auth"."uid"()))) AND ("tenant_id" = ( SELECT "public"."current_tenant_id"() ))));


DROP POLICY IF EXISTS "Owners can triage their inquiries" ON "public"."sponsorship_inquiries";

CREATE POLICY "Owners can triage their inquiries" ON "public"."sponsorship_inquiries" FOR UPDATE USING ((( SELECT "public"."has_premium_membership"() ) AND ("listing_id" IN ( SELECT "l"."id"
   FROM ("public"."fiscal_agent_listings" "l"
     JOIN "public"."users" "u" ON (("l"."owner_user_id" = "u"."id")))
  WHERE ("u"."user_id" = "auth"."uid"()))))) WITH CHECK ((( SELECT "public"."has_premium_membership"() ) AND ("listing_id" IN ( SELECT "l"."id"
   FROM ("public"."fiscal_agent_listings" "l"
     JOIN "public"."users" "u" ON (("l"."owner_user_id" = "u"."id")))
  WHERE ("u"."user_id" = "auth"."uid"())))));


DROP POLICY IF EXISTS "Owners can update their listing" ON "public"."fiscal_agent_listings";

CREATE POLICY "Owners can update their listing" ON "public"."fiscal_agent_listings" FOR UPDATE USING ((( SELECT "public"."has_premium_membership"() ) AND ("owner_user_id" IN ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."user_id" = "auth"."uid"()))) AND ("tenant_id" = ( SELECT "public"."current_tenant_id"() )))) WITH CHECK ((( SELECT "public"."has_premium_membership"() ) AND ("owner_user_id" IN ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."user_id" = "auth"."uid"()))) AND ("tenant_id" = ( SELECT "public"."current_tenant_id"() ))));


DROP POLICY IF EXISTS "Owners can view their inquiries" ON "public"."sponsorship_inquiries";

CREATE POLICY "Owners can view their inquiries" ON "public"."sponsorship_inquiries" FOR SELECT USING ((("listing_id" IN ( SELECT "l"."id"
   FROM ("public"."fiscal_agent_listings" "l"
     JOIN "public"."users" "u" ON (("l"."owner_user_id" = "u"."id")))
  WHERE ("u"."user_id" = "auth"."uid"()))) OR ( SELECT "public"."is_super_admin"() )));


DROP POLICY IF EXISTS "Seekers can send inquiries" ON "public"."sponsorship_inquiries";

CREATE POLICY "Seekers can send inquiries" ON "public"."sponsorship_inquiries" FOR INSERT WITH CHECK ((( SELECT "public"."has_basic_membership"() ) AND ("listing_id" IN ( SELECT "l"."id"
   FROM "public"."fiscal_agent_listings" "l"
  WHERE ((("l"."status")::"text" = 'published'::"text") AND (("l"."verification")::"text" = 'verified'::"text")))) AND (("created_by" IS NULL) OR ("created_by" IN ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."user_id" = "auth"."uid"()))))));


DROP POLICY IF EXISTS "Super admins can insert tenant settings" ON "public"."tenant_settings";

CREATE POLICY "Super admins can insert tenant settings" ON "public"."tenant_settings" FOR INSERT WITH CHECK (( SELECT "public"."is_super_admin"() ));


DROP POLICY IF EXISTS "Super admins can manage tenants" ON "public"."tenants";

CREATE POLICY "Super admins can manage tenants" ON "public"."tenants" USING (( SELECT "public"."is_super_admin"() )) WITH CHECK (( SELECT "public"."is_super_admin"() ));


DROP POLICY IF EXISTS "Super admins can read all billing customers" ON "public"."billing_customers";

CREATE POLICY "Super admins can read all billing customers" ON "public"."billing_customers" FOR SELECT USING (( SELECT "public"."is_super_admin"() ));


DROP POLICY IF EXISTS "Super admins can read all grant comments" ON "public"."grant_comments";

CREATE POLICY "Super admins can read all grant comments" ON "public"."grant_comments" FOR SELECT USING (( SELECT "public"."is_super_admin"() ));


DROP POLICY IF EXISTS "Super admins can read all memberships" ON "public"."user_memberships";

CREATE POLICY "Super admins can read all memberships" ON "public"."user_memberships" FOR SELECT USING (( SELECT "public"."is_super_admin"() ));


DROP POLICY IF EXISTS "Super admins can read all notifications" ON "public"."notifications";

CREATE POLICY "Super admins can read all notifications" ON "public"."notifications" FOR SELECT USING (( SELECT "public"."is_super_admin"() ));


DROP POLICY IF EXISTS "Super admins can read all subscriptions" ON "public"."subscriptions";

CREATE POLICY "Super admins can read all subscriptions" ON "public"."subscriptions" FOR SELECT USING (( SELECT "public"."is_super_admin"() ));


DROP POLICY IF EXISTS "Super admins can update any listing" ON "public"."fiscal_agent_listings";

CREATE POLICY "Super admins can update any listing" ON "public"."fiscal_agent_listings" FOR UPDATE USING (( SELECT "public"."is_super_admin"() )) WITH CHECK (( SELECT "public"."is_super_admin"() ));


DROP POLICY IF EXISTS "Super admins can update platform settings" ON "public"."platform_settings";

CREATE POLICY "Super admins can update platform settings" ON "public"."platform_settings" FOR UPDATE USING (( SELECT "public"."is_super_admin"() )) WITH CHECK (( SELECT "public"."is_super_admin"() ));


DROP POLICY IF EXISTS "Super admins can view system logs" ON "public"."system_logs";

CREATE POLICY "Super admins can view system logs" ON "public"."system_logs" FOR SELECT USING (( SELECT "public"."is_super_admin"() ));


DROP POLICY IF EXISTS "Users can delete attachments for their grants" ON "public"."grant_attachments";

CREATE POLICY "Users can delete attachments for their grants" ON "public"."grant_attachments" FOR DELETE USING ((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ("grant_id" IN ( SELECT "gr"."id"
   FROM ("public"."grant_record" "gr"
     JOIN "public"."users" "u" ON (("gr"."user_id" = "u"."id")))
  WHERE ("u"."user_id" = "auth"."uid"())))));


DROP POLICY IF EXISTS "Users can delete budget items for their grants" ON "public"."budget_items";

CREATE POLICY "Users can delete budget items for their grants" ON "public"."budget_items" FOR DELETE USING ((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ("grant_id" IN ( SELECT "gr"."id"
   FROM ("public"."grant_record" "gr"
     JOIN "public"."users" "u" ON (("gr"."user_id" = "u"."id")))
  WHERE ("u"."user_id" = "auth"."uid"())))));


DROP POLICY IF EXISTS "Users can delete expenses for their grants" ON "public"."expenses";

CREATE POLICY "Users can delete expenses for their grants" ON "public"."expenses" FOR DELETE USING ((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ("grant_id" IN ( SELECT "gr"."id"
   FROM ("public"."grant_record" "gr"
     JOIN "public"."users" "u" ON (("gr"."user_id" = "u"."id")))
  WHERE ("u"."user_id" = "auth"."uid"())))));


DROP POLICY IF EXISTS "Users can delete their own notifications" ON "public"."notifications";

CREATE POLICY "Users can delete their own notifications" ON "public"."notifications" FOR DELETE USING ((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ("user_id" = ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."user_id" = "auth"."uid"())))));


DROP POLICY IF EXISTS "Users can insert budget items for their grants" ON "public"."budget_items";

CREATE POLICY "Users can insert budget items for their grants" ON "public"."budget_items" FOR INSERT WITH CHECK ((( SELECT "public"."has_basic_membership"() ) AND ("grant_id" IN ( SELECT "gr"."id"
   FROM ("public"."grant_record" "gr"
     JOIN "public"."users" "u" ON (("gr"."user_id" = "u"."id")))
  WHERE ("u"."user_id" = "auth"."uid"())))));


DROP POLICY IF EXISTS "Users can insert expenses for their grants" ON "public"."expenses";

CREATE POLICY "Users can insert expenses for their grants" ON "public"."expenses" FOR INSERT WITH CHECK ((( SELECT "public"."has_basic_membership"() ) AND ("grant_id" IN ( SELECT "gr"."id"
   FROM ("public"."grant_record" "gr"
     JOIN "public"."users" "u" ON (("gr"."user_id" = "u"."id")))
  WHERE ("u"."user_id" = "auth"."uid"())))));


DROP POLICY IF EXISTS "Users can insert their own grants" ON "public"."grant_record";

CREATE POLICY "Users can insert their own grants" ON "public"."grant_record" FOR INSERT WITH CHECK ((( SELECT "public"."has_basic_membership"() ) AND ("user_id" IN ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."user_id" = "auth"."uid"())))));


DROP POLICY IF EXISTS "Users can insert their own receipts" ON "public"."receipts";

CREATE POLICY "Users can insert their own receipts" ON "public"."receipts" FOR INSERT WITH CHECK ((( SELECT "public"."has_basic_membership"() ) AND ("user_id" IN ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."user_id" = "auth"."uid"())))));


DROP POLICY IF EXISTS "Users can update budget items for their grants" ON "public"."budget_items";

CREATE POLICY "Users can update budget items for their grants" ON "public"."budget_items" FOR UPDATE USING ((( SELECT "public"."has_basic_membership"() ) AND (("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ("grant_id" IN ( SELECT "gr"."id"
   FROM ("public"."grant_record" "gr"
     JOIN "public"."users" "u" ON (("gr"."user_id" = "u"."id")))
  WHERE ("u"."user_id" = "auth"."uid"()))))));


DROP POLICY IF EXISTS "Users can update expenses for their grants" ON "public"."expenses";

CREATE POLICY "Users can update expenses for their grants" ON "public"."expenses" FOR UPDATE USING ((( SELECT "public"."has_basic_membership"() ) AND (("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ("grant_id" IN ( SELECT "gr"."id"
   FROM ("public"."grant_record" "gr"
     JOIN "public"."users" "u" ON (("gr"."user_id" = "u"."id")))
  WHERE ("u"."user_id" = "auth"."uid"()))))));


DROP POLICY IF EXISTS "Users can update their own grants" ON "public"."grant_record";

CREATE POLICY "Users can update their own grants" ON "public"."grant_record" FOR UPDATE USING ((( SELECT "public"."has_basic_membership"() ) AND (("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ("user_id" IN ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."user_id" = "auth"."uid"()))))));


DROP POLICY IF EXISTS "Users can update their own notifications" ON "public"."notifications";

CREATE POLICY "Users can update their own notifications" ON "public"."notifications" FOR UPDATE USING ((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ("user_id" = ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."user_id" = "auth"."uid"()))))) WITH CHECK ((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ("user_id" = ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."user_id" = "auth"."uid"())))));


DROP POLICY IF EXISTS "Users can upload attachments for their grants" ON "public"."grant_attachments";

CREATE POLICY "Users can upload attachments for their grants" ON "public"."grant_attachments" FOR INSERT WITH CHECK ((( SELECT "public"."has_basic_membership"() ) AND ("grant_id" IN ( SELECT "gr"."id"
   FROM ("public"."grant_record" "gr"
     JOIN "public"."users" "u" ON (("gr"."user_id" = "u"."id")))
  WHERE ("u"."user_id" = "auth"."uid"())))));


DROP POLICY IF EXISTS "Users can view attachments for their grants" ON "public"."grant_attachments";

CREATE POLICY "Users can view attachments for their grants" ON "public"."grant_attachments" FOR SELECT USING ((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ("grant_id" IN ( SELECT "gr"."id"
   FROM ("public"."grant_record" "gr"
     JOIN "public"."users" "u" ON (("gr"."user_id" = "u"."id")))
  WHERE ("u"."user_id" = "auth"."uid"())))));


DROP POLICY IF EXISTS "Users can view audit logs for their own records" ON "public"."audit_log";

CREATE POLICY "Users can view audit logs for their own records" ON "public"."audit_log" FOR SELECT USING ((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ("changed_by" = "auth"."uid"())));


DROP POLICY IF EXISTS "Users can view budget items for their grants" ON "public"."budget_items";

CREATE POLICY "Users can view budget items for their grants" ON "public"."budget_items" FOR SELECT USING ((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ("grant_id" IN ( SELECT "gr"."id"
   FROM ("public"."grant_record" "gr"
     JOIN "public"."users" "u" ON (("gr"."user_id" = "u"."id")))
  WHERE ("u"."user_id" = "auth"."uid"())))));


DROP POLICY IF EXISTS "Users can view comments on their grants" ON "public"."grant_comments";

CREATE POLICY "Users can view comments on their grants" ON "public"."grant_comments" FOR SELECT USING ((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND (("grant_id" IN ( SELECT "gr"."id"
   FROM ("public"."grant_record" "gr"
     JOIN "public"."users" "u" ON (("gr"."user_id" = "u"."id")))
  WHERE ("u"."user_id" = "auth"."uid"()))) OR ( SELECT "public"."is_admin"() ))));


DROP POLICY IF EXISTS "Users can view expenses for their grants" ON "public"."expenses";

CREATE POLICY "Users can view expenses for their grants" ON "public"."expenses" FOR SELECT USING ((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ("grant_id" IN ( SELECT "gr"."id"
   FROM ("public"."grant_record" "gr"
     JOIN "public"."users" "u" ON (("gr"."user_id" = "u"."id")))
  WHERE ("u"."user_id" = "auth"."uid"())))));


DROP POLICY IF EXISTS "Users can view status history for their grants" ON "public"."grant_status_history";

CREATE POLICY "Users can view status history for their grants" ON "public"."grant_status_history" FOR SELECT USING ((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ("grant_id" IN ( SELECT "gr"."id"
   FROM ("public"."grant_record" "gr"
     JOIN "public"."users" "u" ON (("gr"."user_id" = "u"."id")))
  WHERE ("u"."user_id" = "auth"."uid"())))));


DROP POLICY IF EXISTS "Users can view their own grants" ON "public"."grant_record";

CREATE POLICY "Users can view their own grants" ON "public"."grant_record" FOR SELECT USING ((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ("user_id" IN ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."user_id" = "auth"."uid"())))));


DROP POLICY IF EXISTS "Users can view their own notifications" ON "public"."notifications";

CREATE POLICY "Users can view their own notifications" ON "public"."notifications" FOR SELECT USING ((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND (("user_id" = ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."user_id" = "auth"."uid"()))) OR ( SELECT "public"."is_admin"() ))));


DROP POLICY IF EXISTS "Users can view their own receipts" ON "public"."receipts";

CREATE POLICY "Users can view their own receipts" ON "public"."receipts" FOR SELECT USING ((("tenant_id" = ( SELECT "public"."current_tenant_id"() )) AND ("user_id" IN ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."user_id" = "auth"."uid"())))));


DROP POLICY IF EXISTS "Users can view their own tenant" ON "public"."tenants";

CREATE POLICY "Users can view their own tenant" ON "public"."tenants" FOR SELECT USING ((("id" = ( SELECT "public"."current_tenant_id"() )) OR ( SELECT "public"."is_super_admin"() )));


DROP POLICY IF EXISTS "View full listings with basic access" ON "public"."fiscal_agent_listings";

CREATE POLICY "View full listings with basic access" ON "public"."fiscal_agent_listings" FOR SELECT USING ((("owner_user_id" IN ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."user_id" = "auth"."uid"()))) OR ( SELECT "public"."has_basic_membership"() ) OR ( SELECT "public"."is_super_admin"() )));

-- ----------------------------------------------------------------------------
-- storage.objects policies (grant-documents, receipts buckets)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Tenant-scoped read of grant documents" ON "storage"."objects";

CREATE POLICY "Tenant-scoped read of grant documents"
  ON "storage"."objects" FOR SELECT
  USING ("bucket_id" = 'grant-documents'::"text"
    AND ("public"."storage_object_tenant_id"("name") = ( SELECT "public"."current_tenant_id"() ) OR ( SELECT "public"."is_super_admin"() )));


DROP POLICY IF EXISTS "Tenant-scoped upload of grant documents" ON "storage"."objects";

CREATE POLICY "Tenant-scoped upload of grant documents"
  ON "storage"."objects" FOR INSERT
  WITH CHECK ("bucket_id" = 'grant-documents'::"text"
    AND "public"."storage_object_tenant_id"("name") = ( SELECT "public"."current_tenant_id"() ));


DROP POLICY IF EXISTS "Tenant-scoped delete of grant documents" ON "storage"."objects";

CREATE POLICY "Tenant-scoped delete of grant documents"
  ON "storage"."objects" FOR DELETE
  USING ("bucket_id" = 'grant-documents'::"text"
    AND "public"."storage_object_tenant_id"("name") = ( SELECT "public"."current_tenant_id"() ));


DROP POLICY IF EXISTS "Tenant-scoped read of receipts" ON "storage"."objects";

CREATE POLICY "Tenant-scoped read of receipts"
  ON "storage"."objects" FOR SELECT
  USING ("bucket_id" = 'receipts'::"text"
    AND ("public"."storage_object_tenant_id"("name") = ( SELECT "public"."current_tenant_id"() ) OR ( SELECT "public"."is_super_admin"() )));


DROP POLICY IF EXISTS "Tenant-scoped upload of receipts" ON "storage"."objects";

CREATE POLICY "Tenant-scoped upload of receipts"
  ON "storage"."objects" FOR INSERT
  WITH CHECK ("bucket_id" = 'receipts'::"text"
    AND "public"."storage_object_tenant_id"("name") = ( SELECT "public"."current_tenant_id"() ));


DROP POLICY IF EXISTS "Tenant-scoped delete of receipts" ON "storage"."objects";

CREATE POLICY "Tenant-scoped delete of receipts"
  ON "storage"."objects" FOR DELETE
  USING ("bucket_id" = 'receipts'::"text"
    AND "public"."storage_object_tenant_id"("name") = ( SELECT "public"."current_tenant_id"() ));
