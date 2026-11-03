'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { feedURL, createUpdater, canRestartSafely } = require('../updater.cjs');

function fixture(overrides = {}) {
  const autoUpdater = new EventEmitter();
  const calls = { checks: 0, installs: 0, before: 0, messages: [] };
  autoUpdater.setFeedURL = value => { calls.feed = value; };
  autoUpdater.checkForUpdates = () => { calls.checks++; };
  autoUpdater.quitAndInstall = () => { calls.installs++; };
  const dialog = { showMessageBox: async value => { calls.messages.push(value); return { response: 1 }; } };
  const updater = createUpdater({ app: { isPackaged: true, getVersion: () => '0.11.0' }, autoUpdater, dialog,
    release: true, architecture: 'arm64', beforeInstall: () => { calls.before++; }, ...overrides });
  return { updater, autoUpdater, calls };
}
const tick = () => new Promise(resolve => setImmediate(resolve));

test('architecture selects a fixed HTTPS Electron feed; unknown architectures are unsupported', () => {
  assert.equal(feedURL('arm64'), 'https://savenest.app/downloads/electron/arm64/RELEASES.json');
  assert.equal(feedURL('x64'), 'https://savenest.app/downloads/electron/x64/RELEASES.json');
  assert.equal(feedURL('../appcast.xml'), null);
});
test('development packages never configure or contact the production updater', async () => {
  for (const options of [{ release: false }, { app: { isPackaged: false } }, { architecture: 'invalid' }]) {
    const { updater, calls } = fixture(options);
    await updater.check();
    assert.equal(updater.enabled, false); assert.equal(calls.feed, undefined); assert.equal(calls.checks, 0);
  }
});
test('checks are explicit and overlapping checks cannot download twice', async () => {
  const { updater, calls, autoUpdater } = fixture();
  if (process.platform !== 'darwin') return;
  assert.equal(calls.checks, 0); assert.equal(calls.feed.serverType, 'json');
  await updater.check(); await updater.check(); assert.equal(calls.checks, 1);
  autoUpdater.emit('update-not-available'); await tick();
  await updater.check(); assert.equal(calls.checks, 2);
});
test('downloaded update only restarts after a confirmed choice and prepares helper shutdown', async () => {
  const { autoUpdater, calls } = fixture();
  if (process.platform !== 'darwin') return;
  autoUpdater.emit('update-downloaded'); await tick();
  assert.equal(calls.before, 1); assert.equal(calls.installs, 1);
});
test('active drafts prevent updater-initiated restart; a later check can offer installation', async () => {
  let safe = false;
  const { updater, autoUpdater, calls } = fixture({ canRestart: () => safe });
  if (process.platform !== 'darwin') return;
  autoUpdater.emit('update-downloaded'); await tick(); assert.equal(calls.installs, 0);
  safe = true; await updater.check(); assert.equal(calls.installs, 1); assert.equal(calls.checks, 0);
});
test('failed updates permit retry without altering installed app', async () => {
  const { updater, autoUpdater, calls } = fixture();
  if (process.platform !== 'darwin') return;
  await updater.check(); autoUpdater.emit('error', new Error('offline')); await tick();
  await updater.check(); assert.equal(calls.checks, 2); assert.equal(calls.installs, 0);
});

test('restart fails closed for missing helper state, native sheets, pending captures, and connection failures', () => {
  const safe = { canRestartForUpdate: true, busy: false, captureDraft: null, captureSelection: null };
  assert.equal(canRestartSafely({ view: 'root', state: safe }), true);
  for (const input of [
    { view: 'root' }, { view: 'root', state: {} },
    { view: 'root', state: { ...safe, canRestartForUpdate: false } },
    { view: 'editor', state: safe }, { view: 'selection', state: safe },
    { view: 'root', state: { ...safe, busy: true } },
    { view: 'root', state: { ...safe, captureDraft: { id: 'draft' } } },
    { view: 'root', state: { ...safe, captureSelection: { id: 'selection' } } },
    { view: 'root', state: safe, failed: true }
  ]) assert.equal(canRestartSafely(input), false);
});

test('restart rechecks fresh asynchronous helper state after confirmation', async () => {
  let checks = 0;
  const { autoUpdater, calls } = fixture({ canRestart: async () => ++checks === 1 });
  if (process.platform !== 'darwin') return;
  autoUpdater.emit('update-downloaded'); await tick();
  assert.equal(checks, 2); assert.equal(calls.installs, 0);
});
test('a failed helper readiness request never restarts the app', async () => {
  const { autoUpdater, calls } = fixture({ canRestart: async () => { throw new Error('disconnected'); } });
  if (process.platform !== 'darwin') return;
  autoUpdater.emit('update-downloaded'); await tick();
  assert.equal(calls.installs, 0);
});
