# SaveNest for Mac

A small native Mac app for saving browser tabs. Press **⌘⇧K**, keep browsing, and find your links later in a quiet list grouped by **Today**, **Yesterday**, and older dates.

Built with SwiftUI and AppKit. Email sign-in and Stripe subscriptions are managed by savenest.app; links and notes remain local. No analytics, browser extension, or third-party Swift packages. Rounded library cards and a floating action rail take their visual direction from [One](https://getone.one). Settings → Appearance offers the original cream and sage palette or the charcoal and emerald palette; black is the default. The choice applies immediately throughout the app and is remembered across launches.

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

- **SaveNest:** $5/month for new live subscriptions. One plan includes every feature; cancel anytime. Existing $1.99 subscribers keep their price. The owner-only sandbox keeps its $1.99 test price.

Enter a promo code in Account before opening Stripe. **BETA** gives first-time subscribers 31 days free, then $2.50/month for six monthly payments, then $5/month. **REAKTORX** gives $2.50/month for twelve months, then $5/month. Offers do not stack. Checkout shows the full terms and collects a payment method for renewal; cancel from Account → Manage billing. Free-trial access is verified by the server and expires at the trial end unless paid access succeeds.

Plan selection stays in the Account screen. SaveNest opens Stripe only for the secure card/payment step, then the website returns to the app. SaveNest checks server-verified access every five seconds for up to 15 minutes after opening Stripe, even without a browser callback. Checks resume when you return to the app or reopen Account, including after a restart. Returning to the app requests fresh server access instead of the two-minute cache. A valid checkout return also retries for up to one minute if payment confirmation is delayed. **Stop waiting** cancels local checks without changing a payment; **Refresh access** remains available as a fallback and forces a server check. A **Sandbox · test payments only** label identifies a Stripe sandbox account. Use card `4242 4242 4242 4242`, any future expiration, and any CVC; no real payment is taken in sandbox.

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

Use the **Close tab after saving** switch beneath the Save link shortcut. Save-only is the default; your choice is remembered. Closing happens only after a successful library write (including a link already saved), and only for the originally captured browser tab. A navigated, missing, or ambiguous tab is left open with a saved-but-not-closed notice. Safari requires the original tab position and a unique URL; Chromium uses its tab ID. Note, tag, selected-tab, and whole-window capture keep tabs open.

Your previously configured quick-save shortcut is preserved. Choose a key with Command, Option, or Control. Escape cancels recording. Conflicts with another SaveNest action are rejected; an unavailable system shortcut leaves the previous binding unchanged. Each row has its own reset button.

Note and tag capture read the browser link first, then open a small editor with the appropriate field focused. Both note and tags are available in either editor. **⌘Return** saves and **Escape** cancels. Nothing is saved until you confirm. Capturing an existing link opens its existing note and tags; saving updates that link without losing its original date or archive state. A second capture while editing brings the existing draft forward instead of discarding it.

Selected-tab capture opens a checklist of the web tabs in the current browser window and saves only the checked tabs. Bulk capture saves every web tab in that window. Neither action extracts hyperlinks from a page or closes tabs. The menu bar and File menu expose all five capture actions as well.

The foreground supported browser takes priority. From SaveNest or another non-browser app, capture uses the last active supported browser (remembered across restarts). On a cold start, visible browser windows or a single running browser provide a fallback. Known unsupported foreground browsers get a specific message rather than capturing a different browser.

Direct capture adapters: Safari, Safari Technology Preview, Chrome, Chrome Beta, Brave, Edge, Arc, Vivaldi, Chromium, and Opera. These rely on each browser's scripting support; not all adapters have been exercised on this machine. Firefox doesn't expose the same tab scripting interface: copy a URL and use **+ → Paste URL** or **⌘N**.

## Open-tab search

Press **⌘⇧O** from any app to open only the compact tab switcher, without activating SaveNest or raising the library. Clicking outside the switcher dismisses it. Search words across tab titles, URLs, and browser names; title matches rank first. **↑/↓** selects, **Return** switches to the existing tab, **⌘1–9** jumps directly, and **Escape** closes the panel. The shortcut is configurable in Settings. The list refreshes on opening and can be refreshed manually; cached results remain searchable during refresh. Safari and the supported Chromium adapters expose tabs in their open windows. Hidden Safari tab groups, Firefox, and embedded browser views are not included. Tab titles and URLs remain in memory only.

## Library

- A floating rail gives direct access to Library, Tags, open-tab search, Add link, Account, and Settings. Date groups sit in rounded cards; notes and tags stay with their links. Editors, onboarding, capture feedback, and tab search share the selected appearance.
- Links are grouped by local calendar date, newest first.
- Website icons replace letter tiles when available. New captures retain the page’s icon URL; older links use the site favicon or public homepage icon. Requests use no browser cookies or favicon proxy, run in the background (six at a time), and cache locally for seven days. Missing icons keep the letter fallback.
- Click a title to open it in your default browser; click a note preview to edit it. Row actions become more prominent on hover.
- Swipe left with two fingers to reveal Delete and Archive (Restore inside Archive); a long left swipe performs Archive. Swipe right for Email and Copy. Escape closes revealed actions. All actions are also in the row menu.
- Email opens a preview with an editable subject and an optional note (off by default). Include a note starts from your saved note without changing it. Open Mail prepares a draft; you choose the recipient and send it.
- “Archive all links…” in Settings → Your library clears the active library after confirmation. Both individual and bulk archive/restore offer Undo in the footer for the last action.
- “Empty archive…” lives inside Archive. It confirms the count before permanently deleting archived links, notes, and tags. Links outside Archive, restored links, and links added after the confirmation opened are kept.
- Search titles, URLs, notes, and tags with **⌘F**. All keywords must match somewhere; results are ranked by relevance. Use **#tag** to match a single-word tag exactly.
- Click a tag pill or use the Tags menu to filter. All, Favorites, Notes, and Archive keep the library in one compact view.
- Add tags with Return or commas, reuse suggestions, and click a tag to remove it. Saving includes any unfinished tag input; **⌘Return** saves the editor.
- Existing libraries and backups without tags load automatically; notes and saved dates are preserved.
- A row’s **…** menu has copy, note/tag editing, Delete, and archive.
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
```

Twenty Swift checks cover library persistence, dates, browser selection, legacy migration, tags, keyword ranking, tag counts, annotation updates, title fallback, paid-access expiry, subscription payment recovery, delayed automatic access checks, polling timeout/cancellation, and forged, mismatched, or replayed native callbacks. Ten tab-close checks cover successful close, changed or closed windows/tabs, duplicate Safari URLs, and Chromium tab identity after reordering. Four additional Node checks execute the actual page reader against DOM fixtures, including unrelated posts and feed pages. The runner works with Command Line Tools alone; it does not require Xcode's XCTest framework.

Run `./scripts/preview-app.sh` to open a separate **SaveNest Preview** app with an in-memory sample library. The preview has its own app identity, does not register account callbacks, and does not load or write the saved library or register global shortcuts. The fixture is also available by running `.build/debug/SaveNest --ui-preview` directly from a terminal.

## Distribution

This repository produces a local development build. Public downloads need a Developer ID signature and Apple notarization. The build script accepts `SIGNING_IDENTITY` for your Developer ID certificate. It embeds the Automation entitlement and browser-access usage description. No developer credentials are included.

The companion website is in `../savenest` and provides email sign-in, account management, Stripe checkout, and downloads. Bookmark sync is not included: the library remains on the Mac, and an account does not upload existing links.
