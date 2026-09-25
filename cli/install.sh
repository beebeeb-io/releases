#!/bin/sh
# bb — Beebeeb CLI installer (legacy URL)
#
# This URL is kept only so older instructions keep working. The one supported
# installer is:
#
#   curl -fsSL https://get.beebeeb.io | sh
#
# This script does nothing but fetch that installer and run it. It never
# downloads or unpacks a binary itself: the installer it hands off to (the one
# cargo-dist generates on every beebeeb-io/cli GitHub release) carries the
# sha256 of every release archive and refuses an archive that does not match.
#
# Legacy compatibility: INSTALL_DIR=<dir> still installs bb directly into <dir>
# (mapped to BEEBEEB_CLI_UNMANAGED_INSTALL, which also leaves your PATH alone).
# Without it, bb goes to ~/.cargo/bin (or $CARGO_HOME/bin) — the same place
# get.beebeeb.io puts it.
#
# Source: https://github.com/beebeeb-io/cli

set -eu

INSTALLER_URL="https://get.beebeeb.io"

fail() {
  echo "bb: $*" >&2
  exit 1
}

# cargo-dist's installer skips (rather than fails) its checksum check when
# sha256sum is missing. Refuse up front so this route never installs unverified.
command -v sha256sum >/dev/null 2>&1 \
  || fail "sha256sum is required to verify the download (install coreutils), refusing to install unverified"
command -v curl >/dev/null 2>&1 || fail "curl is required"

if [ -n "${INSTALL_DIR:-}" ] && [ -z "${BEEBEEB_CLI_UNMANAGED_INSTALL:-}" ]; then
  BEEBEEB_CLI_UNMANAGED_INSTALL="$INSTALL_DIR"
  export BEEBEEB_CLI_UNMANAGED_INSTALL
fi

echo "  Note: this installer URL is deprecated. Use: curl -fsSL ${INSTALLER_URL} | sh" >&2

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Download fully before running, so a cut-off transfer never executes half a script.
curl --proto '=https' --tlsv1.2 -fsSL "$INSTALLER_URL" -o "$TMP/installer.sh" \
  || fail "could not download the installer from ${INSTALLER_URL}"

[ -s "$TMP/installer.sh" ] \
  || fail "the installer downloaded from ${INSTALLER_URL} is empty"

sh "$TMP/installer.sh" "$@"

# Earlier versions of this script installed to ~/.local/bin. A copy left there
# can shadow the new one on PATH.
if [ -z "${INSTALL_DIR:-}" ] && [ -f "$HOME/.local/bin/bb" ]; then
  echo ""
  echo "  ! An older bb is still at ~/.local/bin/bb (from a previous version of this"
  echo "    installer). Remove it so it does not shadow the new one:"
  echo ""
  echo "      rm ~/.local/bin/bb"
  echo ""
fi
