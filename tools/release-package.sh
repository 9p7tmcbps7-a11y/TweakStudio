#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 2 ]]; then echo "Usage: $0 THEOS_PACKAGE.deb RELEASE_PACKAGE.deb" >&2; exit 2; fi
INPUT="$(realpath "$1")"
OUTPUT="$(realpath -m "$2")"
THEOS="${THEOS:-$HOME/theos}"
ALLEMANDE="${ALLEMANDE:-/var/mobile/Documents/TweakStudio/bin/allemande}"
BIN="$THEOS/toolchain/linux/iphone/bin"
for tool in dpkg-deb perl; do command -v "$tool" >/dev/null || { echo "Missing tool: $tool" >&2; exit 1; }; done
for tool in otool ldid; do [[ -x "$BIN/$tool" ]] || { echo "Missing tool: $BIN/$tool" >&2; exit 1; }; done
[[ -x "$ALLEMANDE" ]] || { echo "Missing allemande converter: $ALLEMANDE (set ALLEMANDE to its path)" >&2; exit 1; }
[[ -f "$THEOS/bin/dm.pl" && -f "$INPUT" ]] || { echo "Missing Theos dm.pl or input package." >&2; exit 1; }
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
ROOT="$WORK/root"; mkdir -p "$ROOT/DEBIAN"
dpkg-deb -x "$INPUT" "$ROOT"
dpkg-deb -e "$INPUT" "$ROOT/DEBIAN"
while IFS= read -r -d '' FILE; do
  [[ -L "$FILE" ]] && continue
  if "$BIN/otool" -hv "$FILE" 2>/dev/null | grep -q 'arm64e'; then
    "$ALLEMANDE" "$FILE" "$WORK/converted"
    "$BIN/ldid" -s "$WORK/converted"
    "$BIN/ldid" -S "$WORK/converted"
    mv "$WORK/converted" "$FILE"
  fi
done < <(find "$ROOT" -type f -not -path '*/DEBIAN/*' -print0)
chmod 755 "$ROOT/DEBIAN"
perl "$THEOS/bin/dm.pl" --compression lzma --compress-level 9 "$ROOT" "$OUTPUT"
dpkg-deb --info "$OUTPUT" >/dev/null
echo "Release package: $OUTPUT"
