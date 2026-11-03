# Contributing to SaveNest

SaveNest is a free, local Mac app. Contributions to its desktop source are welcome under the MIT license. Hosted Cloud services are a separate future product; the public desktop does not need production credentials or a paid account.

## Start here

Check [open issues](https://github.com/dmytro-omelian/savenest/issues) and the [launch tracker](https://github.com/dmytro-omelian/savenest/issues/13) before starting substantial work. Describe the user problem and intended behavior in an issue. Small bug fixes can go straight to a pull request. A proposal is not a promise that it will be built.

## Run and check

Requirements: macOS 14+, Apple's command-line tools with Swift 5.9+, and Node.js 22.12+.

```sh
npm ci
swift run SaveNestChecks
npm test
npm run preview
npm run test:smoke
```

Preview uses sample data. It must never read your real browser history, write your library, register global shortcuts, or send analytics. The smoke check drives the real Electron and Swift helper with that sample data. `swift run SaveNestChecks` is this project's core test runner; it is not an XCTest target.

Use `npm start` for normal local development with your real library. Quit other SaveNest copies first. Export a backup before testing changes against real data. Public signing and notarization require maintainer credentials and are not needed for development.

If the checkout has moved and Swift reports artifact paths from its old location, regenerate the disposable `.build` directory. Do not change source paths to match stale build metadata.

## Pull requests

Explain the problem, resulting behavior, and checks actually run. Keep the change focused. Include screenshots for visible UI changes. Add regression coverage for data loss, authorization, privacy, or other meaningful behavioral risks. Distinguish preview/mocked checks from real-browser or installed-release checks.

Preserve local data compatibility and offline use. Do not put local saving, editing, import, or export behind account or subscription checks. Browser history and unsaved page context remain local and ephemeral. Keep renderer isolation and validate all commands crossing process boundaries.

Never commit credentials, real user libraries, browser databases, personal screenshots, signing material, or generated build artifacts. Report security problems privately as described in [SECURITY.md](SECURITY.md).

By submitting a contribution, you confirm you have the right to contribute it under this repository's MIT license. No separate contributor agreement is required.
