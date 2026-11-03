'use strict';
const WORKSPACE_URL = 'savenest-ui://app/workspace.html';
const noteCommands = new Set(['notesStatus', 'notesChooseVault', 'notesChooseFolder', 'noteLoad', 'noteSave', 'noteDraft', 'noteCheck', 'noteOpen', 'noteReveal', 'noteLocate', 'noteSaveCopy', 'noteDiscardDraft']);
const commands = new Set([...noteCommands, 'init', 'readerExtract', 'original', 'readerImages', 'browser', 'close', 'ready', 'dirty', 'flushed']);
function webURL(raw) {
  try {
    if (typeof raw !== 'string' || raw.length > 16384) return null;
    const url = new URL(raw);
    return ['https:', 'http:'].includes(url.protocol) && url.hostname && !url.username && !url.password ? url.href : null;
  } catch { return null; }
}
function validateWorkspaceCommand(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input) || !commands.has(input.command)) throw new Error('Unknown workspace action.');
  const result = { command: input.command };
  for (const [key, max] of Object.entries({ documentId: 200, text: 100000, revision: 200, url: 16384, title: 10000, requestId: 100 })) {
    if (input[key] === undefined) continue;
    if (typeof input[key] !== 'string' || input[key].length > max) throw new Error(`Invalid ${key}.`);
    result[key] = input[key];
  }
  for (const key of ['enabled', 'dirty', 'ok']) {
    if (input[key] === undefined) continue;
    if (typeof input[key] !== 'boolean') throw new Error(`Invalid ${key}.`);
    result[key] = input[key];
  }
  if (result.url !== undefined && !webURL(result.url)) throw new Error('Only web page addresses are supported.');
  if (['noteSave', 'noteDraft', 'noteSaveCopy'].includes(result.command) && typeof result.text !== 'string') throw new Error('Missing note text.');
  if (['noteSave', 'noteDraft', 'noteCheck', 'noteOpen', 'noteReveal', 'noteLocate', 'noteSaveCopy', 'noteDiscardDraft'].includes(result.command) && !result.documentId) throw new Error('Missing note.');
  if (['noteSave', 'noteDraft', 'noteCheck'].includes(result.command) && typeof result.revision !== 'string') throw new Error('Missing note revision.');
  if (result.command === 'noteLoad' && !result.url) throw new Error('Missing page address.');
  if (result.command === 'original') {
    if (typeof result.enabled !== 'boolean') throw new Error('Missing preview mode.');
    if (result.enabled) {
      const b = input.bounds;
      if (!b || ['x', 'y', 'width', 'height'].some(k => !Number.isFinite(b[k]) || b[k] < 0 || b[k] > 20000)) throw new Error('Invalid preview bounds.');
      result.bounds = Object.fromEntries(['x', 'y', 'width', 'height'].map(k => [k, Math.round(b[k])]));
    }
  }
  if (result.command === 'dirty' && typeof result.dirty !== 'boolean') throw new Error('Missing draft state.');
  if (result.command === 'readerImages' && typeof result.enabled !== 'boolean') throw new Error('Missing image setting.');
  if (result.command === 'flushed' && (!result.requestId || typeof result.ok !== 'boolean')) throw new Error('Missing save result.');
  return result;
}
function trustedWorkspaceSender(event, contents) {
  return Boolean(contents && event.sender === contents && event.senderFrame === contents.mainFrame && event.senderFrame?.url === WORKSPACE_URL);
}
function clampBounds(bounds, size) {
  const x = Math.max(0, Math.min(size[0], bounds.x));
  const y = Math.max(0, Math.min(size[1], bounds.y));
  return { x, y, width: Math.max(0, Math.min(size[0] - x, bounds.width)), height: Math.max(0, Math.min(size[1] - y, bounds.height)) };
}
module.exports = { WORKSPACE_URL, noteCommands, validateWorkspaceCommand, trustedWorkspaceSender, webURL, clampBounds };
