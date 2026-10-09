# SaveNest for Mac

A small native Mac app for saving browser tabs. Press **⌘⇧K**, keep browsing, and find your links later in a quiet list grouped by **Today**, **Yesterday**, and older dates.

Built with SwiftUI and AppKit. Email sign-in and Stripe subscriptions are managed by savenest.app; links and notes remain local. No analytics, browser extension, or third-party Swift packages. Matches the cream and sage palette of [savenest.app](https://savenest.app).

## Run

Requires macOS 14 or later and Apple's Swift command-line tools (Swift 5.9+).

```sh
./scripts/build-app.sh
open build/SaveNest.app
```

The script creates an ad-hoc-signed app for the current Mac architecture. Move `build/SaveNest.app` to Applications if you want to keep it installed. Launch the app at least once before using its shortcut. Closing the library leaves SaveNest running in the menu bar; Quit stops capture.

## Account and beta pricing

Choose **SaveNest → Account**, enter your email in the app, and choose **Email me a sign-in link**. Open the email on the same Mac and confirm it; the browser returns to SaveNest automatically. There is no password. The app stores its session token and the short-lived pending sign-in only in macOS Keychain, never in library backups or preferences. This pending request survives an app restart and can be completed by another installed copy of SaveNest, which avoids losing sign-in when macOS routes the link to a different copy.

Saving requires an active subscription:

- **SaveNest:** $1.99/month. One plan includes every feature; cancel anytime.

Plan selection stays in the Account screen. SaveNest opens Stripe only for the secure card/payment step, then the website returns to the app and SaveNest checks access automatically for up to one minute. A manual **Refresh access** remains available if Stripe confirmation is delayed. A **Sandbox · test payments only** label identifies a Stripe sandbox account. Use card `4242 4242 4242 4242`, any future expiration, and any CVC; no real payment is taken in sandbox.

The server checks paid access; a checkout redirect alone does not unlock the app. The app rechecks before saving when the last successful check is more than two minutes old, after the paid period ends, and when returning to the app. No subscription entitlement is saved to disk. Network failures after that brief in-memory lease prevent new saves until verification succeeds. Existing links remain available to open, search, copy, archive, delete, and export when signed out or unsubscribed. Saving new links, notes, tags, title edits, and imports requires verified access.

The API is fixed to `https://savenest.app`. The browser callback carries a single-use authorization code and state, exchanged with a cryptographically random PKCE verifier. A magic link opened in any browser returns through the app URL handler and must match the Keychain-backed, one-use sign-in state. Checkout and billing returns have their own account-bound, expiring state. Cancelling clears the relevant pending state. Unsolicited callbacks and replays are ignored. Native bearer requests do not follow redirects. Private Stripe and email keys stay on the website server. Signing out revokes the current server session when online and removes the local token.

## Capture

1. Open a normal web page in Safari or a supported Chromium browser.
2. Press **⌘⇧K**. On first use, macOS asks whether SaveNest may automate that browser. Allow it to enable capture. If denied, use System Settings → Privacy & Security → Automation.
3. The tab's title and URL are saved locally. A small top-right confirmation appears; the browser keeps focus and its tabs stay open. Capture errors appear in the same place for eight seconds, with a clear reason and an Automation Settings action when permission is needed. They never open the library or a modal dialog. You can preview the popup in Settings.

Use **SaveNest → Settings** (**⌘,**) to record each shortcut separately:

| Action | Default shortcut |
| --- | --- |
| Save current link | ⌘⇧K |
| Save with a note | ⌘⌥K |
| Save with tags | ⌘⌃K |
| Save selected tabs | ⌘⌃⇧K |
| Save all tabs in the current window | ⌘⌥⇧K |
| Search open tabs | ⌘⇧O |

Your previously configured quick-save shortcut is preserved. Choose a key with Command, Option, or Control. Escape cancels recording. Conflicts with another SaveNest action are rejected; an unavailable system shortcut leaves the previous binding unchanged. Each row has its own reset button.

Note and tag capture read the browser link first, then open a small editor with the appropriate field focused. Both note and tags are available in either editor. **⌘Return** saves and **Escape** cancels. Nothing is saved until you confirm. Capturing an existing link opens its existing note and tags; saving updates that link without losing its original date or archive state. A second capture while editing brings the existing draft forward instead of discarding it.

Selected-tab capture opens a checklist of the web tabs in the current browser window and saves only the checked tabs. Bulk capture saves every web tab in that window. Neither action extracts hyperlinks from a page or closes tabs. The menu bar and File menu expose all five capture actions as well.

The foreground supported browser takes priority. From SaveNest or another non-browser app, capture uses the last active supported browser (remembered across restarts). On a cold start, visible browser windows or a single running browser provide a fallback. Known unsupported foreground browsers get a specific message rather than capturing a different browser.

Direct capture adapters: Safari, Safari Technology Preview, Chrome, Chrome Beta, Brave, Edge, Arc, Vivaldi, Chromium, and Opera. These rely on each browser's scripting support; not all adapters have been exercised on this machine. Firefox doesn't expose the same tab scripting interface: copy a URL and use **+ → Paste URL** or **⌘N**.

## Open-tab search

Press **⌘⇧O** from any app to open a compact tab switcher. Search words across tab titles, URLs, and browser names; title matches rank first. **↑/↓** selects, **Return** switches to the existing tab, **⌘1–9** jumps directly, and **Escape** closes the panel. The shortcut is configurable in Settings. The list refreshes on opening and can be refreshed manually; cached results remain searchable during refresh. Safari and the supported Chromium adapters expose tabs in their open windows. Hidden Safari tab groups, Firefox, and embedded browser views are not included. Tab titles and URLs remain in memory only.

## Library

- Links are grouped by local calendar date, newest first.
- Click a title to open it in your default browser; click a note preview to edit it. Row actions become more prominent on hover.
- Search titles, URLs, notes, and tags with **⌘F**. All keywords must match somewhere; results are ranked by relevance. Use **#tag** to match a single-word tag exactly.
- Click a tag pill or use the Tags menu to filter. All, Favorites, Notes, and Archive keep the library in one compact view.
- Add tags with Return or commas, reuse suggestions, and click a tag to remove it. Saving includes any unfinished tag input; **⌘Return** saves the editor.
- Existing libraries and backups without tags load automatically; notes and saved dates are preserved.
- A row’s **…** menu has copy, note/tag editing, and archive.
- The top **…** menu opens Account or Settings. Archived links can be restored.
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
```

Seventeen Swift checks cover library persistence, dates, browser selection, legacy migration, tags, keyword ranking, tag counts, annotation updates, title fallback, paid-access expiry, subscription payment recovery, and forged, mismatched, or replayed native callbacks. Four additional Node checks execute the actual page reader against DOM fixtures, including unrelated posts and feed pages. The runner works with Command Line Tools alone; it does not require Xcode's XCTest framework.

A read-only design fixture is available in debug builds with `.build/debug/SaveNest --ui-preview`. It does not load or write the saved library or register global shortcuts.

## Distribution

This repository produces a local development build. Public downloads need a Developer ID signature and Apple notarization. The build script accepts `SIGNING_IDENTITY` for your Developer ID certificate. It embeds the Automation entitlement and browser-access usage description. No developer credentials are included.

The companion website is in `../savenest` and provides email sign-in, account management, Stripe checkout, and downloads. Bookmark sync is not included: the library remains on the Mac, and an account does not upload existing links.
