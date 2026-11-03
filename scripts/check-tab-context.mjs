import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import assert from 'node:assert/strict';
const source = readFileSync(new URL('../Sources/SaveNest/TabContext.swift', import.meta.url), 'utf8');
const blocks = [...source.matchAll(/#"""([\s\S]*?)"""#/g)].map(match => match[1]);
const node = (text, excluded = false, visible = true) => ({innerText: text, querySelector: () => null, closest: () => excluded, getClientRects: () => visible ? [1] : []});
const page = runInNewContext(blocks[0], {
  document: {querySelector: () => ({content: 'A useful description'}), querySelectorAll: () => [node('Research ritual'), node('private form text', true), node('hidden paragraph', false, false), node('Visible paragraph')]},
  getComputedStyle: () => ({display:'block', visibility:'visible'}), location: {href: 'https://example.com/page'}
});
assert.deepEqual(JSON.parse(page), {url:'https://example.com/page', text:'A useful description Research ritual Visible paragraph'});
const bounded = runInNewContext(blocks[0], {
  document: {querySelector: () => null, querySelectorAll: () => Array.from({length:1000}, () => node('a'.repeat(10000)))},
  getComputedStyle: () => ({}), location:{href:'https://example.com/page'}
});
assert.equal(JSON.parse(bounded).text.length, 8000);
const read = runInNewContext(blocks[1] + '\nreadTabContexts');
let reads = 0;
const tab = {id: () => '1', url: () => 'https://example.com/page', execute: () => { reads++; return page; }};
const app = {running: () => true, windows: () => [{id: () => 42, tabs: () => [tab]}], doJavaScript: () => { reads++; return page; }};
const target = {key: 'tab-context', windowID: '42', tabID: '1', index: 1, url: 'https://example.com/page'};
for (const safari of [true, false]) {
  const result = read(app, [target], safari, 'fixed source');
  assert.equal(result.contexts[0].key, target.key);
  assert.match(result.contexts[0].text, /Research ritual/);
  assert.equal(result.blocked, false);
}
assert.equal(reads, 2);
assert.equal(read(app, [{...target, url:'https://example.com/changed'}], false, '').contexts.length, 0);
assert.equal(reads, 2);
assert.equal(read(app, [{...target, windowID:'43'}], false, '').contexts.length, 0);
// A navigation during DOM extraction must discard the response.
tab.execute = () => JSON.stringify({url:'https://example.com/changed', text:'wrong document'});
assert.equal(read(app, [target], false, '').contexts.length, 0);
tab.execute = () => { throw {errorNumber:-1743}; };
assert.equal(read(app, [target, target], false, '').blocked, true);
tab.execute = () => { throw {errorNumber:-1728}; };
assert.equal(read(app, [target], false, '').blocked, false);
console.log('Passed page context checks: bounded text, form/hidden exclusion, browser identity, navigation and permission guards');
