'use strict';
const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('savenest', Object.freeze({
  command: input => ipcRenderer.invoke('savenest:command', input),
  onEvent: callback => {
    const listener = (_event, value) => callback(value);
    ipcRenderer.on('savenest:event', listener);
    return () => ipcRenderer.removeListener('savenest:event', listener);
  }
}));
