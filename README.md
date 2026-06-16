# GrantTrail

GrantTrail is a modern, multi-tenant web application designed for non-profits and public sector organizations to manage grant funding, budget allocations, expense reporting, and administrative review workflows. 

Built with **React** on the frontend and **Supabase** (Postgres, Auth, Storage, and Edge Functions) on the backend, the platform supports independent workspaces, automated workflows, and Stripe-based subscription billing.

---

## 🚀 Key Features

* **Multi-Tenant Isolation:** Supports independent workspaces (managed or self-service) with database-level tenant isolation using Postgres Row-Level Security (RLS).
* **Subscription & Billing:** Integrated with Stripe for tier-based subscription access (Basic and Premium) with auto-provisions and admin waivers.
* **Role-Based Workflows:** Distinct interfaces and permissions for Grantees (submit grants, log expenses, upload receipts), Tenant Admins (review grants, manage users, waive subscriptions), and Platform Super Admins (tenant management, defaults config).
* **Audit Logging:** Comprehensive, trigger-based change log that records inserts, updates, and deletes across key database tables.
* **In-App Realtime Notifications:** Live updates via Supabase Realtime when grants, budgets, or expenses change status.
* **Data Visualization:** Built-in charts (using Recharts) for grant spending, budget distribution, and overall funding tracking.
* **Export Options:** Supports exporting tables to CSV, and premium Excel exports for detailed financial reports.

---

## 📂 Repository Structure

```text
grant-trail/
├── frontend/                      # React SPA (Vite + Playwright + Vitest)
│   ├── src/                       # Components, hooks, and context
│   │   ├── components/            # UI components and pages
│   │   ├── hooks/                 # Custom state hooks
│   │   └── lib/                   # API, billing, and auth helpers
│   ├── package.json               # Dependencies and scripts (includes local Supabase CLI)
│   └── .env.example               # Pre-filled template for local development keys
│
├── supabase/                      # Edge Functions, Database Migrations, & Seeds
│   ├── migrations/                # Supabase database schema migrations (squashed schema)
│   ├── functions/                 # Stripe checkout, webhooks, billing portal
│   └── seed.sql                   # Seed data for local dev (users, tenants, and mock grants)
│
├── docs/                          # Walkthroughs and AI setup guides
└── package.json                   # Root-level command delegation wrappers
```

---

## 💻 Quick Start Guide

You can bootstrap the entire development environment (database + auth + frontend) in just three commands, starting from absolute zero.

### Prerequisites
Make sure you have **Node.js 18+**, **npm**, and **Docker** installed and running on your local machine.

### Setup Instructions
Run these commands from the repository root:

```bash
# 1. Install dependencies & configure local environment
npm run setup

# 2. Start the local database (Supabase Docker containers + migrations + seed data)
npm run db:start

# 3. Start the frontend React development server
npm run dev
```

*Note: The local setup runs completely offline, uses deterministic API keys pre-configured in `.env.example`, and automatically seeds test auth users. You do not need to register accounts manually.*

---

## 📖 Documentation Index

This repository contains comprehensive documentation to help developers and administrators navigate the system:

### Technical Documentation
* **[Developer Guide](file:///home/ryan/Documents/grant-trail/DEVELOPER.md):** In-depth local setup, project structure, routing patterns, Auth architecture, development coding patterns, and troubleshooting steps.
* **[System Architecture Spec](file:///home/ryan/Documents/grant-trail/ARCHITECTURE.md):** Architectural boundaries, tenant type comparisons (managed vs. self-service), and custom database trigger behaviors.
* **[Database Schema Reference](file:///home/ryan/Documents/grant-trail/DATABASE.md):** Data types, indices, constraints, RLS policies, and database triggers.
* **[Deployment Guide](file:///home/ryan/Documents/grant-trail/DEPLOYMENT.md):** Production Supabase configuration, environment variables setup, React builds compilation, and Apache server `.htaccess` routing instructions.
* **[ER Diagram (Mermaid)](file:///home/ryan/Documents/grant-trail/docs/ER-Diagram.md):** Graphic representation of entity relations and database associations.

### User Walkthroughs
Step-by-step UI guides containing screen-by-screen navigation and workflows:
* **Grantee Walkthrough:** [Markdown Guide](file:///home/ryan/Documents/grant-trail/docs/Grantee-Walkthrough.md) | [HTML Version](file:///home/ryan/Documents/grant-trail/docs/Grantee-Walkthrough.html)
* **Admin Walkthrough:** [Markdown Guide](file:///home/ryan/Documents/grant-trail/docs/Admin-Walkthrough.md) | [HTML Version](file:///home/ryan/Documents/grant-trail/docs/Admin-Walkthrough.html)
* **Super Admin Walkthrough:** [Markdown Guide](file:///home/ryan/Documents/grant-trail/docs/Super-Admin-Walkthrough.md) | [HTML Version](file:///home/ryan/Documents/grant-trail/docs/Super-Admin-Walkthrough.html)
