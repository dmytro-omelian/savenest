'use strict';
const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('workspace', Object.freeze({
  request: input => ipcRenderer.invoke('savenest:workspace', input),
  onEvent: callback => {
    const listener = (_event, value) => callback(value);
    ipcRenderer.on('savenest:workspace-event', listener);
    return () => ipcRenderer.removeListener('savenest:workspace-event', listener);
  }
}));
