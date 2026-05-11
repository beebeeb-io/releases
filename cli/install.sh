#!/bin/sh
# bb — Beebeeb CLI installer
# Usage:  curl -fsSL https://releases.beebeeb.io/cli/install.sh | sh
#
# Installs the latest bb binary to ~/.local/bin (or $INSTALL_DIR if set).
# Supported: macOS (arm64, x86_64) · Linux (x86_64 musl, aarch64 musl)

set -e

REPO="beebeeb-io/cli"
BIN="bb"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

# ── Detect platform ────────────────────────────────────────────────────────────

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Darwin) OS_TAG="apple-darwin" ;;
  Linux)  OS_TAG="unknown-linux-musl" ;;
  *)
    echo "bb: unsupported OS: $OS" >&2
    exit 1
    ;;
esac

case "$ARCH" in
  x86_64)          ARCH_TAG="x86_64" ;;
  arm64|aarch64)   ARCH_TAG="aarch64" ;;
  *)
    echo "bb: unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

TARGET="${ARCH_TAG}-${OS_TAG}"

# ── Fetch latest release tag ───────────────────────────────────────────────────

echo "  → Fetching latest bb release..."
LATEST="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
  | grep '"tag_name"' \
  | head -1 \
  | sed 's/.*"tag_name": "\(.*\)".*/\1/')"

if [ -z "$LATEST" ]; then
  echo "bb: could not fetch latest release from GitHub" >&2
  exit 1
fi

# ── Download and install ───────────────────────────────────────────────────────

URL="https://github.com/${REPO}/releases/download/${LATEST}/beebeeb-cli-${TARGET}.tar.xz"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "  → Downloading bb ${LATEST} for ${TARGET}..."
curl -fsSL "$URL" -o "$TMP/bb.tar.xz"

tar -xf "$TMP/bb.tar.xz" --strip-components=1 -C "$TMP"
chmod +x "$TMP/bb"

mkdir -p "$INSTALL_DIR"
mv "$TMP/bb" "$INSTALL_DIR/$BIN"

# ── Done ───────────────────────────────────────────────────────────────────────

echo ""
echo "  ✓ bb ${LATEST} installed to ${INSTALL_DIR}/bb"
echo ""

# Warn if INSTALL_DIR is not in PATH
case ":$PATH:" in
  *":${INSTALL_DIR}:"*) ;;
  *)
    echo "  ! ${INSTALL_DIR} is not in your PATH."
    echo "    Add this to your shell profile:"
    echo ""
    echo "      export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
    ;;
esac

echo "  Get started:"
echo "    bb login"
echo "    bb ls"
echo "    bb push <file>"
echo ""
