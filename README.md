<p align="center">
  <a href="https://beebeeb.io"><img src="https://beebeeb.io/assets/beebeeb-icon.png" alt="beebeeb" width="72" height="72" /></a>
</p>
<h1 align="center">beebeeb releases</h1>
<p align="center">Static release host for beebeeb — the Tauri auto-update manifest and the CLI installer, served from <a href="https://releases.beebeeb.io">releases.beebeeb.io</a>.</p>
<p align="center">
  <a href="https://releases.beebeeb.io"><img src="https://img.shields.io/badge/hosted%20on-github%20pages-555.svg" alt="Hosted on GitHub Pages" /></a> &nbsp;
  <a href="SECURITY.md"><img src="https://img.shields.io/badge/security-policy-555.svg" alt="Security policy" /></a>
</p>
<p align="center"><a href="https://beebeeb.io">Website</a> &nbsp;·&nbsp; <a href="https://beebeeb.io/download">Download</a> &nbsp;·&nbsp; <a href="SECURITY.md">Report a vulnerability</a></p>
<p align="center"><sub>End-to-end encrypted cloud storage, built in Europe. Operated by Initlabs B.V., Wijchen, Netherlands.</sub></p>

---

This repository is published as a GitHub Pages site at **[releases.beebeeb.io](https://releases.beebeeb.io)**. It hosts the artifacts that clients fetch to update or install themselves — nothing here is a buildable project, and **no file here should be edited by hand**.

The root URL redirects to **[beebeeb.io/download](https://beebeeb.io/download)**.

## What's here

| Path | Purpose |
| --- | --- |
| `desktop/latest.json` | Tauri v2 auto-update manifest. The desktop app polls this to discover new versions. |
| `cli/install.sh` | One-line installer for the `bb` CLI — `curl -fsSL https://releases.beebeeb.io/cli/install.sh \| sh`. |
| `cli/` | CLI binary downloads (populated by CI on each published release). |
| `index.html` | Redirect to `beebeeb.io/download`. |

## How it's updated

CI workflows in [`desktop`](https://github.com/beebeeb-io/desktop) and [`cli`](https://github.com/beebeeb-io/cli) write the manifest and binaries here on every published GitHub release, using a token scoped to `contents:write` on this repo. Manual edits will be overwritten by the next release.

## Security

Found a vulnerability? Email **security@beebeeb.io** — see [SECURITY.md](SECURITY.md).

## Part of beebeeb

End-to-end encrypted, zero-knowledge cloud storage — made in Europe.
[core](https://github.com/beebeeb-io/core) · [cli](https://github.com/beebeeb-io/cli) · [web](https://github.com/beebeeb-io/web) · [mobile](https://github.com/beebeeb-io/mobile) · [desktop](https://github.com/beebeeb-io/desktop) · [website](https://beebeeb.io)

## License

No license is declared for this repository yet. It hosts release artifacts only; the source for the products it distributes lives in the repos linked above. © Initlabs B.V. (KvK 95157565), Wijchen, Netherlands.
