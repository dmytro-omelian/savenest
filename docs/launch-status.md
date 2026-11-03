# SaveNest launch status

Updated 2026-11-03. [GitHub launch tracker](https://github.com/dmytro-omelian/savenest/issues/13) is the shared source for dependencies and completion. Local code, passing checks, and public release are separate states. **[0.11.0 is publicly released as a signed preview](https://github.com/dmytro-omelian/savenest/releases/tag/v0.11.0); full launch remains pending.** The owner chose preview distribution because an isolated installed-app test environment is unavailable.

## Launch gate

A first-time user can download the signed app, understand its privacy behavior, save and find a link without signing in, and find the source or report a problem. Existing users keep their libraries and prepaid value.

| Work | Status | Evidence / next step |
| --- | --- | --- |
| Simplify capture and finding links | Verified in preview | Unified ⌘O launcher, inline notes/tags and tab selection; real Electron smoke passes with sample data. Live browser permission checks remain. [#14](https://github.com/dmytro-omelian/savenest/issues/14) |
| Make every local feature free | Shipped in signed preview | Local writes no longer depend on subscription verification; signed-out sample capture/edit checks pass. Full offline installed-app acceptance remains pending. [#15](https://github.com/dmytro-omelian/savenest/issues/15) |
| Privacy and analytics controls | Public policy and signed preview | [Privacy policy](https://savenest.app/privacy) and [source copy](privacy.md) are published. Shared native/Electron notice and opt-out; preview reporting blocked. Installed-app network verification remains pending. [#17](https://github.com/dmytro-omelian/savenest/issues/17) |
| Open source and contribution path | Public | MIT, contribution/security docs, templates and CI merged in [#23](https://github.com/dmytro-omelian/savenest/pull/23). Source/history secret scans passed. Clean-clone macOS CI passes. Hosted backend remains separate. [#16](https://github.com/dmytro-omelian/savenest/issues/16) |
| Signed public release and safe updates | Signed preview published | Both final Apple Silicon and Intel ZIPs passed signature, notarization, Gatekeeper, architecture and tamper checks. [Download 0.11.0](https://github.com/dmytro-omelian/savenest/releases/tag/v0.11.0). Installed-app and live-update checks remain. [#18](https://github.com/dmytro-omelian/savenest/issues/18) |
| Landing page, current app visuals and GitHub stars | Preview website published | [savenest.app](https://savenest.app), website source `4eb6f075`, saved version 67. Build and 43 tests pass. Current launcher screenshot, repository and contribution links are live. Hourly star-cache/failure tests pass; live page currently uses the repository-only fallback, so a live count is not yet verified. Mobile visual verification remains. [#19](https://github.com/dmytro-omelian/savenest/issues/19) |
| Free/Cloud pricing and subscriber transition | Live for preview; full launch pending | Free preview is the default; Cloud is Coming soon. Live checkout and referral POSTs return 409, foreign origins 403, with no open Stripe sessions. Existing renewals stopped, collection paused, old purchase prices inactive, historical rates retained for explicit Cloud opt-in. Invoice/refund reconciliation found no unused paid balance to credit. Older native versions retain their old paywall and require manual upgrade to the free preview. [#20](https://github.com/dmytro-omelian/savenest/issues/20) |
| Teams demo booking | Live | [Book a SaveNest demo](https://cal.com/dmytro-omelian/savenest-demo). 30 minutes; existing availability; calendar title uses the guest's name followed by `/ Dima (Savenest demo)`. No test invitation sent. |

Do not mark the launch complete until the public download, repository, privacy page, website pricing and subscriber transition are verified together. Passing preview checks does not establish installed-app or live-payment behavior.

The [preview acceptance checklist](preview-acceptance.md) records remaining isolated upgrade, offline save/edit/import/export/restart, analytics network, browser permission, Intel runtime, and installed-to-installed update tests. No test was run against the owner's primary library or Keychain.

Public Apple Silicon/Intel ZIPs and architecture redirects return successfully. Both live Electron feeds match the published archive hashes and revalidate caches. Website publication recovered from an upload-capacity error using the tested source commit; the successful deployment is also available at [the hosted origin](https://savenest.dmytro-omelian.chatgpt.site).

## Product decisions

- Free: every local feature, no account, no item-count paywall, local export always available.
- Cloud: planned at $4.99/month or $49.90/year; optional encrypted backup, sync across Macs and recovery. No checkout until available.
- Teams: separate future offering; use demos to understand shared-library workflows before setting price.
- Usage counts remain opt-out with visible disclosure. Do not describe them as no telemetry.
- AWS and PostgreSQL are candidate implementation choices, not approved architecture. Encryption, conflicts, recovery and operating cost come first. [Cloud design #21](https://github.com/dmytro-omelian/savenest/issues/21).

## Later work from the launch notes

These remain unchecked proposals, not prerequisites for releasing the free app.

- [ ] **Reader shortcut, notes and Obsidian:** define what “read one link” opens, what notes export, the destination, and whether integration is one-way or bidirectional before implementation.
- [ ] **Link tidying and grouping:** collect concrete examples of the desired Slack-like behavior; test a small deterministic grouping workflow before deciding whether AI is useful.
- [ ] **MCP, proactive assistance and AI:** identify a specific recurring job, buyer and running cost. Local automation is not automatically a paid feature. Hosted compute may be paid after validation.
- [ ] **Team collaboration:** use the demo link to learn about shared collections, permissions and billing. Record evidence before committing to seats or pricing. [#22](https://github.com/dmytro-omelian/savenest/issues/22).
- [ ] **Launch video:** prepare a short real-product demonstration showing capture, retrieval, privacy and the free/open-source model. Review the intended Farza reference before choosing its format.
- [ ] **LinkedIn and X launch:** prepare drafts and assets after the public release is verified. Publication needs a separate explicit request.
- [ ] **X-agent-assisted daily sharing:** define audience, useful content, review requirements and cadence. No daily posting automation has been enabled.

## Parallel ownership

Desktop agent: local behavior, launcher and privacy UI. Website agent: landing page, policy, pricing and API changes. Release agent: packaging, notarization and updater. Coordinator: integration, documentation, GitHub, booking link, publication and billing transition.
