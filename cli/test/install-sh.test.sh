#!/bin/sh
# Verifies that the legacy CLI installer (releases.beebeeb.io/cli/install.sh)
# never installs a binary without checksum verification.
#
# Passing means ONE of:
#   (a) the script IS the cargo-dist installer (it carries verify_checksum
#       and embedded sha256 values), or
#   (b) the script is a thin shim that only fetches the canonical cargo-dist
#       installer (https://get.beebeeb.io) and executes it — it never
#       downloads or extracts a binary archive itself.
#
# Usage:
#   sh cli/test/install-sh.test.sh                 # checks cli/install.sh in this tree
#   sh cli/test/install-sh.test.sh <path>          # checks a local file
#   sh cli/test/install-sh.test.sh --url <url>     # checks what a URL serves
#
# Exit 0 = GREEN, 1 = RED. Prints a pass/fail count; a run with 0 checks is RED.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
TARGET="$HERE/../install.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ "${1:-}" = "--url" ]; then
  [ -n "${2:-}" ] || { echo "usage: $0 --url <url>" >&2; exit 2; }
  if ! curl -fsSL "$2" -o "$WORK/served.sh"; then
    echo "RED: could not fetch $2" >&2
    exit 1
  fi
  TARGET="$WORK/served.sh"
elif [ -n "${1:-}" ]; then
  TARGET="$1"
fi

[ -s "$TARGET" ] || { echo "RED: $TARGET missing or empty" >&2; exit 1; }

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); echo "  ok   $1"; }
bad() { FAIL=$((FAIL + 1)); echo "  FAIL $1"; }

CANONICAL="https://get.beebeeb.io"

# ── Case (a): it is the cargo-dist installer itself ───────────────────────────
if /usr/bin/grep -q '^verify_checksum()' "$TARGET" \
   && /usr/bin/grep -q '_checksum_style="sha256"' "$TARGET"; then
  ok "script is the cargo-dist installer (verify_checksum + embedded sha256)"
  echo "install-sh.test: $PASS passed, $FAIL failed"
  exit 0
fi

# ── Case (b): it must be a shim that delegates to the cargo-dist installer ────

# b1. Static: never extracts an archive or moves a binary into place itself.
if /usr/bin/grep -Eq '(^|[^A-Za-z_])tar[[:space:]]+-' "$TARGET"; then
  bad "script extracts an archive itself (tar) — unverified install path"
else
  ok "script does not extract any archive itself"
fi

# b2. Static: references the canonical installer.
if /usr/bin/grep -q "$CANONICAL" "$TARGET"; then
  ok "script references $CANONICAL"
else
  bad "script does not reference $CANONICAL"
fi

# b3. Behavioural: run it with a fake curl that records every URL it is asked
#     for and serves a stub "cargo-dist installer" for the canonical URL.
mkdir -p "$WORK/bin" "$WORK/home"
cat > "$WORK/bin/curl" <<'FAKE'
#!/bin/sh
url=""; out=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -*) shift ;;
    *)  url="$1"; shift ;;
  esac
done
echo "$url" >> "$FAKE_LOG_DIR/urls"
if [ "$url" = "https://get.beebeeb.io" ]; then
  body='#!/bin/sh
echo "args=$*" > "$FAKE_LOG_DIR/stub-ran"
echo "unmanaged=${BEEBEEB_CLI_UNMANAGED_INSTALL:-}" >> "$FAKE_LOG_DIR/stub-ran"
'
  if [ -n "$out" ]; then printf '%s' "$body" > "$out"; else printf '%s' "$body"; fi
  exit 0
fi
exit 22
FAKE
chmod +x "$WORK/bin/curl"

FAKE_LOG_DIR="$WORK" HOME="$WORK/home" PATH="$WORK/bin:$PATH" \
  INSTALL_DIR="$WORK/custom-bin" \
  sh "$TARGET" --quiet > "$WORK/run.out" 2>&1
RC=$?

if [ "$RC" -eq 0 ]; then ok "shim exits 0 when the canonical installer succeeds"
else bad "shim exited $RC (output: $(tr '\n' ' ' < "$WORK/run.out"))"; fi

if [ -f "$WORK/urls" ] && [ "$(sort -u "$WORK/urls")" = "$CANONICAL" ]; then
  ok "only URL fetched is $CANONICAL"
else
  bad "fetched URLs were: $(tr '\n' ' ' < "$WORK/urls" 2>/dev/null || echo '<none>')"
fi

if [ -f "$WORK/stub-ran" ]; then
  ok "cargo-dist installer was executed"
  if /usr/bin/grep -qx 'args=--quiet' "$WORK/stub-ran"; then
    ok "arguments are passed through to the installer"
  else
    bad "arguments not passed through: $(head -1 "$WORK/stub-ran")"
  fi
  if /usr/bin/grep -qx "unmanaged=$WORK/custom-bin" "$WORK/stub-ran"; then
    ok "legacy INSTALL_DIR is honoured (BEEBEEB_CLI_UNMANAGED_INSTALL)"
  else
    bad "legacy INSTALL_DIR not mapped: $(sed -n 2p "$WORK/stub-ran")"
  fi
else
  bad "cargo-dist installer was never executed"
fi

# b4. Behavioural: a failed download must fail the shim (no silent success).
cat > "$WORK/bin/curl" <<'FAKE'
#!/bin/sh
exit 22
FAKE
if FAKE_LOG_DIR="$WORK" HOME="$WORK/home" PATH="$WORK/bin:$PATH" \
  sh "$TARGET" > "$WORK/run2.out" 2>&1; then
  bad "shim exited 0 although the installer download failed"
else
  ok "shim fails closed when the installer cannot be fetched"
fi

TOTAL=$((PASS + FAIL))
echo "install-sh.test: $PASS passed, $FAIL failed"
if [ "$TOTAL" -eq 0 ] || [ "$FAIL" -ne 0 ]; then exit 1; fi
exit 0
