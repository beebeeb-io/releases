#!/bin/sh
# Integrity test for cli/install.sh (served at https://releases.beebeeb.io/cli/install.sh).
#
# Serves a fake GitHub from local files through a `curl` shim on PATH, so the
# installer under test never reaches the network for the install itself. The
# real v0.10.0 release installer + host artifact are fetched once (public,
# read-only) into a cache and served from there.
#
#   1. tampered: the release archive's `bb` is swapped for a script. The
#      installer MUST exit non-zero, say "checksum", and install nothing.
#   2. clean:    the untouched archive installs a `bb` that reports 0.10.0.
#   3. compat:   INSTALL_DIR=<dir> still installs a flat <dir>/bb.
#   4. no sha256sum on PATH: the tampered archive is still refused (the
#      cargo-dist installer alone would skip verification and install it).
#
# Usage: sh tests/cli-install.test.sh [path/to/install.sh]
# Env:   BB_TEST_CACHE=<dir> to reuse downloaded release files between runs.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="${1:-$HERE/../cli/install.sh}"
SCRIPT="$(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")"
VERSION="v0.10.0"
REAL_CURL="$(command -v curl)"

case "$(uname -s)" in
  Darwin) OS_TAG="apple-darwin" ;;
  Linux)  OS_TAG="unknown-linux-musl" ;;
  *) echo "unsupported OS for this test" >&2; exit 2 ;;
esac
case "$(uname -m)" in
  x86_64) ARCH_TAG="x86_64" ;;
  arm64|aarch64) ARCH_TAG="aarch64" ;;
  *) echo "unsupported arch for this test" >&2; exit 2 ;;
esac
ARTIFACT="beebeeb-cli-${ARCH_TAG}-${OS_TAG}.tar.xz"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
CACHE="${BB_TEST_CACHE:-$WORK/cache}"
mkdir -p "$CACHE"

REL="https://github.com/beebeeb-io/cli/releases/download/$VERSION"
for f in beebeeb-cli-installer.sh "$ARTIFACT"; do
  [ -s "$CACHE/$f" ] || "$REAL_CURL" -fsSL "$REL/$f" -o "$CACHE/$f" || { echo "could not fetch $f" >&2; exit 2; }
done

# ── fake GitHub trees ─────────────────────────────────────────────────────────
mk_fake() { # $1 = root, $2 = archive to serve
  mkdir -p "$1/gh/beebeeb-io/cli/releases/download/$VERSION" \
           "$1/gh/beebeeb-io/cli/releases/latest/download" "$1/api"
  cp "$2" "$1/gh/beebeeb-io/cli/releases/download/$VERSION/$ARTIFACT"
  cp "$CACHE/beebeeb-cli-installer.sh" "$1/gh/beebeeb-io/cli/releases/download/$VERSION/"
  cp "$CACHE/beebeeb-cli-installer.sh" "$1/gh/beebeeb-io/cli/releases/latest/download/"
  printf '{\n  "tag_name": "%s",\n  "name": "%s"\n}\n' "$VERSION" "$VERSION" > "$1/api/latest.json"
}

# Tampered archive: same layout, `bb` replaced.
mkdir -p "$WORK/unpack"
tar -xf "$CACHE/$ARTIFACT" -C "$WORK/unpack"
TOP="$(ls "$WORK/unpack")"
printf '#!/bin/sh\necho TAMPERED\n' > "$WORK/unpack/$TOP/bb"
chmod +x "$WORK/unpack/$TOP/bb"
(cd "$WORK/unpack" && tar -cJf "$WORK/tampered.tar.xz" "$TOP")

mk_fake "$WORK/fake-clean" "$CACHE/$ARTIFACT"
mk_fake "$WORK/fake-tampered" "$WORK/tampered.tar.xz"

# ── curl shim: maps GitHub URLs onto $FAKE_ROOT, logs every request ───────────
mkdir -p "$WORK/bin"
cat > "$WORK/bin/curl" <<'SHIM'
#!/bin/sh
out=""; url=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift ;;
    --header|-H|--proto|--proto-redir|-w|--retry) shift ;;
    http://*|https://*) url="$1" ;;
  esac
  shift
done
case "$url" in
  https://api.github.com/repos/beebeeb-io/cli/releases/latest) f="$FAKE_ROOT/api/latest.json" ;;
  https://github.com/*) f="$FAKE_ROOT/gh/${url#https://github.com/}" ;;
  *) echo "curl-shim: refusing unmapped URL $url" >&2; exit 22 ;;
