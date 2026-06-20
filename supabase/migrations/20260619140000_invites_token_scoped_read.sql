-- ============================================================================
-- D7 — `invites` is world-readable (CRITICAL)
-- ============================================================================
-- The policy "Anyone can read invites by token" was `USING (true)` and the
-- `invites` table had SELECT granted to `anon`, so any unauthenticated caller
-- could enumerate EVERY invite row (tokens + emails) via the PostgREST API.
--
-- Fix:
--   * Drop the `USING (true)` anon-readable policy.
--   * Revoke the broad table privileges from `anon` (it no longer needs direct
--     table access at all — admins read via their own-tenant policy, signup
--     reads via the new RPC).
--   * Add a token-scoped SECURITY DEFINER function `get_invite_by_token(text)`
--     that returns ONLY the single matching invite's needed fields, executable
--     by `anon` (and `authenticated`, for the post-auth complete-profile step).
--   * Leave the admin own-tenant SELECT policy
--     ("Admins can view invites for their tenant") intact, and leave the
--     "System can update invites" policy intact (used to mark invites consumed).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Remove the world-readable path
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Anyone can read invites by token" ON "public"."invites";

-- anon must no longer be able to touch the table directly. (authenticated keeps
-- its grant: the admin own-tenant SELECT policy + the consume-update policy
-- still gate it at the row level.)
REVOKE ALL ON TABLE "public"."invites" FROM "anon";
REVOKE ALL ON SEQUENCE "public"."invites_id_seq" FROM "anon";

-- ---------------------------------------------------------------------------
-- 2. Token-scoped read RPC
-- ---------------------------------------------------------------------------
-- Returns exactly the fields the signup / complete-profile flow needs, for the
-- single invite matching the supplied token. SECURITY DEFINER so it bypasses
-- RLS, but it is hard-scoped to one token — no enumeration is possible.
CREATE OR REPLACE FUNCTION "public"."get_invite_by_token"("p_token" "text")
    RETURNS TABLE (
        "id"          integer,
        "tenant_id"   integer,
        "role"        character varying,
        "email"       character varying,
        "used_at"     timestamp with time zone,
        "expires_at"  timestamp with time zone,
        "tenant_name" "text"
    )
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT
    i.id,
    i.tenant_id,
    i.role,
    i.email,
    i.used_at,
    i.expires_at,
    t.name AS tenant_name
  FROM public.invites i
  JOIN public.tenants t ON t.id = i.tenant_id
  WHERE i.token = p_token::uuid
  LIMIT 1;
$$;

ALTER FUNCTION "public"."get_invite_by_token"("p_token" "text") OWNER TO "postgres";

-- Lock down EXECUTE: only anon (public signup) and authenticated (complete
-- profile, just after auth, before a user record exists) may call it.
REVOKE ALL ON FUNCTION "public"."get_invite_by_token"("p_token" "text") FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "public"."get_invite_by_token"("p_token" "text") TO "anon";
GRANT EXECUTE ON FUNCTION "public"."get_invite_by_token"("p_token" "text") TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."get_invite_by_token"("p_token" "text") TO "service_role";
