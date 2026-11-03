# SaveNest launch status

Updated 2026-11-03. [GitHub launch tracker](https://github.com/dmytro-omelian/savenest/issues/13) is the shared source for dependencies and completion. Local code, passing checks, and public release are separate states.

## Launch gate

A first-time user can download the signed app, understand its privacy behavior, save and find a link without signing in, and find the source or report a problem. Existing users keep their libraries and prepaid value.

| Work | Status | Evidence / next step |
| --- | --- | --- |
| Simplify capture and finding links | Verified in preview | Unified ⌘O launcher, inline notes/tags and tab selection; real Electron smoke passes with sample data. Live browser permission checks remain. [#14](https://github.com/dmytro-omelian/savenest/issues/14) |
| Make every local feature free | Implemented and tested locally | Local writes no longer depend on subscription verification; signed-out sample capture/edit checks pass. Ship the free release. [#15](https://github.com/dmytro-omelian/savenest/issues/15) |
| Privacy and analytics controls | Implemented locally | Shared native/Electron notice and opt-out; preview reporting blocked. Website policy and published-app review in progress. [#17](https://github.com/dmytro-omelian/savenest/issues/17) |
| Open source and contribution path | In progress | MIT, contribution/security docs, templates and CI prepared. Gitleaks found no secrets in 34 commits or current source snapshot. Publication and remote CI remain. [#16](https://github.com/dmytro-omelian/savenest/issues/16) |
| Signed public release and safe updates | In progress | Apple signing/notarization credentials available; Apple Silicon and Intel packaging underway. [#18](https://github.com/dmytro-omelian/savenest/issues/18) |
| Landing page, current app visuals and GitHub stars | In progress | Update current tabs/launcher story, real sample screenshot, repository link and hourly star cache. [#19](https://github.com/dmytro-omelian/savenest/issues/19) |
| Free/Cloud pricing and subscriber transition | Partly blocked | New checkout disabled in local source. Live Stripe connection needs reauthentication before renewal/credit reconciliation. [#20](https://github.com/dmytro-omelian/savenest/issues/20) |
| Teams demo booking | Live | [Book a SaveNest demo](https://cal.com/dmytro-omelian/savenest-demo). 30 minutes; existing availability; calendar title uses the guest's name followed by `/ Dima (Savenest demo)`. No test invitation sent. |

Do not mark the launch complete until the public download, repository, privacy page, website pricing and subscriber transition are verified together. Passing preview checks does not establish installed-app or live-payment behavior.

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
