'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { readFileSync } = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const { WORKSPACE_URL, validateWorkspaceCommand, trustedWorkspaceSender, webURL, clampBounds } = require('../workspace-contracts.cjs');

function deferred() { let resolve, reject; const promise = new Promise((a, b) => { resolve = a; reject = b; }); return { promise, resolve, reject }; }
async function tick() { await new Promise(resolve => setImmediate(resolve)); }
function harness(native = { request: async () => ({ configured: false }) }) {
  let networkHandler, nextID = 1;
  const fakeContents = () => Object.assign(new EventEmitter(), {
    id: nextID++, mainFrame: { url: WORKSPACE_URL }, destroyed: false,
    isDestroyed() { return this.destroyed; }, close() { this.destroyed = true; },
    setWindowOpenHandler(handler) { this.windowOpenHandler = handler; },
    send(_channel, message) {
      this.messages.push(message);
      if (message.event === 'flush' && this.autoFlush) queueMicrotask(() => workspace.request(event(), { command: 'flushed', requestId: message.requestId, ok: true }));
    },
    messages: [], autoFlush: true, loadURL: async () => {}
  });
  class FakeWindow extends EventEmitter {
    constructor(options) { super(); this.options = options; this.webContents = fakeContents(); this.destroyed = false; this.contentView = { addChildView() {}, removeChildView() {} }; }
    isDestroyed() { return this.destroyed; }
    getContentSize() { return [1240, 820]; }
    getBounds() { return { width: 1240, height: 820 }; }
    loadURL() { return Promise.resolve(); }
    setTitle() {}
    show() {}
    focus() {}
    close() { this.destroy(); }
    destroy() { this.destroyed = true; this.emit('closed'); }
  }
  class FakeView { constructor(options) { this.options = options; this.webContents = fakeContents(); } setBounds(bounds) { this.bounds = bounds; } }
  const fakeSession = () => Object.assign(new EventEmitter(), { setPermissionRequestHandler(handler) { this.permissionHandler = handler; }, setPermissionCheckHandler(handler) { this.permissionCheck = handler; } });
  const electron = {
    BrowserWindow: FakeWindow, WebContentsView: FakeView, ipcMain: { handle() {} },
    session: { defaultSession: { webRequest: { onBeforeRequest(_filter, handler) { networkHandler = handler; } } }, fromPartition: fakeSession },
    screen: { getCursorScreenPoint: () => ({x:0,y:0}), getDisplayNearestPoint: () => ({workArea:{width:1440,height:900}}) },
    shell: { openExternal: async () => {} }, dialog: { showMessageBox: async () => ({response:0}) }
  };
  const module = { exports: {} }, directory = path.resolve(__dirname, '..');
  const code = readFileSync(path.join(directory, 'workspace.cjs'), 'utf8');
  vm.runInNewContext(code, { module, exports: module.exports, require: name => name === 'electron' ? electron : name.startsWith('./') ? require(path.join(directory, name)) : require(name), __dirname: directory, setTimeout, clearTimeout, console });
  const workspace = new module.exports.ReadingWorkspace({ native, preview: true, userData: path.join(os.tmpdir(), 'savenest-workspace-tests') });
  workspace.window = new FakeWindow({});
  workspace.source = { url: 'https://example.com/a', title: 'Page A' };
  workspace.payload = { source: workspace.source, notes: {configured:true} };
  workspace.documents.add('note-a');
  const event = () => ({ sender: workspace.window.webContents, senderFrame: workspace.window.webContents.mainFrame });
  return { workspace, event, electron, network: details => { let value; networkHandler(details, result => { value = result; }); return value; } };
}

test('workspace commands reject arbitrary capabilities and malformed note writes', () => {
  for (const input of [null, [], 'noteSave', {command:'exec'}, {command:'callback'}, {command:'noteDiscardDraft'}, {command:'noteSave',documentId:'a',text:'x'}, {command:'noteDraft',documentId:'a',revision:'r',text:'x'.repeat(100001)}, {command:'readerImages',enabled:1}, {command:'original',enabled:true,bounds:{x:0,y:0,width:NaN,height:40}}]) assert.throws(() => validateWorkspaceCommand(input));
  assert.deepEqual(validateWorkspaceCommand({command:'noteDiscardDraft',documentId:'note-a',path:'/etc/passwd'}), {command:'noteDiscardDraft',documentId:'note-a'});
  assert.equal(webURL('file:///etc/passwd'), null);
  assert.equal(webURL('https://user:password@example.com'), null);
  assert.deepEqual(clampBounds({x:1200,y:800,width:900,height:1000},[1240,820]),{x:1200,y:800,width:40,height:20});
});

test('only the exact owning local main frame can access workspace IPC', async () => {
  const {workspace,event} = harness();
  assert.equal(trustedWorkspaceSender(event(), workspace.window.webContents), true);
  const childFrame = {...event(),senderFrame:{url:WORKSPACE_URL}};
  assert.equal(trustedWorkspaceSender(childFrame,workspace.window.webContents),false);
  await assert.rejects(workspace.request(childFrame,{command:'noteOpen',documentId:'note-a'}),/Untrusted/);
  await assert.rejects(workspace.request(event(),{command:'noteOpen',documentId:'another-note'}),/no longer open/);
  await assert.rejects(workspace.request(event(),{command:'noteLoad',url:'https://example.com/b'}),/page changed/);
  workspace.destroy();
});

