# GrantTrail — Master Task Checklist

> **Single place for everything still open** — active work plus the charity-directory
> review (the review can wait, but it lives here too). Detail docs: prod deploy →
> `docs/how_to/prod_setup.md` · owner meeting (access + DNS) → `OWNER-MEETING.md`.
>
> **Legend:** 🟢 agent end-to-end · 🟠 human action · 🔴 human decision

---

## 1. Prod cutover (active)

Prod Supabase project already exists (`danufmurtwqlmbiyfdih`); the current/working DB
is **staging**. Full steps: `prod_setup.md`.

> **First:** run through `OWNER-MEETING.md` with the account owner (access handoffs + DNS). Everything below is post-meeting.

- [ ] 🟠 Create the Resend API key; set `RESEND_API_KEY` (secret) + `EMAIL_FROM` (variable) in GitHub `production`; re-run **Deploy to Production**
- [ ] 🟠 End-to-end smoke test: one real purchase (live card, refund after) → paywall lifts **and** receipt email lands
- [ ] 🟠 After upgrading the prod Supabase instance, re-run the load test (`tests/load/k6-load-test.js`) at expected concurrency
- [ ] 🟢 Run security overview
---

> **Billing model redesign** (future, optional) → `docs/roadmap/billing-model-redesign.md`
