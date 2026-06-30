// Data-access for the receipts table (modularity.md, Phase 3).
import { supabase } from '../../supabaseClient';

// Used to build an expense_id → first receipt file lookup map on the grant
// breakdown and admin review pages.
/** @param {number} grantId */
export const listReceiptsByGrant = (grantId) =>
  supabase.from('receipts').select('expense_id, receipt_files').eq('grant_id', grantId);