test('reader image requests require explicit opt-in and never authorize other network types', async () => {
  const {workspace,event,network} = harness();
  const request = {webContentsId:workspace.window.webContents.id,resourceType:'image'};
  assert.equal(network(request).cancel,true);
  await workspace.request(event(),{command:'readerImages',enabled:true});
  assert.equal(network(request).cancel,false);
  assert.equal(network({...request,resourceType:'xhr'}).cancel,true);
  assert.equal(network({...request,webContentsId:-1}).cancel,false);
  workspace.destroy();
});

test('a successful flush acknowledgement cannot close a document still marked dirty', async () => {
  const {workspace} = harness();
  workspace.dirty = true;
  assert.equal(await workspace.close(),false);
  assert.equal(workspace.window.isDestroyed(),false);
  assert.equal(workspace.dirty,true);
  workspace.destroy();
});

test('only the latest requested page wins when browser capture returns out of order', async () => {
  const a=deferred(),b=deferred();
  const {workspace} = harness({request: request => request.command === 'notesStatus' ? Promise.resolve({configured:false}) : request.command === 'a' ? a.promise : b.promise});
  const first=workspace.open({command:'a'}), second=workspace.open({command:'b'});
  assert.equal(workspace.busy,true);
  b.resolve({url:'https://example.com/b',title:'B'});
  assert.equal(await second,true);
  a.resolve({url:'https://example.com/a',title:'A'});
  assert.equal(await first,false);
  assert.equal(workspace.source.title,'B');
  assert.equal(workspace.busy,false);
  workspace.destroy();
});

test('starting a page capture does not invalidate the current document save', async () => {
  const save=deferred(),capture=deferred();
  const {workspace,event} = harness({request: request => request.command === 'noteSave' ? save.promise : capture.promise});
  const pendingSave=workspace.request(event(),{command:'noteSave',documentId:'note-a',text:'My writing',revision:'r1'});
  const pendingOpen=workspace.open({command:'readerCurrent'});
  save.resolve({documentId:'note-a',text:'My writing',revision:'r2'});
  assert.equal((await pendingSave).revision,'r2');
  workspace.destroy();
  capture.resolve({url:'https://example.com/new',title:'New'});
  assert.equal(await pendingOpen,false);
});

test('stale note responses cannot authorize documents after the active source changes', async () => {
  const note=deferred();
  const {workspace,event} = harness({request:()=>note.promise});
  const response=workspace.request(event(),{command:'noteLoad',url:workspace.source.url});
  workspace.documentGeneration++;
  note.resolve({documentId:'stale-note',text:'old'});
  await assert.rejects(response,/page changed/);
  assert.equal(workspace.documents.has('stale-note'),false);
  workspace.destroy();
});

test('quit cancels and drains pending capture before reporting it is safe to stop the helper', async () => {
  const capture=deferred();
  const {workspace} = harness({request:()=>capture.promise});
  const open=workspace.open({command:'readerCurrent'});
  let finished=false;
  const quit=workspace.prepareToQuit().then(value=>{finished=true;return value;});
  await tick();
  assert.equal(finished,false);
  capture.resolve({url:'https://example.com/late',title:'Late'});
  assert.equal(await open,false);
  assert.equal(await quit,true);
  assert.equal(workspace.source.title,'Page A');
  workspace.destroy();
});

test('Original view has no preload or Node access and blocks unsolicited navigation', async () => {
  const {workspace,event}=harness();
  await workspace.request(event(),{command:'original',enabled:true,bounds:{x:0,y:100,width:600,height:600}});
  const view=workspace.original,preferences=view.options.webPreferences;
  assert.equal(preferences.preload,undefined);
  assert.equal(preferences.nodeIntegration,false);
  assert.equal(preferences.sandbox,true);
  assert.equal(preferences.contextIsolation,true);
  assert.equal(preferences.session.permissionCheck(),false);
  let prevented=false;
  view.webContents.emit('will-navigate',{preventDefault(){prevented=true;}},'https://example.com/other');
  assert.equal(prevented,true);
  assert.equal(workspace.window.webContents.messages.at(-1).event,'originalNavigation');
  workspace.removeOriginal();
  const before=workspace.window.webContents.messages.length;
  view.webContents.emit('did-finish-load');
  assert.equal(workspace.window.webContents.messages.length,before,'old view must not send state into a replacement');
  workspace.destroy();
});

test('a crashed renderer preserves recovery and requires an explicit choice before closing', async () => {
  const {workspace,electron}=harness();
  workspace.rendererCrashed=true; workspace.dirty=true;
  assert.equal(await workspace.flush('quit'),false);
  assert.equal(workspace.dirty,true);
  electron.dialog.showMessageBox=async()=>({response:1});
  assert.equal(await workspace.flush('quit'),true);
  assert.equal(workspace.dirty,false);
  workspace.destroy();
});


test('optional Reader extraction is pinned to the open page and rejects stale responses', async () => {
  const capture = deferred(); let requested;
  const {workspace,event} = harness({request: request => { requested = request; return capture.promise; }});
  const pending = workspace.request(event(), {command:'readerExtract',url:'https://example.com/other'});
  assert.equal(requested.url, 'https://example.com/a');
  assert.equal(requested.command, 'readerExtract');
  workspace.documentGeneration++;
  capture.resolve({url:'https://example.com/a',article:{content:'Old article'}});
  await assert.rejects(pending, /page changed/);
  assert.equal(workspace.source.article,undefined);
  workspace.destroy();
});
