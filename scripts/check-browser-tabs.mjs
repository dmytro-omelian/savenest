import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import assert from 'node:assert/strict';
const source = readFileSync(new URL('../Sources/SaveNest/BrowserTabScript.swift', import.meta.url), 'utf8');
const script = source.split('#"""')[1].split('"""#')[0];
const { readBrowserTabs, activateBrowserTab } = runInNewContext(script + '\n({readBrowserTabs, activateBrowserTab})');
let checks = 0;
function fixture(safari, stringIDs) {
  const id = value => stringIDs ? String(value) : value;
  const tabs = Array.from({length:12}, (_, i) => ({
    id: () => id(i + 1), url: () => `https://example.com/${i}`, name: () => `Safari ${i}`, title: () => `Chrome ${i}`
  }));
  tabs.push({id: () => id(99), url: () => 'chrome://settings'});
  const window = {id: () => id(42), tabs: () => tabs};
  const app = {running: () => true, windows: () => [window], activate() { this.activated = true; }};
  const browser = {id: safari ? 'com.apple.Safari' : 'com.google.Chrome', name: safari ? 'Safari' : 'Chrome', safari};
  return {app, browser, window, tabs};
}
const combined = [];
for (const [safari, stringIDs] of [[true, false], [false, true], [false, false]]) {
  const f = fixture(safari, stringIDs);
  const rows = readBrowserTabs(f.app, f.browser);
  assert.equal(rows.length, 12);
  assert.equal(rows[0].windowID, '42');
  assert.equal(rows[0].tabID, safari ? '' : '1');
  assert.equal(rows[0].title, safari ? 'Safari 0' : 'Chrome 0');
  const target = {...rows[10], safari};
  assert.equal(activateBrowserTab(f.app, target), true);
  assert.equal(f.app.activated, true);
  if (safari) assert.equal(f.window.currentTab, f.tabs[10]);
  else assert.equal(f.window.activeTabIndex, 11);
  // Reordering retains tab identity; navigating must never switch to another URL.
  [f.tabs[0], f.tabs[10]] = [f.tabs[10], f.tabs[0]];
  assert.equal(activateBrowserTab(f.app, target), true);
  f.tabs[0].url = () => 'https://example.com/changed';
  assert.equal(activateBrowserTab(f.app, target), false);
  assert.equal(activateBrowserTab(f.app, {...target, windowID:'missing'}), false);
  combined.push(...rows);
  checks++;
}
assert.equal(new Set(combined.map(t => t.browserID)).size, 2);
checks++;
const f = fixture(false, true);
f.tabs[0].url = () => { throw {errorNumber:-1743}; };
assert.throws(() => readBrowserTabs(f.app, f.browser));
checks++;
f.tabs[0].url = () => { throw {errorNumber:-1728}; };
assert.equal(readBrowserTabs(f.app, f.browser).length, 11);
checks++;
f.app.running = () => false;
assert.equal(readBrowserTabs(f.app, f.browser).length, 0);
assert.equal(activateBrowserTab(f.app, {}), false);
checks++;
// Profiles share a browser application but have separate window IDs. Include
// every window and route identical URLs/tab IDs back to the original window.
for (const safari of [false, true]) {
  const a = fixture(safari, !safari), b = fixture(safari, !safari);
  b.window.id = () => safari ? 43 : '43';
  a.app.windows = () => [a.window, b.window];
  const rows = readBrowserTabs(a.app, a.browser);
  assert.equal(rows.length, 24);
  assert.equal(new Set(rows.map(t => t.windowID)).size, 2);
  const target = {...rows[12], safari};
  assert.equal(target.windowID, '43');
  assert.equal(activateBrowserTab(a.app, target), true);
  assert.equal(a.window.currentTab, undefined);
  assert.equal(a.window.activeTabIndex, undefined);
  if (safari) assert.equal(b.window.currentTab, b.tabs[0]);
  else assert.equal(b.window.activeTabIndex, 1);
  // Losing the original profile window must not activate the matching tab elsewhere.
  a.app.windows = () => [a.window];
  assert.equal(activateBrowserTab(a.app, target), false);
  checks++;
}
console.log(`Passed ${checks} browser tab discovery and switching checks`);
