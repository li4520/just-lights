#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SDK_BASE_DIR="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks"
SDK_DEFAULT="$("$ROOT_DIR/scripts/find_connectiq_sdk.sh" "$SDK_BASE_DIR")"
SDK_HOME="${CIQ_SDK_HOME:-$SDK_DEFAULT}"
KEY_PATH="${CIQ_DEVELOPER_KEY:-$ROOT_DIR/developer_key}"
BIN_DIR="$ROOT_DIR/build/bin"
SUPPORTED_DEVICES=(edge1050 edge1040 edge850 edge840 edgeexplore2)
TARGET_DEVICE="${1:-${LIGHT820_DEVICE:-edge1050}}"

if [[ -z "$SDK_HOME" || ! -x "$SDK_HOME/bin/monkeyc" ]]; then
  echo "Unable to locate a usable Connect IQ SDK. Set CIQ_SDK_HOME or install one via Garmin SDK Manager." >&2
  exit 1
fi

if [[ ! -f "$KEY_PATH" ]]; then
  echo "Unable to locate a Connect IQ developer key." >&2
  echo "Set CIQ_DEVELOPER_KEY or place a local key at: $KEY_PATH" >&2
  exit 1
fi

is_supported_device() {
  local device="$1"
  local supported
  for supported in "${SUPPORTED_DEVICES[@]}"; do
    if [[ "$supported" == "$device" ]]; then
      return 0
    fi
  done
  return 1
}

build_target() {
  local device="$1"
  local output_path="$BIN_DIR/Light820_${device}.prg"

  "$SDK_HOME/bin/monkeyc" \
    -f "$ROOT_DIR/monkey.jungle" \
    -o "$output_path" \
    -d "$device" \
    -y "$KEY_PATH"

  cp "$output_path" "$BIN_DIR/Light820.prg"
  echo "Built: $output_path"
}

mkdir -p "$BIN_DIR"

if [[ "$TARGET_DEVICE" == "all" ]]; then
  for device in "${SUPPORTED_DEVICES[@]}"; do
    build_target "$device"
  done
  exit 0
fi

if ! is_supported_device "$TARGET_DEVICE"; then
  echo "Unsupported Light820 target: $TARGET_DEVICE" >&2
  echo "Supported targets: ${SUPPORTED_DEVICES[*]} or all" >&2
  exit 1
fi

build_target "$TARGET_DEVICE"
