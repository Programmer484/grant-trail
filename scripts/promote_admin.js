const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

const askQuestion = (query) => new Promise((resolve) => rl.question(query, resolve));

async function main() {
  console.log('====================================================');
  console.log('🛡️ GrantTrail Super Admin Promotion Tool');
  console.log('====================================================\n');

  try {
    let email = process.argv[2];
    if (!email) {
      email = await askQuestion('Enter the email address of the user to promote: ');
    }
    email = email.trim().toLowerCase();

    if (!email) {
      throw new Error('Email address cannot be empty.');
    }

    const tempDir = path.join(__dirname, '..', 'supabase', '.temp');
    if (!fs.existsSync(tempDir)) {
      fs.mkdirSync(tempDir, { recursive: true });
    }

    console.log(`\n🔍 Checking if user profile exists for "${email}" on the linked Supabase database...`);

    // We run queries from a temp file (-f) rather than passing SQL as an inline
    // arg: combining `shell: true` with an args array word-splits the unquoted
    // SQL, so the CLI never receives the real query.
    const escapedEmail = email.replace(/'/g, "''");
    const checkSqlPath = path.join(tempDir, 'promote_admin_check.sql');
    fs.writeFileSync(
      checkSqlPath,
      `SELECT id, role, tenant_id FROM users WHERE email = '${escapedEmail}';`
    );

    const checkResult = spawnSync('npx', [
      '--prefix', 'frontend', 'supabase', 'db', 'query', '--linked', '-o', 'json', '-f', checkSqlPath
    ]);

    try {
      if (fs.existsSync(checkSqlPath)) fs.unlinkSync(checkSqlPath);
    } catch (e) {
      // Ignore cleanup error
    }

    if (checkResult.status !== 0) {
      throw new Error(`Failed to query database: ${checkResult.stderr?.toString() || 'unknown error'}`);
    }

    let rows = [];
    try {
      const output = checkResult.stdout.toString().trim();
      // The CLI wraps JSON results in an envelope ({ boundary, rows, warning })
      // and may print log lines first. Parse the object spanning the first '{'
      // to the last '}', then read its `rows`.
      const jsonStart = output.indexOf('{');
      const jsonEnd = output.lastIndexOf('}');
      if (jsonStart !== -1 && jsonEnd > jsonStart) {
        const parsed = JSON.parse(output.substring(jsonStart, jsonEnd + 1));
        rows = parsed.rows || [];
      } else {
        throw new Error('No JSON output returned.');
      }
    } catch (e) {
      throw new Error(`Failed to parse query result: ${e.message}\nRaw CLI output: ${checkResult.stdout.toString()}`);
    }

    if (rows.length === 0 || !rows[0].id) {
      throw new Error(`No user profile found for email "${email}" on the linked Supabase database.\n` +
                      'Please ensure the user has completed their registration in the application browser signup first.');
    }

    const user = rows[0];
    console.log(`✅ Found user record (ID: ${user.id}, Current Role: ${user.role}).`);

    console.log(`\n⬆️ Promoting "${email}" to Super Admin on the linked Supabase database...`);

    // Join against tenants so we never write a NULL tenant_id if 'tfac' is
    // missing: no matching tenant row means the UPDATE simply affects 0 rows.
    const promoteSql = `
UPDATE users u
SET role = 'super_admin',
    tenant_id = t.id
FROM tenants t
WHERE t.slug = 'tfac'
  AND u.email = '${escapedEmail}';
`;

    const tempSqlPath = path.join(tempDir, 'promote_admin_temp.sql');
    fs.writeFileSync(tempSqlPath, promoteSql);

    const promoteExec = spawnSync('npx', [
      '--prefix', 'frontend', 'supabase', 'db', 'query', '--linked', '-f', tempSqlPath
    ], {
      stdio: 'inherit'
    });

    // Clean up temporary script
    try {
      if (fs.existsSync(tempSqlPath)) fs.unlinkSync(tempSqlPath);
    } catch (e) {
      // Ignore cleanup error
    }

    if (promoteExec.status !== 0) {
      throw new Error('Failed to execute promotion SQL on the linked Supabase database.');
    }

    console.log('\n====================================================');
    console.log('🎉 PROMOTION SUCCESSFUL!');
    console.log('====================================================');
    console.log(`User "${email}" has been elevated to Super Admin.`);
    console.log('They can now log in and access the platform control panel.');
    console.log('====================================================\n');

  } catch (err) {
    console.error(`\n❌ Error: ${err.message}`);
  } finally {
    rl.close();
  }
}

main();
