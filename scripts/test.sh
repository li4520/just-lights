#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SDK_BASE_DIR="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks"
SDK_DEFAULT="$("$ROOT_DIR/scripts/find_connectiq_sdk.sh" "$SDK_BASE_DIR")"
SDK_HOME="${CIQ_SDK_HOME:-$SDK_DEFAULT}"
KEY_PATH="${CIQ_DEVELOPER_KEY:-$ROOT_DIR/developer_key}"
BUILD_ONLY=0
if [[ "${1:-}" == "--build-only" ]]; then
  BUILD_ONLY=1
  shift
fi
DEVICE="${1:-edge1050}"
TEST_FILTER="${2:-}"
APP_PATH="$ROOT_DIR/build/bin/Light820_tests.prg"
SIM_BIN="$SDK_HOME/bin/ConnectIQ.app/Contents/MacOS/simulator"
RUN_OUTPUT="$(mktemp)"
trap 'rm -f "$RUN_OUTPUT"' EXIT

if [[ -z "$SDK_HOME" || ! -x "$SDK_HOME/bin/monkeyc" ]]; then
  echo "Unable to locate a usable Connect IQ SDK. Set CIQ_SDK_HOME or install one via Garmin SDK Manager." >&2
  exit 1
fi

if [[ ! -f "$KEY_PATH" ]]; then
  echo "Unable to locate a Connect IQ developer key." >&2
  echo "Set CIQ_DEVELOPER_KEY or place a local key at: $KEY_PATH" >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/build/bin"

"$SDK_HOME/bin/monkeyc" \
  -f "$ROOT_DIR/monkey_tests.jungle" \
  -o "$APP_PATH" \
  -d "$DEVICE" \
  -y "$KEY_PATH" \
  --unit-test
echo "Built Light820 unit-test PRG: $APP_PATH"

if [[ "$BUILD_ONLY" == "1" ]]; then
  exit 0
fi

if ! pgrep -f "$SIM_BIN" >/dev/null 2>&1; then
  "$SDK_HOME/bin/connectiq" >/dev/null 2>&1 &
  sleep 3
fi

for _ in 1 2 3 4 5; do
  if [[ -n "$TEST_FILTER" ]]; then
    if "$SDK_HOME/bin/monkeydo" "$APP_PATH" "$DEVICE" -t "$TEST_FILTER" 2>&1 | tee "$RUN_OUTPUT"; then
      exit 0
    fi
  else
    if "$SDK_HOME/bin/monkeydo" "$APP_PATH" "$DEVICE" -t 2>&1 | tee "$RUN_OUTPUT"; then
      exit 0
    fi
  fi

  if grep -Eq "PASSED \\(passed=[0-9]+, failed=0, errors=0\\)" "$RUN_OUTPUT"; then
    exit 0
  fi

  "$SDK_HOME/bin/connectiq" >/dev/null 2>&1 &
  sleep 2
done

echo "Unable to run Light820 unit tests in simulator after retries."
echo "Try opening the Connect IQ Simulator app manually, then rerun this script."
exit 1
