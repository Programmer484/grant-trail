-- ==========================================
-- Restore platform + storage bootstrap data
-- ==========================================
-- The original schema history created these data rows inside initial_schema.
-- The squashed baseline was generated from a schema dump (which excludes data),
-- so it dropped them. This forward-only migration restores them rather than
-- editing the already-applied baseline.
--
-- On production these rows already exist (created by the original history), so
-- every insert is an idempotent no-op there; it only adds the missing rows on a
-- fresh build (CI, a new environment). Keeping it as a new migration means the
-- migration history matches across environments — no already-applied file is
-- rewritten.

-- Single platform_settings row. Product IDs are intentionally NULL here and set
-- per-environment (super_admin / Stripe env vars); the seed sets them locally.
INSERT INTO platform_settings (id)
VALUES (1)
ON CONFLICT (id) DO NOTHING;

-- Storage buckets for receipt and grant-document uploads.
INSERT INTO storage.buckets (id, name, public)
VALUES ('receipts', 'receipts', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('grant-documents', 'grant-documents', false)
ON CONFLICT (id) DO NOTHING;
