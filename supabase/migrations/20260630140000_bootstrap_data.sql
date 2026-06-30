-- ==========================================
-- Bootstrap data (squashed 2026-06-30)
-- ==========================================
-- Combines bootstrap_initial_tenant + restore_platform_and_storage_data.
-- All inserts are idempotent (ON CONFLICT DO NOTHING).

-- Initial tenant
INSERT INTO tenants (name, slug, tenant_type)
VALUES ('The Family Advocates Canada', 'tfac', 'managed')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO tenant_settings (tenant_id)
VALUES ((SELECT id FROM tenants WHERE slug = 'tfac'))
ON CONFLICT (tenant_id) DO NOTHING;

-- Platform settings row (product IDs set per-environment, not here)
INSERT INTO platform_settings (id)
VALUES (1)
ON CONFLICT (id) DO NOTHING;

-- Storage buckets
INSERT INTO storage.buckets (id, name, public)
VALUES ('receipts', 'receipts', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('grant-documents', 'grant-documents', false)
ON CONFLICT (id) DO NOTHING;
