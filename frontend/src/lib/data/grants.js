// Data-access for the grant_record table. Thin wrappers around the exact
// queries previously inlined in components (modularity.md, Phase 2). Each
// read returns Supabase's native { data, error } so call sites keep their own
// error handling unchanged.
import { supabase } from '../../supabaseClient';

export const getGrant = (id) =>
  supabase.from('grant_record').select('*').eq('id', id).single();

export const updateGrant = (id, updates) =>
  supabase.from('grant_record').update(updates).eq('id', id);
