# GrantTrail: Scalability & Backend Optimization Playbook

This guide covers the necessary steps to ensure the GrantTrail backend can handle high-concurrency traffic (1,000+ simultaneous users) and explains how to deploy the Edge Functions, audit database performance, enable connection pooling, and run load tests.

---

## 1. Deploying Supabase Edge Functions
Since the backend uses Supabase Edge Functions for Stripe integration and subscription syncing, they must be deployed to your remote Supabase project.

### Step 1: Set Stripe Secrets on Remote Supabase
Before deploying, set the required environment variables in your remote Supabase instance:
```bash
./bin/supabase secrets set --project-ref stbkgkzuitsdpqyithfx \
  STRIPE_SECRET_KEY="your_stripe_secret_key" \
  STRIPE_WEBHOOK_SIGNING_SECRET="your_stripe_webhook_signing_secret" \
  FRONTEND_URL="https://your-frontend-domain.vercel.app"
```

### Step 2: Deploy the Edge Functions
Deploy all local functions found in `supabase/functions/` to the remote project:
```bash
./bin/supabase functions deploy --project-ref stbkgkzuitsdpqyithfx
```
*Note: Individual functions can be updated using:*
```bash
./bin/supabase functions deploy --project-ref stbkgkzuitsdpqyithfx sync-my-subscription
```

---

## 2. Database Index Audit & Optimization
To support 1,000+ concurrent queries without performance degradation, the database must minimize disk scans. 

### Existing Index Status
The initial schema already implements critical indexes on all foreign keys and tenant isolation columns:
* `users(tenant_id, email, user_id)`
* `grant_record(tenant_id, user_id, status)`
* `expenses(tenant_id, grant_id, budget_item_id)`
* `audit_log(tenant_id, table_name, record_id)`

### Recommended Composite Indexes for High Load
For dashboard sorting and timeline feeds, execute the following SQL in the Supabase Dashboard SQL Editor to prevent slow sort operations:

```sql
-- Speed up grant timeline and dashboard sorting by date per tenant
CREATE INDEX IF NOT EXISTS idx_grant_record_tenant_created 
ON grant_record(tenant_id, created_at DESC);

-- Speed up expense report queries ordered by date per tenant
CREATE INDEX IF NOT EXISTS idx_expenses_tenant_created 
ON expenses(tenant_id, created_at DESC);

-- Speed up audit log searches by table and timestamp
CREATE INDEX IF NOT EXISTS idx_audit_log_table_created 
ON audit_log(table_name, created_at DESC);
```

---

## 3. Enable Supabase Connection Pooling (Supavisor)
Direct PostgreSQL connections will exhaust database limits under high user load. Supabase uses **Supavisor** for connection pooling.

1. Go to your **Supabase Dashboard** -> **Settings** -> **Database**.
2. Scroll to the **Connection Pooling** section.
3. Copy the **Pooler connection string** (port `6543`, host: `*.pooler.supabase.com`).
4. **Choose the Mode**:
   * **Transaction Mode (Default, Recommended)**: Multiple concurrent frontend requests share a pool of server connections. Required for serverless APIs and scaling to 10,000+ connections.
   * **Session Mode**: Holds a physical connection for each active client session (not recommended for serverless/high load).

> [!NOTE]
> Update your server environment variables to point to the Pooler host (port `6543`) rather than the direct database port (`5432`) for production workloads.

---

## 4. Run Load Tests Using k6
A load test script is created at [k6-load-test.js](file:///home/nati/granttrail/backend/k6-load-test.js). It simulates users logging in, fetching grants, and querying expenses.

### Step 1: Install k6
On Linux (Debian/Ubuntu/Kali):
```bash
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD194E8CE9D355
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt update
sudo apt install k6
```

### Step 2: Seed a Load Test Account
Ensure the test user exists in your remote authentication list (`maria.smith@example.com` or create a dummy account).

### Step 3: Run the Load Test
Execute the test from the root of your project, passing your Supabase keys as environment variables:
```bash
SUPABASE_ANON_KEY="your_anon_key" \
TEST_USER_EMAIL="maria.smith@example.com" \
TEST_USER_PASSWORD="password123" \
k6 run backend/k6-load-test.js
```

---

## 5. Profiling Slow Queries in Supabase
During the load test, monitor how the database performs under pressure:

1. Go to the **Supabase Dashboard** -> **Database** (left sidebar).
2. Click **Query Performance** (or **Query Analysis**).
3. Sort queries by **Total Execution Time** or **Average Execution Time**.
4. Identify any query that takes longer than `50ms`.
5. Run `EXPLAIN ANALYZE <your_query>` in the SQL Editor to see if it is performing sequential scans (indicates missing index) or index scans.
