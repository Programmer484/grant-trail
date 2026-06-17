-- No-op migration: end-to-end test of the Supabase GitHub integration.
-- Does nothing to the schema; its only purpose is to confirm that merging to
-- main causes the integration to apply a new migration. Verify by checking that
-- this version (20260617130000) appears in the dashboard's migration history
-- (supabase_migrations.schema_migrations). Safe to leave in place or remove.
SELECT 1;
