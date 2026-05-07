# beebeeb-io/releases

GitHub Pages release hosting for beebeeb.io products.
URL: releases.beebeeb.io

## Structure

- `desktop/latest.json` — Tauri v2 auto-update manifest
- `cli/` — Future CLI binary downloads

## Build & dev

No build step. GitHub Pages serves static files from main branch root.

## Updating

Never edit manually. CI workflows in `repos/desktop` and `repos/cli` write here.
