#!/usr/bin/env node
/**
 * Build-time guard for required VITE_ environment variables.
 *
 * Vite inlines env vars into the bundle at build time, so a missing one
 * doesn't fail the build — it silently ships `undefined` and the app crashes
 * at module load (blank white screen). This runs as `prebuild`, so any build
 * (local, CI, or Vercel) fails fast with a clear message instead.
 */

// Vars the app cannot boot without. Keep in sync with src/supabaseClient.js.
const REQUIRED = ['VITE_SUPABASE_URL', 'VITE_SUPABASE_KEY'];

const missing = REQUIRED.filter((name) => !process.env[name]?.trim());

if (missing.length > 0) {
  console.error(
    `\n✗ Missing required environment variable(s): ${missing.join(', ')}\n` +
      `  Vite inlines these at build time. Set them in your build environment` +
      ` (e.g. Vercel → Settings → Environment Variables) and rebuild.\n`
  );
  process.exit(1);
}

console.log(`✓ Required env vars present: ${REQUIRED.join(', ')}`);
