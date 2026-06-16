import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'http://127.0.0.1:54321';
const supabaseKey = 'sb_secret_LOCAL_DEV_KEY'; // service_role key
const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: { autoRefreshToken: false, persistSession: false }
});

const emails = [
  'maria.smith@example.com',
  'jacob.soto@example.com',
  'faizan.sharp@example.com',
  'eric.hobbs@example.com',
  'sam.reeves@example.com',
  'alex.tan@example.com',
  'priya.sharma@example.com',
  'david.chen@example.com',
  'amara.okafor@example.com',
  'carlos.lopez@example.com',
  'nadia.park@example.com'
];

async function seedAuth() {
  console.log('Creating auth users...');
  for (const email of emails) {
    const { data, error } = await supabase.auth.admin.createUser({
      email,
      password: 'password123',
      email_confirm: true
    });
    if (error && !error.message.includes('already exists')) {
      console.error(`Error creating ${email}:`, error.message);
    } else {
      console.log(`User created/exists: ${email}`);
    }
  }
}

seedAuth();
