import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import assert from 'node:assert/strict';
const source = readFileSync(new URL('../Sources/SaveNest/TabCloseScript.swift', import.meta.url), 'utf8');
const script = source.split('#"""')[1].split('"""#')[0];
let checks = 0;
function verify({safari = true, tabs = [{id:1,url:'https://example.com/a'}], windowID = 4, running = true, target = {}, expected}) {
  const closed = [];
  const app = { running: () => running, windows: () => [{id: () => windowID, tabs: () => tabs.map(t => ({id: () => t.id, url: () => t.url, close: () => closed.push(t.id)}))}] };
  const result = runInNewContext(script + '\ncloseCapturedTab(app, target)', { app, target: {windowID:4, index:0, tabID:1, url:'https://example.com/a', safari, ...target} });
  assert.equal(result, expected !== null);
  assert.deepEqual(closed, expected === null ? [] : [expected]);
  checks++;
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
console.log(`Passed ${checks} tab-close safety checks`);
