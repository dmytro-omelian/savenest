# SaveNest for Mac

A small native Mac app for saving browser tabs. Press **⌘⇧K**, keep browsing, and find your links later in a quiet list grouped by **Today**, **Yesterday**, and older dates.

Built with SwiftUI and AppKit. Email sign-in and Stripe subscriptions are managed by savenest.app; links and notes remain local. Optional anonymous usage counts help improve the app; there is no browser extension. Sparkle handles signed in-app updates. Rounded library cards and a floating action rail take their visual direction from [One](https://getone.one). Settings → Appearance offers the original cream and sage palette or the charcoal and emerald palette; black is the default. The choice applies immediately throughout the app and is remembered across launches.

## Run

Requires macOS 14 or later and Apple's Swift command-line tools (Swift 5.9+).

```sh
./scripts/build-app.sh
open build/SaveNest.app
```

The script creates an ad-hoc-signed app for the current Mac architecture. Move `build/SaveNest.app` to Applications if you want to keep it installed. Public builds launched from Downloads, a disk image, or another folder offer to move themselves to Applications and reopen there; development and Preview builds do not. Launch the app at least once before using its shortcut. Closing the library leaves SaveNest running in the menu bar; Quit stops capture.

## Account and beta pricing

Choose **SaveNest → Account**, enter your email in the app, and choose **Email me a sign-in link**. Open the email on the same Mac and confirm it; the browser returns to SaveNest automatically. There is no password. The app stores its session token and the short-lived pending sign-in only in macOS Keychain, never in library backups or preferences. This pending request survives an app restart and can be completed by another installed copy of SaveNest, which avoids losing sign-in when macOS routes the link to a different copy.

Saving requires an active subscription:

- **SaveNest:** $4.99/month for new live subscriptions. One plan includes every feature; cancel anytime. Existing $1.99 and $5 subscribers keep their price. The owner-only sandbox keeps its $1.99 test price.

Enter active promotion codes on the hosted Stripe Checkout page. Stripe shows the discount and its terms before payment. SaveNest does not accept or pre-apply codes. Existing server-confirmed BETA trials keep their recorded access, while new redemptions use the promotion terms configured in Stripe. Cancel from Account → Manage billing.

Plan selection stays in the Account screen. SaveNest opens Stripe only for the secure card/payment step, then the website returns to the app. SaveNest checks server-verified access every five seconds for up to 15 minutes after opening Stripe, even without a browser callback. Checks resume when you return to the app or reopen Account, including after a restart. Returning to the app requests fresh server access instead of the two-minute cache. A valid checkout return also retries for up to one minute if payment confirmation is delayed. **Stop waiting** cancels local checks without changing a payment; **Refresh access** remains available as a fallback and forces a server check. A **Sandbox · test payments only** label identifies a Stripe sandbox account. Use card `4242 4242 4242 4242`, any future expiration, and any CVC; no real payment is taken in sandbox.

The server checks paid access; a checkout redirect alone does not unlock the app. The app rechecks before saving when the last successful check is more than two minutes old, after the paid period ends, and when returning to the app. No subscription entitlement is saved to disk. Network failures after that brief in-memory lease prevent new saves until verification succeeds. Existing links remain available to open, search, copy, archive, delete, and export when signed out or unsubscribed. Saving new links, notes, tags, title edits, and imports requires verified access.

The API is fixed to `https://savenest.app`. The browser callback carries a single-use authorization code and state, exchanged with a cryptographically random PKCE verifier. A magic link opened in any browser returns through the app URL handler and must match the Keychain-backed, one-use sign-in state. Checkout and billing returns have their own account-bound, expiring state. Cancelling clears the relevant pending state. Unsolicited callbacks and replays are ignored. Native bearer requests do not follow redirects. Private Stripe and email keys stay on the website server. Signing out revokes the current server session when online and removes the local token.

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
| Search open tabs | ⌘⇧O |
| Close duplicate tabs | ⌘⇧D |

Settings → **After saving** can close the source tab after Save link or Save with a note. Save-only is the default; your choice is remembered. Closing happens only after a successful library write or confirmed editor save (including a link already saved), and only for the originally captured browser tab. A navigated, missing, or ambiguous tab is left open with a saved-but-not-closed notice. Selected-tab and whole-window capture always keep tabs open.

Your previously configured quick-save shortcut is preserved. Choose a key with Command, Option, or Control. Escape cancels recording. Conflicts with another SaveNest action are rejected; an unavailable system shortcut leaves the previous binding unchanged. Each row has its own reset button.

Save with a note reads the browser link first, then opens only a small editor without activating SaveNest or raising the library. The editor includes both the note and tags, with the note focused. For new links, SaveNest can pre-fill up to three existing tags from repeated patterns in the page title and exact website host. Quick Save uses the same learning and applies those tags silently; clipboard and open-tab single-link saves do too. Suggestions come only from links and tags already stored on this Mac; they remain editable later and never use a cloud model. Auto-tagging is on by default and can be disabled in Settings. **⌘Return** saves and **Escape** cancels. Nothing in the note editor is saved until you confirm. Capturing an existing link opens its existing note and tags without adding automatic tags; saving updates that link without losing its original date or archive state. A second capture while editing brings the existing draft forward instead of discarding it.

Selected-tab capture opens a checklist of the web tabs in the current browser window and saves only the checked tabs. Bulk capture saves every web tab in that window. Neither action extracts hyperlinks from a page or closes tabs. The menu bar and File menu expose the capture actions as well.

The foreground supported browser takes priority. From SaveNest or another non-browser app, capture uses the last active supported browser (remembered across restarts). On a cold start, visible browser windows or a single running browser provide a fallback. Known unsupported foreground browsers get a specific message rather than capturing a different browser.

Direct capture adapters: Safari, Safari Technology Preview, Chrome, Chrome Beta, Brave, Edge, Arc, Vivaldi, Chromium, and Opera. These rely on each browser's scripting support; not all adapters have been exercised on this machine. Firefox doesn't expose the same tab scripting interface: copy a URL and use **+ → Paste URL** or **⌘N**.

## Clipboard, importance, and usage counts

Settings → Clipboard → **Offer to save copied links** is off by default. Enable it to offer Save or Add note when you copy a single HTTP(S) URL. Monitoring starts with the next clipboard change; it ignores previously copied contents, prose, credentials in URLs, private/transient/generated pasteboard types, and links already saved (including Archive). The offer lasts 12 seconds and never takes keyboard focus. It saves the URL shown by that offer even if you copy something else. Turning monitoring off dismisses any offer. **Save copied link** in File or the menu bar works without continuous monitoring. Normal verified subscription access still applies.

The **Review importance** rail button is visible but disabled while this feature is being redesigned.

Settings also offers an optional shortcut preset: **⇧⌘K** saves and **⇧⌘N** adds a note with optional tags. Existing bindings are retained until selected; a registration conflict rolls back the entire preset. Every binding remains configurable.

**Share anonymous usage counts** is enabled by default, announced by a dismissible library banner, and can be turned off in Settings or directly from the banner. Every 60 seconds, the app sends only fixed event names/counts to `https://savenest.app/api/usage`. It includes no account token, cookie, persistent installation/device identifier, URLs, titles, note text, tag names, clipboard contents, or importance choices. A fresh random batch ID prevents counting one upload twice. Turning reporting off clears pending counts, cancels in-flight requests, and discards the session. Events remain in memory only; offline, failed, short sessions, and shutdown activity may be missed. Reporting does not block saving. Counts already sent cannot be associated with an individual for deletion.

The service aggregates by UTC day, retaining approximately 90 days of counts and seven days of upload receipts. Ordinary network information (including IP address) reaches the hosting provider but is not stored in the usage tables. These are best-effort action totals, not unique-user, retention, or revenue metrics. In Settings → Anonymous usage, the verified owner account `dima@omelabs.org` can load the last 30 days; server authorization independently enforces that exact identity. Preview mode sends no analytics and does not monitor the clipboard.

## Open-tab search

Press **⌘⇧O** from any app to open only the compact tab switcher, without activating SaveNest or raising the library. Clicking outside the switcher dismisses it. Search words across tab titles, URLs, and browser names; title matches rank first. **↑/↓** selects, **Return** switches to the existing tab, **⌘1–9** jumps directly, and **Escape** closes the panel. The shortcut is configurable in Settings. The list refreshes on opening and can be refreshed manually; cached results remain searchable during refresh. Safari and the supported Chromium adapters expose tabs in their open windows. Hidden Safari tab groups, Firefox, and embedded browser views are not included. All matching tabs from every scriptable Safari and Chrome window, including windows in different profiles, appear in one scrollable list, with ⌘1–9 shortcuts for the first nine. Use the bookmark button beside a result to save that specific tab without switching browsers; it stays open. Tab titles and URLs remain in memory unless you explicitly save a result.

**⌘⇧D** closes exact duplicate web addresses within each supported browser window and removes known empty/new-tab pages. It keeps an active duplicate when the browser exposes that state and otherwise keeps the first copy. Separate windows and browser profiles are left independent, URLs with different queries or fragments remain separate, and tabs that move or navigate before closing are left open. This shortcut overlaps Chromium’s Bookmark all tabs command and can be changed in Settings.

## Library

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

## Distribution

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
