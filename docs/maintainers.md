# Maintainer notes

These notes cover official SaveNest distribution. Contributors only need the [development setup and checks](../CONTRIBUTING.md); no release credentials are required.

## Build boundaries

- `npm run build` produces a local development app for the current architecture under `dist/`.
- `npm run release:electron` stages signed, notarized Apple Silicon and Intel apps using existing maintainer credentials. It does not publish them.
- `scripts/package-release.sh` belongs to the retained native app and Sparkle update system. It must not be used to publish an Electron update.

Keep local libraries, signing material, credentials, generated archives, and local staging paths out of Git.

## Official Electron distribution

1. Complete the relevant checks in [CONTRIBUTING.md](../CONTRIBUTING.md) and review the [preview acceptance checklist](preview-acceptance.md). Passing build checks does not establish installed-app migration, Intel runtime, or update behavior.
2. Keep `package.json`, `package-lock.json`, and `Resources/Info.plist` versions consistent, with an increasing native build number. Add release notes under `Resources/ReleaseNotes/`.
3. On the release machine, set `SIGNING_IDENTITY` and `NOTARY_PROFILE` to existing credentials, then run `npm run release:electron`. Never commit their values or key material.
4. Validate both staged ZIPs with `node scripts/check-electron-package.mjs <zip-path> <architecture>`, using `arm64` and `x64` respectively. Artifacts and metadata are staged under `build/releases/electron/<version>/`.
5. Publish verified ZIPs to the matching GitHub release. After the public archives exist, publish each architecture's `RELEASES.json` to `/downloads/electron/<architecture>/RELEASES.json` on the website. Update download links and architecture choices together. Never overwrite a published version's archive.
6. Verify public downloads and update metadata, then record installed-app results in the [release issue](https://github.com/dmytro-omelian/savenest/issues/18). Keep untested items open.

Signing uses a temporary workspace outside synced Desktop/iCloud folders, where file-provider metadata can invalidate signatures. The packaging script records this local staging path beside the artifacts; it is not a public asset.

## Update safety

Electron checks and downloads updates only when requested. Installation/restart requires confirmation and a fresh check that no launcher or native draft is active. Squirrel verifies the downloaded app's signing identity. The Swift helper's Sparkle updater is disabled in Electron builds.

The old native Sparkle feed remains separate. Native users export a backup, quit the old app, and manually install the Electron preview. Both use the same library path and Keychain services; startup rejects a second library writer. Full installed-app migration acceptance remains pending.

Retain the existing Sparkle signing key and public-key identity for legacy maintenance. Never generate replacement keys per release or point the legacy feed at an Electron archive. The [native reference](legacy-native.md) documents the older interface and updater.

The [launch tracker](https://github.com/dmytro-omelian/savenest/issues/13) is the source for rollout status. Publishing a preview does not mark full launch complete.
