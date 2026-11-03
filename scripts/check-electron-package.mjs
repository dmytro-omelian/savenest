import { mkdtemp, readFile, rm, appendFile } from 'node:fs/promises';
import { createReadStream } from 'node:fs';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';
import { extractFile } from '@electron/asar';

const [archive, architecture] = process.argv.slice(2);
if (!archive || !['arm64', 'x64'].includes(architecture)) throw new Error('Usage: node scripts/check-electron-package.mjs ARCHIVE arm64|x64');
const temporary = await mkdtemp(path.join(tmpdir(), 'savenest-package-check-'));
const run = (command, args) => execFileSync(command, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
try {
  run('ditto', ['-x', '-k', path.resolve(archive), temporary]);
  const app = path.join(temporary, 'SaveNest.app');
  const helper = path.join(app, 'Contents/Resources/SaveNest.app');
  const plist = (bundle, key) => run('/usr/libexec/PlistBuddy', ['-c', `Print :${key}`, path.join(bundle, 'Contents/Info.plist')]);
  const version = plist(app, 'CFBundleShortVersionString');
  assert.equal(plist(app, 'CFBundleIdentifier'), 'app.savenest.electron');
  assert.equal(plist(helper, 'CFBundleIdentifier'), 'app.savenest.mac');
  assert.equal(plist(helper, 'CFBundleShortVersionString'), version);
  assert.equal(plist(helper, 'SaveNestUpdatesEnabled'), 'false');
  const cpu = architecture === 'x64' ? 'x86_64' : 'arm64';
  run('lipo', [path.join(app, 'Contents/MacOS/SaveNest'), '-verify_arch', cpu]);
  run('lipo', [path.join(helper, 'Contents/MacOS/SaveNest'), '-verify_arch', cpu]);
  run('codesign', ['--verify', '--deep', '--strict', app]);
  run('xcrun', ['stapler', 'validate', app]);
  run('spctl', ['--assess', '--type', 'execute', app]);
  const asar = path.join(app, 'Contents/Resources/app.asar');
  const manifest = JSON.parse(extractFile(asar, 'package.json').toString());
  assert.equal(manifest.version, version); assert.equal(manifest.saveNestRelease, true);
  for (const name of ['Electron-LICENSE.txt', 'LICENSES.chromium.html', 'Sparkle-LICENSE.txt']) {
    assert.ok((await readFile(path.join(app, 'Contents/Resources/licenses', name))).length > 50);
  }
  const hash = createHash('sha256');
  for await (const chunk of createReadStream(archive)) hash.update(chunk);
  const sha256 = hash.digest('hex');
  // Check the resource seal rejects modified code, on an isolated temporary copy.
  await appendFile(asar, '\nmodified-for-signature-validation\n');
  let rejected = false;
  try { run('codesign', ['--verify', '--deep', '--strict', app]); } catch { rejected = true; }
  assert.equal(rejected, true, 'A modified app archive must fail signature verification.');
  console.log(JSON.stringify({ archive: path.resolve(archive), architecture, version, sha256,
    checks: ['matching versions', 'correct architectures', 'signature', 'stapled notarization', 'Gatekeeper', 'helper updater disabled', 'licenses', 'tamper rejection'] }, null, 2));
} finally { await rm(temporary, { recursive: true, force: true }); }
