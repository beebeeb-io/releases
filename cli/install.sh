#!/bin/sh
# bb — Beebeeb CLI installer (legacy URL)
#
# This URL is kept only so older instructions keep working. The one supported
# installer is:
#
#   curl -fsSL https://get.beebeeb.io | sh
#
# This script does nothing but fetch that installer and run it. It never
# downloads or unpacks a binary itself: the installer it hands off to carries
# the sha256 of every release archive and refuses an archive that does not match.
#
# Legacy compatibility: INSTALL_DIR=<dir> still installs bb directly into <dir>
# (mapped to BEEBEEB_CLI_UNMANAGED_INSTALL, which also leaves your PATH alone).
# Without it, bb goes to ~/.cargo/bin — the same place get.beebeeb.io puts it.

set -eu

INSTALLER_URL="https://get.beebeeb.io"

if [ -n "${INSTALL_DIR:-}" ] && [ -z "${BEEBEEB_CLI_UNMANAGED_INSTALL:-}" ]; then
  BEEBEEB_CLI_UNMANAGED_INSTALL="$INSTALL_DIR"
  export BEEBEEB_CLI_UNMANAGED_INSTALL
fi

echo "  Note: this installer URL is deprecated. Use: curl -fsSL ${INSTALLER_URL} | sh" >&2

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! curl --proto '=https' --tlsv1.2 -fsSL "$INSTALLER_URL" -o "$TMP/installer.sh"; then
  echo "bb: could not download the installer from ${INSTALLER_URL}" >&2
  exit 1
fi

if [ ! -s "$TMP/installer.sh" ]; then
  echo "bb: the installer downloaded from ${INSTALLER_URL} is empty" >&2
  exit 1
fi

sh "$TMP/installer.sh" "$@"
