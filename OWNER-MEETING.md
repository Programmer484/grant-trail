# GrantTrail — Owner Meeting Checklist

> Everything that requires the Supabase / Vercel / GoDaddy account owner in the room.
> Work through this top-to-bottom in one sitting, then hand back to Ryan for the post-meeting steps.

---

## Before the meeting — Ryan does this alone

- [ ] Log in to [resend.com](https://resend.com) → **Domains** → **Add Domain** → enter `send.atkasolutions.org` → **Create**
- [ ] Leave the Resend record table open — you'll read values from it during the DNS step below

---

## In the meeting — needs account owner

### 1. Supabase — grant Ryan admin access

1. Log in to [supabase.com](https://supabase.com) → open project **`danufmurtwqlmbiyfdih`** (the prod "big" one)
2. **Settings → Team** → invite `ryanleo2006@gmail.com` as **Owner** (or at minimum **Admin**)
3. Ryan accepts the email invite — confirm he can open the project dashboard before moving on

### 2. Vercel — share the prod project

Choose one:
- **Option A (preferred):** Transfer the prod Vercel project to Ryan's account
- **Option B:** Add Ryan as a member with **Admin** role on the Vercel team/project

Either way, confirm Ryan can open the project in Vercel before moving on.

### 3. GoDaddy DNS — add Resend records for `send.atkasolutions.org`

1. Sign in to GoDaddy → **My Products** → **atkasolutions.org** → **DNS → DNS Records**
2. Add these four records (Ryan reads the exact values from the Resend page open in step 0):

> ⚠️ GoDaddy auto-appends `.atkasolutions.org` — enter only the part shown in the **Name/Host** column.

| # | Type | Name/Host (enter this)   | Value                              | Priority | TTL  |
|---|------|--------------------------|------------------------------------|----------|------|
| 1 | MX   | `send`                   | *(Resend's MX target)*             | 10       | 1 hr |
| 2 | TXT  | `send`                   | *(Resend's SPF record)*            | —        | 1 hr |
| 3 | TXT  | `resend._domainkey.send` | *(Resend's long DKIM key)*         | —        | 1 hr |
| 4 | TXT  | `_dmarc.send`            | *(Resend's suggested DMARC value)* | —        | 1 hr |

3. Save. DNS propagates in 15–60 min — Ryan will verify after the meeting.

---

## After the meeting — Ryan does these alone

- [ ] Resend → **Domains** → **Verify** — wait for all records to go green (check back after ~30 min)
- [ ] Create a Resend API key → push to GitHub Actions environments:
  ```bash
  gh secret set RESEND_API_KEY --env production --body "re_..."
  gh variable set EMAIL_FROM --env production --body "GrantTrail <receipts@send.atkasolutions.org>"

  gh secret set RESEND_API_KEY --env staging --body "re_..."
  gh variable set EMAIL_FROM --env staging --body "GrantTrail <receipts@send.atkasolutions.org>"
  ```
- [ ] GitHub Actions → **Deploy to Production** → **Run workflow**
- [ ] End-to-end smoke test: one real purchase with a live card → refund after → confirm paywall lifts **and** receipt email arrives (check Resend → Emails dashboard if it doesn't)
- [ ] Re-run load test against prod Supabase after upgrading the instance: `tests/load/k6-load-test.js`
- [ ] Run security overview (`🟢` item in TEST-CHECKLIST.md)
