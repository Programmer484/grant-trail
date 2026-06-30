# Local Email Testing (Resend)

**You don't need this for most local dev** — the app works fully without email.

## Setup

1. Create a free account at [resend.com](https://resend.com).
2. Dashboard → API Keys → Create API Key (sending access is enough).
3. Add to `supabase/functions/.env`:
   ```dotenv
   RESEND_API_KEY=re_…
   EMAIL_FROM=onboarding@resend.dev
   ```
   `onboarding@resend.dev` is Resend's sandbox sender — no domain/DNS setup needed,
   but it only delivers to your own Resend account email. For a real `EMAIL_FROM`,
   verify a domain first (Dashboard → Domains → Add Domain, 3 DNS records).
4. Restart functions with the env file: `npx --prefix frontend supabase functions serve --env-file ./supabase/functions/.env`
5. Trigger an email from the app (submit a sponsorship inquiry, or complete a
   checkout) and check Resend Dashboard → Emails for the delivery record.

## How it works

```
edge function (notify-inquiry / stripe-webhook)
    │  HTTP POST (Bearer RESEND_API_KEY)
    ▼
_shared/email.ts  ──>  https://api.resend.com/emails  ──>  recipient inbox
```

`RESEND_API_KEY`/`EMAIL_FROM` are read from `supabase/functions/.env`. If either is
unset, `_shared/email.ts` silently skips the send (no crash, no error to the
caller) and logs `RESEND_API_KEY/EMAIL_FROM not all set — skipping email send.`
Auth emails (magic links, password resets) go through Supabase's own Inbucket, not
Resend.

## Common gotchas

| Symptom | Cause / fix |
|---------|-------------|
| Email silently skipped, no error | `RESEND_API_KEY` or `EMAIL_FROM` not set, or functions not restarted after editing `.env` |
| `422 Unprocessable Entity` from Resend | `EMAIL_FROM` domain not verified in Resend (sandbox sender bypasses this) |
| `401 Unauthorized` | `RESEND_API_KEY` invalid or expired — regenerate in the Resend dashboard |
| Auth emails (magic links) not working | Those go through Inbucket, not Resend — check `http://localhost:54324` |
