import http from 'k6/http';
import { check, sleep } from 'k6';

// k6 Options: Simulate load up to 1000 concurrent virtual users (VUs)
export const options = {
  stages: [
    { duration: '30s', target: 100 },  // Ramp-up to 100 users
    { duration: '1m', target: 500 },   // Ramp-up to 500 users
    { duration: '2m', target: 1000 },  // Stay at 1000 users for 2 minutes
    { duration: '30s', target: 0 },    // Ramp-down to 0 users
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],    // Error rate must be less than 1%
    http_req_duration: ['p(95)<800'],  // 95% of requests must complete under 800ms
  },
};

// Target Config (Retrieve from environment or fallback)
const SUPABASE_URL = __ENV.SUPABASE_URL || 'https://stbkgkzuitsdpqyithfx.supabase.co';
const ANON_KEY = __ENV.SUPABASE_ANON_KEY || '';
const TEST_EMAIL = __ENV.TEST_USER_EMAIL || 'maria.smith@example.com';
const TEST_PASSWORD = __ENV.TEST_USER_PASSWORD || 'password123';

export function setup() {
  if (!ANON_KEY) {
    throw new Error('SUPABASE_ANON_KEY environment variable is required.');
  }

  const loginUrl = `${SUPABASE_URL}/auth/v1/token?grant_type=password`;
  const loginPayload = JSON.stringify({
    email: TEST_EMAIL,
    password: TEST_PASSWORD,
  });
  
  const loginParams = {
    headers: {
      'Content-Type': 'application/json',
      'apikey': ANON_KEY,
    },
  };

  const loginRes = http.post(loginUrl, loginPayload, loginParams);
  
  if (loginRes.status !== 200) {
    throw new Error(`Authentication failed: ${loginRes.body}`);
  }

  return loginRes.json().access_token;
}

export default function (token) {
  // 2. Fetch Grants (simulating authenticated RLS table query)
  const restParams = {
    headers: {
      'Authorization': `Bearer ${token}`,
      'apikey': ANON_KEY,
    },
  };

  const grantsRes = http.get(`${SUPABASE_URL}/rest/v1/grant_record?select=*`, restParams);
  check(grantsRes, {
    'fetch grants status is 200': (r) => r.status === 200,
  });

  // 3. Fetch Expenses
  const expensesRes = http.get(`${SUPABASE_URL}/rest/v1/expenses?select=*`, restParams);
  check(expensesRes, {
    'fetch expenses status is 200': (r) => r.status === 200,
  });

  // 4. Simulate user activity delay
  sleep(Math.random() * 2 + 1); // 1-3 seconds pause
}