esac
echo "$url" >> "$FAKE_ROOT/requests.log"
[ -f "$f" ] || { echo "curl-shim: 404 $url" >&2; exit 22; }
if [ -n "$out" ]; then cp "$f" "$out"; else cat "$f"; fi
SHIM
chmod +x "$WORK/bin/curl"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL $1"; }

SYS_PATH="/usr/bin:/bin:/usr/sbin:/sbin"
run_install() { # $1 = fake root, $2 = home, rest = env assignments
  root="$1"; home="$2"; shift 2
  mkdir -p "$home"
  env -i PATH="$WORK/bin:$SYS_PATH" HOME="$home" FAKE_ROOT="$root" \
      BEEBEEB_CLI_NO_MODIFY_PATH=1 "$@" sh "$SCRIPT" > "$root/out.log" 2>&1
}

# 1. tampered
run_install "$WORK/fake-tampered" "$WORK/home-t"; rc=$?
[ -s "$WORK/fake-tampered/requests.log" ] && ok "tampered: installer fetched through the fake GitHub" || bad "tampered: installer never used the fake GitHub"
[ "$rc" -ne 0 ] && ok "tampered: exit $rc (non-zero)" || bad "tampered: exit 0 — tampered archive accepted"
grep -qi 'checksum' "$WORK/fake-tampered/out.log" && ok "tampered: output names a checksum failure" || bad "tampered: no checksum message in output"
if find "$WORK/home-t" -name bb -type f 2>/dev/null | grep -q .; then
  bad "tampered: a bb binary was installed: $(find "$WORK/home-t" -name bb -type f | head -1)"
else
  ok "tampered: no bb installed"
fi
[ "$rc" -eq 0 ] || [ "$FAIL" -eq 0 ] || sed 's/^/      | /' "$WORK/fake-tampered/out.log"

# 2. clean
run_install "$WORK/fake-clean" "$WORK/home-c"; rc=$?
[ "$rc" -eq 0 ] && ok "clean: exit 0" || { bad "clean: exit $rc"; sed 's/^/      | /' "$WORK/fake-clean/out.log"; }
BB="$(find "$WORK/home-c" -name bb -type f 2>/dev/null | head -1)"
if [ -n "$BB" ] && HOME="$WORK/home-c" "$BB" --version 2>/dev/null | grep -q '0\.10\.0'; then
  ok "clean: installed bb reports 0.10.0 (${BB#"$WORK"/})"
else
  bad "clean: no working bb 0.10.0 installed"
fi

# 3. INSTALL_DIR compatibility
rm -f "$WORK/fake-clean/requests.log"
run_install "$WORK/fake-clean" "$WORK/home-d" INSTALL_DIR="$WORK/flat"; rc=$?
if [ "$rc" -eq 0 ] && [ -x "$WORK/flat/bb" ] && "$WORK/flat/bb" --version 2>/dev/null | grep -q '0\.10\.0'; then
  ok "INSTALL_DIR: bb 0.10.0 installed flat at \$INSTALL_DIR/bb"
else
  bad "INSTALL_DIR: expected \$INSTALL_DIR/bb (exit $rc)"; sed 's/^/      | /' "$WORK/fake-clean/out.log"
fi

# 4. no sha256sum available: system tools mirrored minus sha256sum
mkdir -p "$WORK/nosha"
for d in /usr/bin /bin /usr/sbin /sbin; do
  for t in "$d"/*; do
    n="$(basename "$t")"
    [ "$n" = sha256sum ] && continue
    [ -e "$WORK/nosha/$n" ] || ln -s "$t" "$WORK/nosha/$n"
  done
done
rm -f "$WORK/fake-tampered/requests.log"
SYS_PATH="$WORK/nosha" run_install "$WORK/fake-tampered" "$WORK/home-n"; rc=$?
if [ "$rc" -ne 0 ] && ! find "$WORK/home-n" -name bb -type f 2>/dev/null | grep -q .; then
  ok "no sha256sum: refused (exit $rc), nothing installed"
else
  bad "no sha256sum: tampered archive installed unverified (exit $rc)"; sed 's/^/      | /' "$WORK/fake-tampered/out.log"
fi

echo "$PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ] && [ "$PASS" -gt 0 ]
