# beebeeb-io/releases

GitHub Pages site for beebeeb.io release artifacts.
Deployed at: https://releases.beebeeb.io

## Structure

- `desktop/latest.json` — Tauri auto-update manifest (written by desktop CI on each release)
- `cli/` — CLI binary downloads (future)

## How it works

CI workflows in `repos/desktop` and `repos/cli` push updated manifests and 
artifacts here on every published GitHub release. Do not edit files here manually.

## Setup (one-time, Guus)

1. Create `github.com/beebeeb-io/releases` as a public repo
2. Enable GitHub Pages → source: main branch, root directory
3. Add DNS CNAME: `releases.beebeeb.io CNAME beebeeb-io.github.io`
4. Create a GitHub PAT with `contents:write` on this repo
5. Add it as `RELEASES_PUSH_TOKEN` secret in `beebeeb-io/desktop` and `beebeeb-io/cli`
