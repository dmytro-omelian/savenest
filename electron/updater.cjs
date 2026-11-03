'use strict';

function feedURL(architecture) {
  if (!['arm64', 'x64'].includes(architecture)) return null;
  return `https://savenest.app/downloads/electron/${architecture}/RELEASES.json`;
}

function canRestartSafely({ view, state, failed = false }) {
  return !failed && state?.canRestartForUpdate === true && !state.busy &&
    !['editor', 'selection'].includes(view) && !state.captureDraft && !state.captureSelection;
}

// Squirrel validates the downloaded application's signing identity. The feed is
// separate from the native Sparkle feed and uses numeric version comparisons.
// Checks are user-initiated: no background update requests or surprise downloads.
function createUpdater({ app, autoUpdater, dialog, release = false, architecture = process.arch, canRestart = () => true, beforeInstall = () => {} }) {
  const url = feedURL(architecture);
  const enabled = Boolean(app.isPackaged && release && process.platform === 'darwin' && url);
  let busy = false, downloaded = false, prompting = false;
  const show = options => dialog.showMessageBox({ type: 'info', buttons: ['OK'], ...options });
  async function safeToRestart() {
    try { return await canRestart() === true; } catch { return false; }
  }
  async function offerInstall() {
    if (prompting) return;
    prompting = true;
    try {
      if (!await safeToRestart()) {
        await show({ message: 'Update downloaded', detail: 'Finish saving your draft. The update will install the next time you quit SaveNest.' });
        return;
      }
      const result = await show({ message: 'SaveNest is ready to update',
        detail: 'Your local library and settings will be kept. Install and restart now, or install on your next quit.',
        buttons: ['On next quit', 'Install & restart'], defaultId: 0, cancelId: 0 });
      if (result.response === 1 && await safeToRestart()) { beforeInstall(); autoUpdater.quitAndInstall(); }
    } finally { prompting = false; }
  }
  if (enabled) {
    autoUpdater.setFeedURL({ url, serverType: 'json' });
    autoUpdater.on('error', () => {
      busy = false;
      void show({ type: 'warning', message: 'Couldn’t check or download the update', detail: 'Your installed app and local library are unchanged. Check your connection and try again.' });
    });
    autoUpdater.on('update-not-available', () => {
      busy = false;
      void show({ message: 'You’re up to date', detail: `SaveNest ${app.getVersion()} is the latest available release.` });
    });
    autoUpdater.on('update-downloaded', () => { busy = false; downloaded = true; void offerInstall(); });
  }
  return {
    enabled,
    async check() {
      if (!enabled || busy) return;
      if (downloaded) return offerInstall();
      busy = true;
      try { autoUpdater.checkForUpdates(); }
      catch { busy = false; await show({ type: 'warning', message: 'Couldn’t start the update check', detail: 'Try again from an installed release in Applications.' }); }
    }
  };
}

module.exports = { feedURL, createUpdater, canRestartSafely };
