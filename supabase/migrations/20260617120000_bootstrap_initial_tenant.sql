-- ==========================================
-- Bootstrap the initial tenant (structural only)
-- ==========================================
-- Seeds the minimum tenant structure the app needs so the first user has an
-- organization to belong to. Previously this lived in scripts/deploy_db.js; it
-- now runs via the Supabase GitHub integration on merge to production, because
-- seed files are NOT merged to production by the integration.
--
-- Idempotent: ON CONFLICT DO NOTHING means re-running is a no-op. No user/admin
-- accounts are created here — admins are still promoted via the signup UI +
-- `npm run admin:promote <email>` flow.

-- Create initial tenant
INSERT INTO tenants (name, slug, tenant_type)
VALUES ('The Family Advocates Canada', 'tfac', 'managed')
ON CONFLICT (slug) DO NOTHING;

-- Create its settings row
INSERT INTO tenant_settings (tenant_id)
VALUES ((SELECT id FROM tenants WHERE slug = 'tfac'))
ON CONFLICT (tenant_id) DO NOTHING;
