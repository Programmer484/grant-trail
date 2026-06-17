const { spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const readline = require('readline');

const DEPLOY_DIR = path.join(__dirname, '..', '.deploy');
const SUPABASE_FILE = path.join(DEPLOY_DIR, 'supabase.env');
const VERCEL_FILE = path.join(DEPLOY_DIR, 'vercel.env');

// Required keys per file. Used both to validate the scratch files before we
// touch any platform, and to push only the intended keys to each destination.
const REQUIRED = {
  [SUPABASE_FILE]: ['STRIPE_SECRET_KEY', 'STRIPE_PRICE_BASIC', 'STRIPE_PRICE_PRO', 'STRIPE_WEBHOOK_SECRET', 'APP_URL'],
  [VERCEL_FILE]: ['VITE_SUPABASE_URL', 'VITE_SUPABASE_KEY'],
};

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
const askQuestion = (query) => new Promise((resolve) => rl.question(query, resolve));

// Minimal .env parser: KEY=VALUE per line, skips blanks/comments, strips a
// trailing " # comment" on unquoted values and surrounding quotes on quoted ones.
function parseEnvFile(file) {
  if (!fs.existsSync(file)) {
    throw new Error(`Missing ${path.relative(process.cwd(), file)} — work through Step 2 of the deployment guide first.`);
  }
  const map = {};
  for (let line of fs.readFileSync(file, 'utf8').split('\n')) {
    line = line.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();
    let val = line.slice(eq + 1).trim();
    if (/^["']/.test(val)) {
      const quote = val[0];
      const end = val.indexOf(quote, 1);
      val = end !== -1 ? val.slice(1, end) : val.slice(1);
    } else {
      val = val.replace(/\s+#.*$/, '').trim();
    }
    map[key] = val;
  }
  return map;
}

function validate(file, map) {
  const missing = REQUIRED[file].filter((k) => !map[k]);
  if (missing.length) {
    throw new Error(
      `${path.basename(file)} is missing values for: ${missing.join(', ')}.\n` +
      'Did you fill in the webhook secret (Step 4) and APP_URL (Step 5)?'
    );
  }
}

const run = (cmd, args, opts = {}) => spawnSync(cmd, args, { shell: true, ...opts });

// Both pushes need a logged-in CLI. Probe each up front so we fail with a clear
// instruction instead of a cryptic error halfway through pushing.
function preflightAuth() {
  console.log('🔑 Checking CLI authentication...');
  const sb = run('npx', ['--prefix', 'frontend', 'supabase', 'projects', 'list'], { stdio: 'ignore' });
  if (sb.status !== 0) {
    throw new Error('Supabase CLI is not logged in. Run `npx supabase login`, then re-run.');
  }
  const vc = run('npx', ['vercel', 'whoami'], { stdio: 'ignore' });
  if (vc.status !== 0) {
    throw new Error('Vercel CLI is not logged in. Run `npx vercel login` (and `npx vercel link` to connect this repo), then re-run.');
  }
  console.log('✅ Supabase and Vercel CLIs authenticated.\n');
}

async function main() {
  console.log('====================================================');
  console.log('🔐 GrantTrail Production Secrets Deployment');
  console.log('====================================================\n');

  let tempEnv;
  try {
    let projectRef = process.argv[2];
    if (!projectRef) {
      projectRef = await askQuestion('Enter your Supabase Project Ref: ');
    }
    projectRef = projectRef.trim();
    if (!projectRef) {
      throw new Error('Project Ref cannot be empty.');
    }

    // Parse and validate BOTH files before touching any platform, so we never
    // end up half-pushed because a value was missing.
    const supabaseVars = parseEnvFile(SUPABASE_FILE);
    const vercelVars = parseEnvFile(VERCEL_FILE);
    validate(SUPABASE_FILE, supabaseVars);
    validate(VERCEL_FILE, vercelVars);
    console.log('✅ Both .deploy/ files present and complete.\n');

    preflightAuth();

    // --- Supabase Edge Function secrets ---
    console.log('⚡ Pushing Edge Function secrets to Supabase...');
    // Write a normalized temp env file (only the required keys, comments stripped)
    // so --env-file never trips on template comments or stray entries.
    tempEnv = path.join(os.tmpdir(), `granttrail-supabase-${Date.now()}.env`);
    fs.writeFileSync(
      tempEnv,
      REQUIRED[SUPABASE_FILE].map((k) => `${k}=${supabaseVars[k]}`).join('\n') + '\n',
      { mode: 0o600 }
    );
    const sbPush = run('npx', [
      '--prefix', 'frontend', 'supabase', 'secrets', 'set',
      '--project-ref', projectRef, '--env-file', tempEnv,
    ], { stdio: 'inherit' });
    if (sbPush.status !== 0) {
      throw new Error('Failed to push Supabase secrets. Check the Project Ref and that you are logged in (`npx supabase login`).');
    }
    console.log('✅ Supabase secrets set.\n');

    // --- Vercel production env vars ---
    console.log('▲ Pushing frontend env vars to Vercel (production)...');
    for (const key of REQUIRED[VERCEL_FILE]) {
      // Remove any existing value first so a re-run overwrites cleanly (ignore "not found").
      run('npx', ['vercel', 'env', 'rm', key, 'production', '-y'], { stdio: 'ignore' });
      const add = run('npx', ['vercel', 'env', 'add', key, 'production'], { input: vercelVars[key] });
      if (add.status !== 0) {
        throw new Error(
          `Failed to set ${key} on Vercel.\n${(add.stderr || '').toString().trim()}\n` +
          'If the CLI is not authed/linked, run `npx vercel login` then `npx vercel link`, ' +
          'or set the two VITE_ vars in the Vercel dashboard — then re-run.'
        );
      }
      console.log(`   ✅ ${key}`);
    }
    console.log('');

    // --- Verify both landed ---
    console.log('🔎 Verifying Supabase secrets:');
    run('npx', ['--prefix', 'frontend', 'supabase', 'secrets', 'list', '--project-ref', projectRef], { stdio: 'inherit' });
    console.log('\n🔎 Verifying Vercel production env:');
    run('npx', ['vercel', 'env', 'ls', 'production'], { stdio: 'inherit' });

    // --- Shred only after both pushes succeeded ---
    fs.rmSync(DEPLOY_DIR, { recursive: true, force: true });
    console.log('\n🧹 Shredded .deploy/ — no production keys left on disk.');

    console.log('\n====================================================');
    console.log('🎉 Secrets deployed. Deploy the app with `git push` (Vercel rebuilds on push to main).');
    console.log('====================================================\n');
  } catch (err) {
    console.error(`\n❌ Error: ${err.message}`);
    console.error('\n.deploy/ was left in place so you can fix the issue and re-run.');
    process.exitCode = 1;
  } finally {
    if (tempEnv && fs.existsSync(tempEnv)) {
      try { fs.unlinkSync(tempEnv); } catch (_) { /* ignore */ }
    }
    rl.close();
  }
}

main();
