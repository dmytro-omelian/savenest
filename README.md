# SaveNest for Mac

A free, MIT-licensed Mac app for saving and finding browser pages from one **⌘O launcher**, built with Electron and a local Swift helper. No account or subscription is required for local features.

[Website](https://savenest.app) · [Privacy](https://savenest.app/privacy) · [Contributing](CONTRIBUTING.md) · [Launch status](docs/launch-status.md) · [Security](SECURITY.md)

Press **⌘O**, then type. Commands, open tabs, saved links, notes, tags, and recent browser history share one search. **Enter** runs the selected command, switches to an open tab, or opens a saved/visited page. **⌘K** shows actions for that result. Pasting a URL offers **Save this link**. Saving with a note and choosing multiple tabs happen inside the same panel.

The floating launcher opens on the display containing the pointer, including over fullscreen apps, and stays out of the Dock. Click elsewhere to hide it. Escape closes actions, goes back from an editor or scope, then dismisses root search. Unsaved edits require an explicit discard. The launcher remembers context for 60 seconds; after that it resets root search unless a draft is open. **⌘O** toggles it. The old **⌘⇧O** default migrates automatically; custom shortcuts remain unchanged and can be edited through the searchable Settings command.

Account, Settings, sharing, and system dialogs retain their native implementation and are reachable from root search. Optional email sign-in and existing billing management are handled by savenest.app; links and notes remain local. Existing saved links and Keychain sessions use the same storage, with no conversion. Settings → Appearance changes both interfaces. [Design rationale and primary-source research](docs/launcher-design.md).

### Browser history

History search reads local Chrome/Chromium-family, Firefox, and Safari databases without modifying them. It indexes up to 2,000 recent records per profile from the last 90 days, across at most 30 profiles, with a 20,000-URL memory cap. Standard profile locations for Chrome/Beta, Brave, Edge, Arc, Vivaldi, Chromium, Opera, Firefox, and Safari are supported. External/custom profile locations and Safari profile layouts outside the standard history database are not scanned.

History remains in memory, is never uploaded or exported, and is refreshed on opening (at most once per minute) or explicitly via **Refresh tabs and history**. Failed reads clear that source’s old results and show an access/format error. **Browser history sources** shows connected profiles and a pause control that cancels reads and clears the cache. macOS may require file access for protected browser folders; SaveNest does not change those permissions.

A URL found in multiple sources becomes one result with its source labels. If it is open, Enter switches to that tab. Separate open instances remain distinct so profiles/windows are not confused. Title and keyword relevance rank before page-context matches; abbreviated single-word titles are also supported. History-only results can be saved, annotated, or opened like other pages.

## Run

Requires macOS 14 or later, Node.js 22.12+ with npm, and Apple's Swift command-line tools (Swift 5.9+).

```sh
npm ci
npm start
```

`npm start` builds the native helper and launches Electron with the existing library. Quit other copies of SaveNest first. Closing the window keeps the app in the menu bar; Quit also stops the helper and global shortcuts.

```sh
npm run preview       # Sample library in memory; no browser capture or analytics
swift run SaveNestChecks # Core data, privacy, authentication and browser checks
npm test              # Electron command, sender, launcher and updater checks
npm run test:smoke    # Real Electron + native helper, using sample data
npm run build         # Local macOS application in dist/SaveNest-darwin-<architecture>/
```

The smoke test covers root commands, scoped/page-context/history search, URL capture, inline note capture, multi-tab selection, dirty-draft protection, keyboard actions, history pause/resume, archive/restore, delete/undo, save-and-close, literal rendering of untrusted titles, renderer isolation, window toggling, and helper shutdown. It writes `build/launcher-preview.png` and `build/launcher-actions.png`. Preview uses sample visits and never reads real browser history or registers global shortcuts.

The ordinary `npm run build` output is a **local development build** for the current architecture. Maintainers use the signed Electron release workflow below for public distribution. Sparkle is disabled in the helper so it cannot replace Electron with a legacy native release. Existing `scripts/package-release.sh` packages only the legacy native application.

### Electron boundaries

- The renderer loads four fixed bundled assets through `savenest-ui://app`, with a restrictive content policy, process sandboxing, context isolation, and no Node access. All navigation, popups, webviews, and permission requests are blocked.
- A narrow preload bridge accepts validated app actions from the main frame only. Login callbacks enter through the Electron main process, then pass to the native account controller for existing state/PKCE validation. Tokens never enter the renderer.
- The Swift helper remains the sole writer of `~/Library/Application Support/SaveNest/library.json`. Existing atomic writes, damaged-library protection, local write protection, tab identity checks, and local search remain in use.
- Electron includes All, Open, Saved, History, Favorites, Notes, and Archive scopes. Use **⌘K** for actions, **⌘1–9** to run a result, **⌘S** to save a page, **⌘E** to edit, **⌘N** to add, and **⌘Return** to save an editor. **Control-Tab** cycles scopes; **Shift-Space** marks a page for bulk actions.
- Email sharing, tag management, and cleanup review open in native dialogs. The primary Electron UI is a nonactivating floating panel with inline capture, editing, and selection. Row swipe gestures remain specific to the legacy native interface.

### Signed Electron releases

Maintainers with existing Apple release credentials can run:

```sh
SIGNING_IDENTITY='Developer ID Application: Dmytro Omelian (444G89GLZD)' \
NOTARY_PROFILE='savenest-notary' npm run release:electron
```

This builds both Apple Silicon (`arm64`) and Intel (`x64`) helpers and Electron apps, signs and notarizes each, and stages ZIPs plus release metadata under `build/releases/electron/<version>/`. Signable bundles live in a temporary workspace outside Desktop/iCloud to prevent file-provider metadata invalidating signatures. The local workspace path is recorded alongside the artifacts and is not published.

Verify each ZIP before publication:

```sh
node scripts/check-electron-package.mjs build/releases/electron/0.11.0/SaveNest-0.11.0-macOS-arm64.zip arm64
node scripts/check-electron-package.mjs build/releases/electron/0.11.0/SaveNest-0.11.0-macOS-x64.zip x64
```

Publish versioned ZIPs to the matching GitHub release only after verification. Copy each architecture's `RELEASES.json` to the website at `/downloads/electron/<architecture>/RELEASES.json`, after its referenced public ZIP exists. Update the download page and architecture choices together. Do not overwrite a published version's ZIP or advertise an artifact that is still private.

**Check & Download Updates…** uses Electron's signed macOS updater and a separate architecture-specific feed. Checks and downloads are user-initiated. Installation/restart requires confirmation and a fresh check that no native or launcher draft/work is active. Squirrel verifies the downloaded application's signing identity. The old native Sparkle feed remains separate; native users quit the old app and download the Electron release manually. Both use the same local library and Keychain services, and startup rejects a second library writer.

Build/signature/notarization checks do not substitute for Intel runtime testing or an installed-to-installed update test. Record those separately in the release issue.

To run the retained native application directly, use `./scripts/build-app.sh` and `open build/SaveNest.app`. The remaining sections document the native services and legacy interface in detail.

## Free, Cloud, and accounts

**SaveNest Free** includes every local feature: unlimited saves within your Mac’s storage, notes, tags, search, browser tools, imports, exports, and existing sharing. Saving and editing work offline and without an account. Damaged-library protection still prevents overwriting an unreadable library.

**SaveNest Cloud** is planned at **$4.99/month or $49.90/year** for optional, end-to-end encrypted backup, sync across Macs, and recovery. It is **not available yet**, and new checkout is disabled. No cloud storage capacity, retention period, or delivery date is promised. Team collaboration is a separate future offering; [book a demo](https://cal.com/dmytro-omelian/savenest-demo) to discuss your workflow.

The desktop source, including future cloud-client code, uses MIT. The hosted backend is separate and is not included here. You do not need server credentials or a production account to build or use the desktop app.

Account is optional and remains available to manage existing billing. Email sign-in uses one-use state and PKCE; tokens stay in macOS Keychain, outside renderer state and library exports. Signing out keeps all local features available. The server remains responsible for billing state; a browser redirect never grants a paid service entitlement.

The launch transition stops existing renewals during the gap, credits unused prepaid time, and preserves previous monthly/yearly rates for an explicit future Cloud upgrade. See the [launch tracker](https://github.com/dmytro-omelian/savenest/issues/13) for verified rollout status. Do not interpret this source change as evidence that live billing has already been migrated.

## Capture

1. Open a normal web page in Safari or a supported Chromium browser.
2. Press **⌘⇧K**. On first use, macOS asks whether SaveNest may automate that browser. Allow it to enable capture. If denied, use System Settings → Privacy & Security → Automation.
3. The tab's title and URL are saved locally. Quick Save can also attach up to three existing tags learned from your saved links. A small top-right confirmation appears; the browser keeps focus and its tabs stay open. Capture errors appear in the same place for eight seconds, with a clear reason and an Automation Settings action when permission is needed. They never open the library or a modal dialog. You can preview the popup in Settings.

Use **SaveNest → Settings** (**⌘,**) to record each shortcut separately:

| Action | Default shortcut |
| --- | --- |
| Save current link | ⌘⇧K |
| Save with a note | ⌘⌥K |
| Save selected tabs | ⌘⌃⇧K |
| Save all tabs in the current window | ⌘⌥⇧K |
| Open SaveNest launcher | ⌘O |
| Close duplicate tabs | ⌘⇧D |

Settings → **After saving** can close the source tab after Save link or Save with a note. Save-only is the default; your choice is remembered. Closing happens only after a successful library write or confirmed editor save (including a link already saved), and only for the originally captured browser tab. A navigated, missing, or ambiguous tab is left open with a saved-but-not-closed notice. Selected-tab and whole-window capture always keep tabs open.

Your previously configured quick-save shortcut is preserved. Choose a key with Command, Option, or Control. Escape cancels recording. Conflicts with another SaveNest action are rejected; an unavailable system shortcut leaves the previous binding unchanged. Each row has its own reset button.

Save with a note reads the browser link first, then opens only a small editor without activating SaveNest or raising the library. The editor includes both the note and tags, with the note focused. For new links, SaveNest can pre-fill up to three existing tags from repeated patterns in the page title and exact website host. Quick Save uses the same learning and applies those tags silently; clipboard and open-tab single-link saves do too. Suggestions come only from links and tags already stored on this Mac; they remain editable later and never use a cloud model. Auto-tagging is on by default and can be disabled in Settings. **⌘Return** saves and **Escape** cancels. Nothing in the note editor is saved until you confirm. Capturing an existing link opens its existing note and tags without adding automatic tags; saving updates that link without losing its original date or archive state. A second capture while editing brings the existing draft forward instead of discarding it.

Selected-tab capture opens a checklist of the web tabs in the current browser window and saves only the checked tabs. Bulk capture saves every web tab in that window. Neither action extracts hyperlinks from a page or closes tabs. The menu bar and File menu expose the capture actions as well.

The foreground supported browser takes priority. From SaveNest or another non-browser app, capture uses the last active supported browser (remembered across restarts). On a cold start, visible browser windows or a single running browser provide a fallback. Known unsupported foreground browsers get a specific message rather than capturing a different browser.

Direct capture adapters: Safari, Safari Technology Preview, Chrome, Chrome Beta, Brave, Edge, Arc, Vivaldi, Chromium, and Opera. These rely on each browser's scripting support; not all adapters have been exercised on this machine. Firefox doesn't expose the same tab scripting interface: copy a URL and use **+ → Paste URL** or **⌘N**.

## Clipboard, importance, and usage counts

Settings → Clipboard → **Offer to save copied links** is off by default. Enable it to offer Save or Add note when you copy a single HTTP(S) URL. Monitoring starts with the next clipboard change; it ignores previously copied contents, prose, credentials in URLs, private/transient/generated pasteboard types, and links already saved (including Archive). The offer lasts 12 seconds and never takes keyboard focus. It saves the URL shown by that offer even if you copy something else. Turning monitoring off dismisses any offer. **Save copied link** in File or the menu bar works without continuous monitoring. No account or subscription is needed.

The **Review importance** rail button is visible but disabled while this feature is being redesigned.

Settings also offers an optional shortcut preset: **⇧⌘K** saves and **⇧⌘N** adds a note with optional tags. Existing bindings are retained until selected; a registration conflict rolls back the entire preset. Every binding remains configurable.

**Share anonymous usage counts** is enabled by default, announced by a dismissible library banner, and can be turned off in Settings or directly from the banner. Every 60 seconds, the app sends only fixed event names/counts to `https://savenest.app/api/usage`. It includes no account token, cookie, persistent installation/device identifier, URLs, titles, note text, tag names, clipboard contents, or importance choices. A fresh random batch ID prevents counting one upload twice. Turning reporting off clears pending counts, cancels in-flight requests, and discards the session. Events remain in memory only; offline, failed, short sessions, and shutdown activity may be missed. Reporting does not block saving. Counts already sent cannot be associated with an individual for deletion.

The service aggregates by UTC day, retaining approximately 90 days of counts and seven days of upload receipts. Ordinary network information (including IP address) reaches the hosting provider but is not stored in the usage tables. These are best-effort action totals, not unique-user, retention, or revenue metrics. In Settings → Anonymous usage, the verified owner account `dima@omelabs.org` can load the last 30 days; server authorization independently enforces that exact identity. Preview mode sends no analytics and does not monitor the clipboard.

## Browser tab adapters

Open tabs participate in the main **⌘O** search. Choose **Search open tabs** or the Open tabs scope to narrow results. Titles rank above URLs and browser names. Results refresh on opening; cached pages remain searchable while browsers respond. Safari and the supported Chromium adapters expose tabs across scriptable windows and profiles. Hidden Safari tab groups, Firefox tabs, and embedded browser views are not included. Firefox history is supported separately. Use **⌘S** or **⌘K → Save to library** to save a tab without switching browsers. Tab titles and URLs remain in memory unless explicitly saved.

**⌘⇧D** closes exact duplicate web addresses within each supported browser window and removes known empty/new-tab pages. It keeps an active duplicate when the browser exposes that state and otherwise keeps the first copy. Separate windows and browser profiles are left independent, URLs with different queries or fragments remain separate, and tabs that move or navigate before closing are left open. This shortcut overlaps Chromium’s Bookmark all tabs command and can be changed in Settings.

## Native library interface (legacy reference)

- A floating rail gives direct access to Library, Tags, open-tab search, Add link, Account, and Settings. Date groups sit in rounded cards; notes and tags stay with their links. Editors, onboarding, capture feedback, and tab search share the selected appearance.
- Links are grouped by local calendar date, newest first.
- Website icons replace letter tiles when available. New captures retain the page’s icon URL; older links use the site favicon or public homepage icon. Requests use no browser cookies or favicon proxy, run in the background (six at a time), and cache locally for seven days. Missing icons keep the letter fallback.
- Click a title to open it in your default browser; click a note preview to edit it. Row actions become more prominent on hover.
- Swipe left with two fingers to reveal Delete and Archive (Restore inside Archive); a long left swipe performs Archive. Swipe right for Email and Copy. Escape closes revealed actions. All actions are also in the row menu.
- Email opens a preview with an editable subject and an optional note (off by default). Include a note starts from your saved note without changing it. Open Mail prepares a draft; you choose the recipient and send it.
- “Archive all links…” in Settings → Your library clears the active library after confirmation. Both individual and bulk archive/restore offer Undo in the footer for the last action.
- “Empty archive…” lives inside Archive. It confirms the count before permanently deleting archived links, notes, and tags. Links outside Archive, restored links, and links added after the confirmation opened are kept.
- Search titles, full URLs, notes, tags, and archived links with **⌘F**. Search starts in Everywhere; scope it to Library, Favorites, Notes, or Archive when needed. Archived matches are labeled. All keywords must match somewhere and results are ranked by relevance. Use **#tag** to match a single-word tag exactly.
- Refine results by tag, website, or whether a note is present. The same filters work inside Archive.
- Add tags with Return or commas, press Tab to accept the first matching suggestion, and click a tag to remove it. Suggestions mirror lowercase or leading-uppercase input; automatic tags follow the casing used by most existing tags. Saving includes any unfinished tag input; **⌘Return** saves the editor.
- Existing libraries and backups without tags load automatically; notes and saved dates are preserved.
- A row’s **…** menu has copy, note/tag editing, Delete, and archive.
- **⌘Z** restores the last library change. Text fields keep standard typing undo.
- A long swipe grows and highlights its direct action, then labels it before release applies it: Copy to the right, Archive or Restore to the left.
- Account and Settings are in the right-hand rail. The library header only shows the local status; individual links retain their **…** menus. Archived links can be restored.
- Duplicates are skipped without overwriting existing notes or dates.
- Internal browser pages, local files, and URLs with embedded credentials are skipped.
- Settings can export and merge-import JSON backups.

Data lives at `~/Library/Application Support/SaveNest/library.json`. Writes are atomic. If loading fails, the original file is left intact and further writes are blocked, so a damaged or newer-format library cannot be silently overwritten. Restore a valid backup at that path and restart the app to recover.

## Better titles

Capture attempts a fixed, read-only script in the captured page to read Open Graph/Twitter metadata and, for a matching social post permalink, the post text. X extraction matches the current status ID so a reply or promoted post does not become the title. No metadata is sent to another service, and SaveNest does not change the browser’s security preferences.

Browsers may block this unless **Allow JavaScript from Apple Events** is enabled by the user. Browser Automation access and this JavaScript setting are separate. If metadata is blocked, unavailable, or a page navigates during capture, SaveNest retains a useful native title or builds a descriptive fallback from the URL (for example `@anna on X · 123` or `Instagram reel · ABC123`). Login-only pages and changing social site markup can limit results. These fallbacks identify the link; they do not invent a caption. A captured title can always be edited.

## Checks

```sh
swift run SaveNestChecks
node scripts/check-metadata.mjs
node scripts/check-tab-close.mjs
node scripts/check-browser-tabs.mjs
```

Forty Swift checks cover library persistence, dates, browser selection, legacy migration, tags and tag sorting, hybrid auto-tagging, tag completion, keyword ranking, tab-cleanup planning, domain scoping, annotation updates, title fallback, paid-access expiry, subscription payment recovery, delayed automatic access checks, polling timeout/cancellation, and forged, mismatched, or replayed native callbacks. Nineteen tab-close checks cover successful and batch close, changed or closed windows/tabs, duplicate Safari URLs, and Chromium tab identity after reordering. Ten browser-tab checks cover mixed browser identity types, cleanup discovery, multiple profile windows with identical URLs, complete result lists, tab switching after reordering, navigation guards, and permission errors. Six additional Node checks execute the actual page reader against DOM fixtures, including unrelated posts and feed pages. The runner works with Command Line Tools alone; it does not require Xcode's XCTest framework.

Run `./scripts/preview-app.sh` to open a separate **SaveNest Preview** app with an in-memory sample library. The preview has its own app identity, does not register account callbacks, and does not load or write the saved library or register global shortcuts. The fixture is also available by running `.build/debug/SaveNest --ui-preview` directly from a terminal.

## Legacy native distribution

This repository produces a local development build. Public downloads need a Developer ID signature and Apple notarization. The build script accepts `SIGNING_IDENTITY` for your Developer ID certificate. It embeds the Automation entitlement and browser-access usage description. No developer credentials are included.

The companion website is in `../savenest` and provides email sign-in, account management, Stripe checkout, and downloads. Bookmark sync is not included: the library remains on the Mac, and an account does not upload existing links.

### In-app updates

Release builds use Sparkle 2.10.0. **Check for Updates…** is available in the SaveNest application menu, the menu bar icon, and **Settings → App updates**, alongside the version/build and **Automatically check for updates** switch. Sparkle asks for permission for automatic checks on the second launch; it remembers the user's choice and checks daily when enabled. Downloads and installation require user action. Sparkle's system profiling is disabled. Updates do not require sign-in or an active subscription.

The feed is `https://savenest.app/downloads/appcast.xml`. Sparkle verifies update archive signatures before installation, replaces the application, and relaunches it. Library data remains in Application Support. Development builds from `build-app.sh`, ad-hoc release previews, and SaveNest Preview disable updates; the preview never creates a Sparkle updater. The build scripts embed and sign the framework and each helper, preserving their entitlements and symlinks.

Version 0.9.3 (build 26) introduces the updater. Users on 0.9.2 or earlier need one manual installation. Publishing a feed alone cannot add an updater to their old app.

### Publish a new version

1. Bump the version and monotonically increasing build number (the build number determines update order):

   ```sh
   ./scripts/set-version.sh 0.9.5 28
   ```

2. Add release notes at `Resources/ReleaseNotes/0.9.5.html`. Use an HTML fragment, such as `<h2>What's new</h2><ul><li>…</li></ul>`; Sparkle embeds it in the feed.
3. Build the universal, Developer ID signed, notarized update:

   ```sh
   SIGNING_IDENTITY='Developer ID Application: Dmytro Omelian (444G89GLZD)' \
   NOTARY_PROFILE='savenest-notary' \
   ./scripts/package-release.sh
   ```

   The script validates the notarization profile and Sparkle signing key first, signs the framework and helpers, notarizes and staples the app, then generates the signed archive entries in `build/releases/updates/appcast.xml`. ZIPs, release notes, and `release.json` live in that same directory. Existing versioned ZIPs are never overwritten. Only notarized releases enter the update feed. Ad-hoc packaging (`ALLOW_ADHOC=1`) writes separately to `build/releases/previews` and never generates a public feed.

4. Copy the versioned ZIP, release notes, `appcast.xml`, and `release.json` to the companion website's `public/downloads/`. Its `/download/macos` redirect reads the manifest's filename automatically. Publish via the website's deployment workflow. Upload archives before the feed if deployment is not atomic. Keep existing published archives available. Serve the feed over HTTPS with a short cache lifetime or revalidation. The generated files are local artifacts until this step completes.
5. Check both the website download and **Check for Updates…** from an older updater-enabled release. Verify download, install, relaunch, and preserved library/settings. Test on an installed app outside the build directory; users on the current build should see “up to date.” Do not downgrade the production feed to test.

Before publishing, check the package and its update metadata with `python3 scripts/check-update-package.py build/releases/updates/SaveNest-0.9.5-macOS.zip` (use the version being released). This uses a temporary feed and verifies both valid signatures and rejection of a modified archive. It also works on an ad-hoc preview ZIP; it never publishes the test feed or installs the app.

### Signing key and a new release Mac

The Sparkle Ed25519 private key is stored in the login Keychain under account `app.savenest.mac`; only its public key is committed as `SUPublicEDKey` in `Resources/Info.plist`. Back up that private key securely before migrating or erasing this Mac. It is separate from the Apple Developer ID certificate and notarization credentials.

After `swift package resolve`, Sparkle's `generate_keys`, `sign_update`, and `generate_appcast` tools are in `.build/artifacts/sparkle/Sparkle/bin/`. To inspect the existing public key:

```sh
.build/artifacts/sparkle/Sparkle/bin/generate_keys --account app.savenest.mac -p
```

Use Sparkle's documented key export/import process to transfer the existing private key to another release machine. Never commit private key exports. Do not generate a replacement key for each release: the packaging script requires the Keychain public key to match the app's committed public key. `SPARKLE_KEY_ACCOUNT` can select another Keychain account containing the same key. Apple notarization profiles are created separately with `xcrun notarytool store-credentials`.

See [Sparkle setup](https://sparkle-project.org/documentation/) and [publishing updates](https://sparkle-project.org/documentation/publishing/) for details.
