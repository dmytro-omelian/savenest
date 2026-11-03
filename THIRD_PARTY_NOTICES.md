# Third-party notices

SaveNest's own source is licensed under MIT. Dependencies retain their own licenses.

- **Electron** — MIT, Copyright Electron contributors and GitHub Inc. Electron includes Chromium, Node.js, and other components with additional licenses. Distributed applications retain Electron's `LICENSE` and `LICENSES.chromium.html`; consult those files for the complete bundled notices. Source: https://github.com/electron/electron.
- **Sparkle 2.10.0** — MIT, Copyright Sparkle Project contributors. The native helper bundles Sparkle; its license is included with the application. Source: https://github.com/sparkle-project/Sparkle.
- **SQLite** — public domain. SaveNest uses macOS's system SQLite for read-only browser-history queries. Source: https://sqlite.org/copyright.html.
- **Swift and Apple frameworks** — supplied by the developer toolchain or operating system, under their respective terms; not relicensed by SaveNest.

Build tools such as `@electron/packager`, `@electron/fuses`, and their dependencies are installed from the locked npm dependency graph. Their license files remain in their packages; they are not part of SaveNest's own MIT grant. Release packaging must retain notices for every component actually distributed.

Website names, browser names, and third-party marks remain the property of their owners. Favicon downloads are runtime user-library data and are not included in the source release. The generated SaveNest icon is built by `scripts/make-icon.swift`.
