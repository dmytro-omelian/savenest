'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const path = require('node:path');
const { JSDOM } = require('jsdom');
const tick = () => new Promise(resolve => setImmediate(resolve));

function harness(save) {
  const root = path.join(__dirname, '../renderer');
  const dom = new JSDOM(readFileSync(path.join(root, 'index.html'), 'utf8'), { runScripts: 'outside-only', pretendToBeVisual: true });
  const { window } = dom;
  const calls = []; let emit;
  window.HTMLElement.prototype.scrollIntoView = () => {};
  window.savenest = {
    onEvent(callback) { emit = callback; },
    async command(request) {
      calls.push(request);
      return ['add', 'saveDraft', 'edit'].includes(request.command) ? save(request) : true;
    }
  };
  window.eval(readFileSync(path.join(root, 'launcher-model.js'), 'utf8'));
  window.eval(readFileSync(path.join(root, 'renderer.js'), 'utf8'));
  return { window, calls, emit: message => emit(message), close: () => window.close() };
}
function submit(h) {
  h.window.document.dispatchEvent(new h.window.KeyboardEvent('keydown', { key: 'Enter', metaKey: true, bubbles: true, cancelable: true }));
}
for (const captured of [false, true]) {
  test(`Cmd+Enter dismisses ${captured ? 'captured note' : 'new link'} only after save succeeds`, async () => {
    let finish;
    const h = harness(() => new Promise(resolve => { finish = resolve; }));
    try {
      if (captured) h.emit({ event: 'state', state: { rows: [], query: '', scope: 'All', captureDraft: { id: 'capture-1', url: 'https://example.com', title: 'Page' } } });
      else { h.emit({ event: 'add' }); h.window.document.getElementById('edit-url').value = 'https://example.com'; }
      h.window.document.getElementById('edit-note').value = 'Keep this note';
      submit(h); submit(h);
      assert.equal(h.calls.filter(c => c.command === (captured ? 'saveDraft' : 'add')).length, 1);
      assert.equal(h.calls.some(c => c.command === 'dismiss'), false);
      finish(true); await tick();
      assert.equal(h.window.document.body.dataset.view, 'root');
      assert.equal(h.calls.filter(c => c.command === 'dismiss').length, 1);
    } finally { h.close(); }
  });
}
for (const failure of [false, new Error('Disk full')]) {
  test(`failed save preserves editor and note (${failure ? 'rejection' : 'false response'})`, async () => {
    const h = harness(() => { if (failure) throw failure; return false; });
    try {
      h.emit({ event: 'add' });
      h.window.document.getElementById('edit-url').value = 'https://example.com';
      h.window.document.getElementById('edit-note').value = 'Unsaved note';
      submit(h); await tick();
      assert.equal(h.window.document.body.dataset.view, 'editor');
      assert.equal(h.window.document.getElementById('edit-note').value, 'Unsaved note');
      assert.equal(h.calls.some(c => c.command === 'dismiss'), false);
      assert.equal(h.window.document.getElementById('primary').disabled, false);
      if (failure) assert.equal(h.window.document.getElementById('editor-error').textContent, 'Disk full');
    } finally { h.close(); }
  });
}
test('editing an existing result saves without dismissing the launcher', async () => {
  const h = harness(() => true);
  try {
    h.emit({ event: 'state', state: { rows: [{ id: 'saved-1', title: 'Example', url: 'https://example.com', isSaved: true }], query: '', scope: 'Saved' } });
    h.window.document.dispatchEvent(new h.window.KeyboardEvent('keydown', { key: 'e', metaKey: true, bubbles: true }));
    h.window.document.getElementById('edit-note').value = 'Updated note';
    submit(h); await tick();
    assert.equal(h.calls.filter(c => c.command === 'edit').length, 1);
    assert.equal(h.window.document.body.dataset.view, 'root');
    assert.equal(h.calls.some(c => c.command === 'dismiss'), false);
  } finally { h.close(); }
});
