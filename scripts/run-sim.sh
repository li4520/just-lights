#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SDK_BASE_DIR="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks"
SDK_DEFAULT="$("$ROOT_DIR/scripts/find_connectiq_sdk.sh" "$SDK_BASE_DIR")"
SDK_HOME="${CIQ_SDK_HOME:-$SDK_DEFAULT}"
TARGET_DEVICE="${1:-${LIGHT820_DEVICE:-edge1050}}"
APP_PATH="$ROOT_DIR/build/bin/Light820_${TARGET_DEVICE}.prg"
SIM_BIN="$SDK_HOME/bin/ConnectIQ.app/Contents/MacOS/simulator"
SIM_RESET="${LIGHT820_SIM_RESET:-1}"
SUPPORTED_DEVICES=(edge1050 edge1040 edge850 edge840 edgeexplore2)

if [[ -z "$SDK_HOME" || ! -x "$SDK_HOME/bin/monkeydo" ]]; then
  echo "Unable to locate a usable Connect IQ SDK. Set CIQ_SDK_HOME or install one via Garmin SDK Manager." >&2
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

if ! is_supported_device "$TARGET_DEVICE"; then
  echo "Unsupported Light820 simulator target: $TARGET_DEVICE" >&2
  echo "Supported targets: ${SUPPORTED_DEVICES[*]}" >&2
  exit 1
fi

if [[ "$SIM_RESET" == "1" ]]; then
  pkill -f "$SIM_BIN" >/dev/null 2>&1 || true
  pkill -f '/bin/monkeydo' >/dev/null 2>&1 || true
  pkill -f 'monkeydodeux.MonkeyDoDeux' >/dev/null 2>&1 || true
  pkill -f '/bin/shell --transport=tcp' >/dev/null 2>&1 || true
  find /private/var/folders -type d -path '*/T/com.garmin.connectiq/GARMIN' -prune -exec rm -rf {} + 2>/dev/null || true
  sleep 1
fi

needs_build=false
if [[ ! -f "$APP_PATH" ]]; then
  needs_build=true
elif find "$ROOT_DIR/source" \
          "$ROOT_DIR/resources" \
          "$ROOT_DIR/manifest.xml" \
          "$ROOT_DIR/monkey.jungle" \
          -newer "$APP_PATH" -print -quit | grep -q .; then
  needs_build=true
fi

if [[ "$needs_build" == true ]]; then
  "$ROOT_DIR/scripts/build_light820.sh" "$TARGET_DEVICE"
fi

pkill -f '/bin/monkeydo' >/dev/null 2>&1 || true
pkill -f 'monkeydodeux.MonkeyDoDeux' >/dev/null 2>&1 || true
pkill -f '/bin/shell --transport=tcp' >/dev/null 2>&1 || true

if ! pgrep -f "$SIM_BIN" >/dev/null 2>&1; then
  "$SDK_HOME/bin/connectiq" >/dev/null 2>&1 &
  sleep 3
fi

for _ in 1 2 3 4 5; do
  if "$SDK_HOME/bin/monkeydo" "$APP_PATH" "$TARGET_DEVICE"; then
    exit 0
  fi
  "$SDK_HOME/bin/connectiq" >/dev/null 2>&1 &
  sleep 2
done

echo "Unable to connect to Light820 simulator after retries."
echo "Try opening the Connect IQ Simulator app manually, then re-run this script."
exit 1
