#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-0.1.0}"
RELEASE_DIR="$ROOT_DIR/build/release/v$VERSION"
SUPPORTED_DEVICES=(edge1050 edge1040 edge850 edge840 edgeexplore2)

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

"$ROOT_DIR/scripts/build.sh" all

for device in "${SUPPORTED_DEVICES[@]}"; do
  source_path="$ROOT_DIR/build/bin/Light820_${device}.prg"
  target_path="$RELEASE_DIR/JustLights_${device}_v$VERSION.prg"
  if [[ ! -f "$source_path" ]]; then
    echo "Missing build output: $source_path" >&2
    exit 1
  fi
  cp "$source_path" "$target_path"
done

(
  cd "$RELEASE_DIR"
  shasum -a 256 ./*.prg > SHA256SUMS.txt
)

echo "Release assets staged at: $RELEASE_DIR"
