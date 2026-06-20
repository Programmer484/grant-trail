import { supabase } from '../supabaseClient';

// Fetch a single invite by its token via the `get_invite_by_token` RPC.
//
// The `invites` table is no longer directly readable by `anon` (D7 security
// fix): a token-scoped SECURITY DEFINER function returns ONLY the matching
// invite, so unauthenticated callers can't enumerate every invite/token/email.
//
// Returns the invite shaped like the old `select('*, tenants(name)')` result
// (so callers keep using `invite.tenants?.name`), or null if not found.
// On error, returns { data: null, error }.
export async function getInviteByToken(token) {
  if (!token) return { data: null, error: null };

  const { data, error } = await supabase.rpc('get_invite_by_token', {
    p_token: token,
  });

  if (error) return { data: null, error };

  const row = Array.isArray(data) ? data[0] : data;
  if (!row) return { data: null, error: null };

  const { tenant_name, ...rest } = row;
  return {
    data: { ...rest, tenants: tenant_name ? { name: tenant_name } : null },
    error: null,
  };
}
