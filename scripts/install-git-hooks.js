#!/usr/bin/env node
/**
 * Wire git up to the version-controlled hooks in .githooks/ so every clone gets
 * the pre-push migration-drift check. Runs as part of `npm run setup` (and as a
 * `prepare` step), so contributors don't have to install hooks by hand.
 *
 * Idempotent and failure-tolerant: it no-ops (without failing the install) when
 * run outside a git work tree or when git is unavailable, so it never breaks
 * `npm install` in CI or in a downloaded tarball.
 */
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const hooksDir = path.join(root, '.githooks');

try {
  if (!fs.existsSync(hooksDir)) {
    process.exit(0); // Nothing to install.
  }

  // Only touch git config if we're actually inside a git work tree.
  execFileSync('git', ['rev-parse', '--is-inside-work-tree'], { cwd: root, stdio: 'ignore' });
  execFileSync('git', ['config', 'core.hooksPath', '.githooks'], { cwd: root });

  // Ensure the hook is executable (no-op / harmless on Windows).
  try {
    fs.chmodSync(path.join(hooksDir, 'pre-push'), 0o755);
  } catch (_) {
    /* ignore — git for Windows runs hooks via its bundled shell regardless */
  }

  console.log('✓ Git hooks installed (core.hooksPath → .githooks).');
  console.log('  pre-push will block schema changes that are missing a migration.');
} catch (_err) {
  console.log('ℹ️  Skipped git hook install (not a git work tree or git unavailable).');
}
