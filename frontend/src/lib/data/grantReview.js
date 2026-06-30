// Data-access for the admin grant-review aux tables — grantee profile,
// status history, and comments (modularity.md, Phase 3).
import { supabase } from '../../supabaseClient';

// Narrow projection of the grantee's profile, just what the review page shows.
/** @param {string} userId */
export const getGrantee = (userId) =>
  supabase
    .from('users')
    .select('firstname, lastname, organization_name, email')
    .eq('id', userId)
    .single();

/** @param {number} grantId */
export const listGrantStatusHistory = (grantId) =>
  supabase
    .from('grant_status_history')
    .select('*')
    .eq('grant_id', grantId)
    .order('created_at', { ascending: true });

/** @param {number} grantId */
export const listGrantComments = (grantId) =>
  supabase
    .from('grant_comments')
    .select('*')
    .eq('grant_id', grantId)
    .order('created_at', { ascending: true });

/**
 * @param {number} grantId
 * @param {string} comment
 * @param {string} userId
 */
export const addGrantComment = (grantId, comment, userId) =>
  supabase.from('grant_comments').insert({ grant_id: grantId, comment, user_id: userId });
