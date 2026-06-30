import { useCallback, useEffect, useState } from 'react';
import { getOwnGrant } from '../lib/data/grants';
import { listExpenses } from '../lib/data/expenses';
import { listBudgetItems } from '../lib/data/budgetItems';
import { listReceiptsByGrant } from '../lib/data/receipts';

// Load state for GrantBreakdown: the grantee's own grant plus its budget
// items, expenses, and a receipt lookup map. Exposes `reload` so the page
// can re-fetch after a budget item/expense add/edit/delete (modularity.md,
// Phase 3).
export function useGrantBreakdown(grantId, userId) {
  const [grant, setGrant] = useState(null);
  const [budgetItems, setBudgetItems] = useState([]);
  const [expenses, setExpenses] = useState([]);
  const [receiptMap, setReceiptMap] = useState({});
  const [error, setError] = useState('');

  const reload = useCallback(async () => {
    if (!userId) return;

    const { data: grantData, error: grantError } = await getOwnGrant(grantId, userId);
    if (grantError || !grantData) {
      setError('Grant not found.');
      return;
    }
    setGrant(grantData);

    const { data: biData } = await listBudgetItems(grantId);
    setBudgetItems(biData || []);

    const { data: expData } = await listExpenses(grantId);
    setExpenses(expData || []);

    const { data: recData } = await listReceiptsByGrant(grantId);
    const map = {};
    (recData || []).forEach(r => {
      if (r.receipt_files?.length > 0) map[r.expense_id] = r.receipt_files[0];
    });
    setReceiptMap(map);
  }, [grantId, userId]);

  useEffect(() => { reload(); }, [reload]);

  return { grant, budgetItems, expenses, receiptMap, error, reload };
}
