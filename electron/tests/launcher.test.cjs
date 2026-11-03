const { test } = require('node:test');
const assert = require('node:assert/strict');
const { commands, detectedURL, rows, primaryLabel } = require('../renderer/launcher-model.js');

test('root search exposes saving, open tabs, browser history and settings without a mode change', () => {
  assert(commands('').some(item => item.action === 'quick'));
  assert(commands('').some(item => item.action === 'note'));
  assert.equal(commands('history')[0].scope, 'History');
  assert.equal(commands('open tabs')[0].scope, 'Open');
  assert.equal(commands('settings')[0].command, 'settings');
  assert.equal(commands('save with a note')[0].action, 'note');
  assert.equal(commands('history sources')[0].ui, 'sources');
});
test('URL input becomes a save command, rejecting credentials and unsafe schemes', () => {
  assert.equal(detectedURL('example.com/path?q=a#b'), 'https://example.com/path?q=a#b');
  assert.equal(commands('https://example.com/')[0].id, 'command:save-url');
  for (const value of ['javascript:alert(1)', 'file:///tmp/private', 'https://u:p@example.com', 'https://u@example.com', 'not a URL', 'search history', 'data:text/html,test']) assert.equal(detectedURL(value), null);
});
test('a merged open/saved/history result switches to its tab; history-only opens the link', () => {
  const page = { id: 'tab:1', title: 'Page', isOpen: true, isSaved: true, isHistory: true };
  const found = rows({ scope: 'All', rows: [page] }, 'page');
  assert.equal(found.filter(item => item.kind === 'page').length, 1);
  assert.equal(primaryLabel(found.find(item => item.kind === 'page')), 'Switch to tab');
  assert.equal(primaryLabel({ kind: 'page', isHistory: true, isOpen: false }), 'Open link');
});
test('scoped search contains pages only and undo is offered only when available', () => {
  assert.deepEqual(rows({ scope: 'History', rows: [] }, 'save'), []);
  assert.equal(commands('undo', { canUndo: false }).length, 0);
  assert.equal(commands('undo', { canUndo: true })[0].command, 'undo');
});
