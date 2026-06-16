-- Composite index to speed up tenant-isolated grant sorting on dashboards
CREATE INDEX IF NOT EXISTS idx_grant_record_tenant_created 
ON public.grant_record(tenant_id, created_at DESC);

-- Composite index to speed up tenant-isolated expense listing sorted by date
CREATE INDEX IF NOT EXISTS idx_expenses_tenant_created 
ON public.expenses(tenant_id, created_at DESC);

-- Index on audit log creation date for clean filtering
CREATE INDEX IF NOT EXISTS idx_audit_log_created_at
ON public.audit_log(created_at DESC);
