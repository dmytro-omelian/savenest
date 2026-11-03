# Signed preview acceptance

Version 0.11.0 is a preview. Keep the full launch open until the following checks pass in a separate macOS user account or VM with a disposable library. Do not use a person's primary library or Keychain to fill a testing gap.

## What automated checks establish

- Clean-clone CI installs dependencies, runs core checks and Electron tests, and compiles the native app without production credentials.
- Temporary-file tests verify real library write/read equality, Unicode and notes, archive state, damaged-file preservation, and rejection of future format versions.
- Legacy JSON fixtures verify older optional fields can be decoded. They do not test an installed-app migration.
- Electron smoke tests run the real UI and helper with sample data. Preview writes are in memory, so they do not establish disk persistence or offline import/export.
- Release validation checks architectures, matching app/helper versions, signatures, notarization tickets, Gatekeeper, bundled licenses, and rejection of tampered resources.

## Remaining manual checks

- [ ] In the isolated account, create a disposable library using the previously distributed native app. Include notes, Unicode, tags, collections, favorites, archived items, and custom shortcuts. Export a backup.
- [ ] Quit the old app, install the matching signed preview, and confirm every field and shortcut survives. Restart and compare the library and exported data.
- [ ] While signed out, block network access and save/edit/delete/undo local items. Import and export through the native file dialogs; restart and verify persisted data. Repeat with an unsubscribed test account when one is available.
- [ ] Exercise browser capture with permission allowed and denied. Pause history and verify indexed history disappears. Check that unsaved browser activity is absent from the exported library.
- [ ] Observe requests in the isolated environment. Turn anonymous reporting off, create events, and verify no further usage transmissions occur; compare actual requests to the published policy.
- [ ] Run the Intel build on Intel hardware or an appropriately configured environment. Architecture/signature checks alone are insufficient.
- [ ] Install a newer signed Electron build through its feed. Confirm signature rejection for invalid updates, explicit restart, draft protection, and library preservation. Do not redirect the old native Sparkle feed to an Electron archive.

Record version, architecture, OS version, steps, result, and issue links. Check off only observed results. [Release issue #18](https://github.com/dmytro-omelian/savenest/issues/18) and [launch tracker #13](https://github.com/dmytro-omelian/savenest/issues/13) track the remaining work.
