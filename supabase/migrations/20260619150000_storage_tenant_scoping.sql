-- ============================================================================
-- D5 — storage objects are tenant/role-blind (CRITICAL)
-- ============================================================================
-- The storage.objects policies for buckets `grant-documents` and `receipts`
-- only checked `auth.uid() IS NOT NULL` for upload / delete / own-read, so any
-- authenticated user of ANY tenant could read, overwrite, or delete another
-- org's files. The `grant_attachments` / `receipts` *table* rows are tenant
-- scoped, but the underlying objects were not.
--
-- Path convention enforced (derived from the upload code in frontend/src):
--   grant-documents :  attachments/<tenant_id>/<grant_id>/<file>
--                      (frontend/src/components/GrantAttachments.js)
--   receipts        :  receipts/<tenant_id>/<grant_id>/<expense_id>/<file>
--                      (frontend/src/components/AddExpenseModal.js)
--
--   In both buckets the SECOND path segment is the owning tenant_id. With
--   storage.foldername(name) returning a 1-based text[] of the folders, that is
--   element [2]. We scope every policy so a caller may only touch objects whose
--   path tenant segment equals their own current_tenant_id().
--
-- Role handling:
--   * admins keep own-tenant read via is_admin() (own-tenant only) — they could
--     already read all objects in the bucket, but is_admin() is tenant-scoped so
--     "all" was really "their tenant" intent; we keep that.
--   * super_admin is tenant-agnostic: granted read across buckets via
--     is_super_admin() (read-only; writes stay on the tenant path).
--   * everyone else (grantees) may read / insert / delete only within their own
--     tenant's path prefix.
-- ============================================================================

-- Helper: the tenant_id encoded in an object's path (2nd folder segment), as int.
-- Returns NULL when the path is malformed / too shallow, which fails the
-- equality check and denies access.
CREATE OR REPLACE FUNCTION "public"."storage_object_tenant_id"("p_name" "text")
    RETURNS integer
    LANGUAGE "plpgsql" IMMUTABLE
    SET "search_path" TO 'public'
    AS $$
DECLARE
  parts text[];
BEGIN
  parts := storage.foldername(p_name);
  IF array_length(parts, 1) IS NULL OR array_length(parts, 1) < 2 THEN
    RETURN NULL;
  END IF;
  RETURN parts[2]::integer;
EXCEPTION WHEN others THEN
  RETURN NULL;
END;
$$;

ALTER FUNCTION "public"."storage_object_tenant_id"("p_name" "text") OWNER TO "postgres";

-- ---------------------------------------------------------------------------
-- Replace the tenant/role-blind policies
-- ---------------------------------------------------------------------------

-- == grant-documents ========================================================
DROP POLICY IF EXISTS "Users can view their own grant documents"  ON "storage"."objects";
DROP POLICY IF EXISTS "Users can upload grant documents"          ON "storage"."objects";
DROP POLICY IF EXISTS "Users can delete their own grant documents" ON "storage"."objects";
DROP POLICY IF EXISTS "Admins can view all grant documents"        ON "storage"."objects";

CREATE POLICY "Tenant-scoped read of grant documents"
  ON "storage"."objects" FOR SELECT
  USING (
    "bucket_id" = 'grant-documents'::"text"
    AND (
      "public"."storage_object_tenant_id"("name") = "public"."current_tenant_id"()
      OR "public"."is_super_admin"()
    )
  );

CREATE POLICY "Tenant-scoped upload of grant documents"
  ON "storage"."objects" FOR INSERT
  WITH CHECK (
    "bucket_id" = 'grant-documents'::"text"
    AND "public"."storage_object_tenant_id"("name") = "public"."current_tenant_id"()
  );

CREATE POLICY "Tenant-scoped delete of grant documents"
  ON "storage"."objects" FOR DELETE
  USING (
    "bucket_id" = 'grant-documents'::"text"
    AND "public"."storage_object_tenant_id"("name") = "public"."current_tenant_id"()
  );

-- == receipts ===============================================================
DROP POLICY IF EXISTS "Users can view their own receipts"   ON "storage"."objects";
DROP POLICY IF EXISTS "Users can upload receipts"           ON "storage"."objects";
DROP POLICY IF EXISTS "Users can delete their own receipts" ON "storage"."objects";
DROP POLICY IF EXISTS "Admins can view all receipts in storage" ON "storage"."objects";

CREATE POLICY "Tenant-scoped read of receipts"
  ON "storage"."objects" FOR SELECT
  USING (
    "bucket_id" = 'receipts'::"text"
    AND (
      "public"."storage_object_tenant_id"("name") = "public"."current_tenant_id"()
      OR "public"."is_super_admin"()
    )
  );

CREATE POLICY "Tenant-scoped upload of receipts"
  ON "storage"."objects" FOR INSERT
  WITH CHECK (
    "bucket_id" = 'receipts'::"text"
    AND "public"."storage_object_tenant_id"("name") = "public"."current_tenant_id"()
  );

CREATE POLICY "Tenant-scoped delete of receipts"
  ON "storage"."objects" FOR DELETE
  USING (
    "bucket_id" = 'receipts'::"text"
    AND "public"."storage_object_tenant_id"("name") = "public"."current_tenant_id"()
  );
