# SaveNest privacy policy

Updated November 3, 2026

This policy covers the current free SaveNest 0.11.0 preview. A full Cloud policy will be published before accepting subscriptions or uploading library data.

## Your library stays on your Mac

The free SaveNest Mac app works without an account. Saved links, titles, notes, and tags are stored locally. Cloud backup, sync, and Teams are not available yet.

- **Local content:** your library, browser history, and page context are not uploaded to SaveNest.
- **Optional reporting:** anonymous action counts are on by default. Turn them off in Settings or the first-use notice.
- **Network requests:** website icons, account services, updates, and usage reporting can contact external servers.

## Who runs SaveNest

SaveNest is operated by Omelabs, Inc. Dmytro (Dima) Omelian is its founder. For privacy questions, data requests, or support, email [dima@omelabs.org](mailto:dima@omelabs.org).

## Your library and browser access

Saved URLs, titles, notes, tags, favorites, and archive state are stored in a local library file inside your Mac’s Application Support folder. SaveNest does not encrypt that file itself. Your Mac’s account permissions, device security, and any disk encryption you enable protect it. Exports are local files you control.

With macOS Automation permission, SaveNest can read supported browsers’ open-tab URLs and titles. Optional page-context search reads text from open pages when the browser permits JavaScript through Apple Events. Open tabs and unsaved page context remain in memory. Explicitly saved links and notes become part of your local library.

History search reads supported browsers’ local history databases without changing them. It indexes a bounded set of recent visits in memory. Pausing history search clears SaveNest’s history cache; it does not delete browser history. History is not included in library exports or sent with usage counts.

Clipboard offers are off by default. If you enable them, SaveNest watches for a newly copied web URL and offers to save it. Clipboard contents are not uploaded. You can turn this off in Settings.

## Connections made by the app

SaveNest may request a website’s favicon or public homepage to display its icon. These requests do not use your browser cookies or a favicon proxy, but the destination receives ordinary connection information such as your IP address. Icons are cached locally and refreshed when requested after seven days. Cached files may remain on your Mac until evicted by the bounded cache or removed locally.

Update checks contact savenest.app; release downloads are hosted on GitHub. These services receive ordinary request information. Opening a saved page uses your browser. Sharing by email uses the email application you choose and sends the content you explicitly share to your selected recipient.

SaveNest does not upload your saved library to an AI provider. Automatic tag suggestions use links and tags already stored on your Mac.

## Anonymous usage counts

“Share anonymous usage counts” is enabled by default. A visible notice and Settings provide an off switch. Reporting sends fixed action names and totals, such as app opens, links saved, notes saved, and links opened. It does not send URLs, titles, note text, tag names, clipboard contents, account tokens, account IDs, or persistent installation/device identifiers.

Pending counts stay in memory and are sent in batches, approximately once a minute. Each batch has a new random identifier to prevent double-counting. Turning reporting off clears pending counts and cancels reporting requests. A request already received by the server cannot be recalled.

The service keeps daily aggregate counts for approximately 90 days and random batch receipts for seven days. Cleanup runs when new batches arrive, so expired records may remain until the next cleanup. These tables do not contain IP addresses. The hosting provider still receives ordinary network information. Because counts have no person or device identifier, we cannot locate one person’s contribution in an aggregate for deletion.

## Optional accounts and earlier subscriptions

If you request a sign-in link, we process your email address, optional name, and authentication records to provide your account. Sign-in does not upload your library. The app keeps its session credential in macOS Keychain. The server stores hashed tokens. A successful browser confirmation can also set a secure, HttpOnly account-session cookie.

Sign-in links expire after 15 minutes; the one-use code exchanged by the app expires after two minutes. Account sessions expire after 30 days. Expired authentication records are removed during later authentication cleanup, rather than by a guaranteed deletion timer. Signing out removes the app’s local credential and, when online, revokes that server session.

Stripe processes payments and existing subscription management. SaveNest stores the associated customer identifier, subscription status, plan, billing-period dates, and payment-event identifiers. Payment-card details are entered on Stripe’s pages and are not stored in SaveNest’s database. New subscriptions and paid referral invitations are currently closed.

For earlier referrals, we retain the invited email, inviter/account links, delivery state, and reward state to resolve existing offers and billing. Account, billing, support, and historical referral records are kept while needed to operate the account, resolve requests or disputes, and meet applicable recordkeeping duties. They do not currently have an automatic deletion schedule. Request account deletion by email; we will explain any records that must be retained.

## The website, bookings, and service providers

The website does not add advertising trackers. Essential account cookies and hosting/security infrastructure may still process request data. Authentication abuse controls use hashed email/IP-derived keys and expiry times; they do not add raw IP addresses to the usage-count tables.

- [Cloudflare](https://www.cloudflare.com/privacypolicy/) hosts the website, APIs, and account database through the Sites hosting platform.
- [Resend](https://resend.com/legal/privacy-policy) delivers requested account emails and processed earlier referral emails.
- [Stripe](https://stripe.com/privacy) processes existing billing and payment records.
- [GitHub](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement) hosts the public source and desktop downloads. We fetch the public star count from our server, not your browser.
- [Cal.com](https://cal.com/privacy) handles demo bookings when you follow the booking link. Information you enter there is used to arrange your requested meeting.

Following these links, downloading a release, or booking a meeting connects you to the relevant provider. Provider operations may involve processing outside your country. Their linked notices describe their handling of data. We do not claim that all website or account data stays in one country.

## Why we process information and your choices

We use requested account, support, and billing information to provide those services. We use limited security and operational information to protect the service and understand whether basic features work, and retain records where required by law. Optional usage reporting can be turned off without losing any local feature.

You can export or delete local links in the app, revoke browser access in macOS, pause history, disable clipboard offers, and turn off usage reporting. Uninstalling the app may leave its Application Support files, preferences, and Keychain entries on your Mac. Export anything you want to keep before deleting those files.

Depending on your location, you may have rights to access, correct, erase, or receive personal data, restrict or object to its processing, and complain to your data-protection authority. Email [dima@omelabs.org](mailto:dima@omelabs.org) to make a request. We may need to verify that the account belongs to you. We cannot remotely delete local files on your Mac.

## Future Cloud features and policy changes

Cloud is planned as a separate, explicitly enabled service with library content encrypted on your devices. It is not running today. We will publish its actual data flows, recovery behavior, storage limits, and retention terms before accepting subscriptions or uploading library data.

We will update this page when practices change and revise the date above. The desktop app’s [source code is available for inspection](https://github.com/dmytro-omelian/savenest).
