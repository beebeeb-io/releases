# beebeeb-io/releases

GitHub Pages release hosting for beebeeb.io products.
URL: releases.beebeeb.io

## Structure

- `desktop/latest.json` — Tauri v2 auto-update manifest
- `cli/install.sh` — DEPRECATED legacy installer URL; a thin shim that runs the cargo-dist installer from https://get.beebeeb.io (checksum-verified). Never make it download/extract a binary itself.
- `cli/test/install-sh.test.sh` — guard for the above; run `sh cli/test/install-sh.test.sh` (expect `N passed, 0 failed`).

## Build & dev

No build step. GitHub Pages serves static files from main branch root.

## Updating

`desktop/latest.json`: never edit manually, the `repos/desktop` release workflow writes it. `cli/install.sh` is hand-maintained (no CI writes it).
