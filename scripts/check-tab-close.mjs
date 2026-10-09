import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import assert from 'node:assert/strict';
const source = readFileSync(new URL('../Sources/SaveNest/TabCloseScript.swift', import.meta.url), 'utf8');
const script = source.split('#"""')[1].split('"""#')[0];
let checks = 0;
function fixture(tabs, windowID = 4, running = true) {
  const closed = [], calls = { bulkURLs: 0, bulkTabIDs: 0, bulkWindowIDs: 0, individualURLs: 0 };
  // Model JXA collection specifiers: bulk property getters and indexed objects.
  const collection = tabs.map(t => ({
    id: () => t.id,
    url: () => { calls.individualURLs++; return t.finalURL ?? t.url; },
    close: () => closed.push(t.id)
  }));
  collection.url = () => { calls.bulkURLs++; return tabs.map(t => t.url); };
  collection.id = () => { calls.bulkTabIDs++; return tabs.map(t => t.id); };
  const window = { id: () => windowID, tabs: collection };
  const windows = [window];
  windows.id = () => { calls.bulkWindowIDs++; return [windowID]; };
  return { app: { running: () => running, windows }, window, closed, calls };
}
function verify({safari = true, tabs = [{id:1,url:'https://example.com/a'}], windowID = 4, running = true, target = {}, expected}) {
  const f = fixture(tabs, windowID, running);
  const result = runInNewContext(script + '\ncloseCapturedTab(app, target)', {
    app: f.app, target: {windowID:4, index:0, tabID:1, url:'https://example.com/a', safari, ...target}
  });
  assert.equal(result, expected !== null);
  assert.deepEqual(f.closed, expected === null ? [] : [expected]);
  assert.ok(f.calls.individualURLs <= 1, 'Never scan individual tab URLs');
  checks++;
  return f.calls;
}
verify({expected:1});
verify({running:false,expected:null});
verify({windowID:5,expected:null});
verify({tabs:[],expected:null});
verify({tabs:[{id:1,url:'https://example.com/changed'}],expected:null});
verify({tabs:[{id:2,url:'https://example.com/b'},{id:1,url:'https://example.com/a'}],expected:null});
verify({tabs:[{id:1,url:'https://example.com/a'},{id:2,url:'https://example.com/a'}],expected:null});
verify({safari:false,tabs:[{id:2,url:'https://example.com/b'},{id:1,url:'https://example.com/a'}],expected:1});
verify({safari:false,tabs:[{id:2,url:'https://example.com/a'}],expected:null});
verify({safari:false,tabs:[{id:1,url:'https://example.com/changed'}],expected:null});
// Navigation between the bulk snapshot and final validation must leave the tab open.
for (const safari of [true, false]) {
  verify({safari,tabs:[{id:1,url:'https://example.com/a',finalURL:'https://example.com/changed'}],expected:null});
}
// A large window must require a constant number of browser calls, both on capture and close.
const manyTabs = Array.from({length:1000}, (_, id) => ({id, url:`https://example.com/${id}`}));
const f = fixture(manyTabs);
assert.equal(runInNewContext(script + '\nuniqueSafariTabIndex(window, url)', {
  window:f.window, url:manyTabs[999].url
}), 999);
assert.deepEqual(f.calls, {bulkURLs:1,bulkTabIDs:0,bulkWindowIDs:0,individualURLs:0});
checks++;
for (const safari of [true, false]) {
  const calls = verify({safari,tabs:manyTabs,target:{index:999,tabID:999,url:manyTabs[999].url},expected:999});
  assert.deepEqual(calls, {bulkURLs:safari ? 1 : 0,bulkTabIDs:safari ? 0 : 1,bulkWindowIDs:1,individualURLs:1});
}
console.log(`Passed ${checks} tab-close safety and performance checks`);
