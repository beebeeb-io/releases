#!/bin/sh
# bb — Beebeeb CLI installer
# Usage:  curl -fsSL https://releases.beebeeb.io/cli/install.sh | sh
#
# Kept for existing links only. The canonical installer is
#   curl --proto '=https' --tlsv1.2 -LsSf https://get.beebeeb.io | sh
# and this script hands off to that same installer: the one cargo-dist
# generates on every beebeeb-io/cli GitHub release. It verifies the archive's
# SHA-256 against the value baked into it at release time before installing,
# and installs to ~/.cargo/bin (or $CARGO_HOME/bin) like every other route.
#
# INSTALL_DIR=<dir> still installs a single bb into <dir> (no PATH edits,
# no self-updater), as this script always did.
#
# Source: https://github.com/beebeeb-io/cli

set -eu

INSTALLER_URL="https://github.com/beebeeb-io/cli/releases/latest/download/beebeeb-cli-installer.sh"

fail() {
  echo "bb: $*" >&2
  exit 1
}

# cargo-dist's installer skips (rather than fails) its checksum check when
# sha256sum is missing. Refuse up front so this route never installs unverified.
command -v sha256sum >/dev/null 2>&1 \
  || fail "sha256sum is required to verify the download (install coreutils), refusing to install unverified"
command -v curl >/dev/null 2>&1 || fail "curl is required"

if [ -n "${INSTALL_DIR:-}" ]; then
  BEEBEEB_CLI_UNMANAGED_INSTALL="$INSTALL_DIR"
  export BEEBEEB_CLI_UNMANAGED_INSTALL
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Download fully before running, so a cut-off transfer never executes half a script.
curl --proto '=https' --tlsv1.2 -fsSL "$INSTALLER_URL" -o "$TMP/installer.sh" \
  || fail "could not download the installer from $INSTALLER_URL"

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
