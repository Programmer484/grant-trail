-- ==========================================
-- F7: throttle notify-inquiry (see docs/architecture-review/FOLLOWUPS.md)
-- ==========================================
-- notify-inquiry is JWT-gated but had no rate limit: an authenticated caller
-- could replay the same inquiryId to spam a charity's inbox with duplicate
-- notification emails. Cap it at one notification per inquiry by recording
-- when the notification was sent and having the function skip already-
-- notified rows. No new RLS needed: sponsorship_inquiries already has a
-- "Service role can manage inquiries" policy covering this column, and the
-- edge function writes via the service role.

ALTER TABLE "public"."sponsorship_inquiries"
  ADD COLUMN IF NOT EXISTS "notified_at" timestamp with time zone;
