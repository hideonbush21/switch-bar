#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${SWITCHBAR_BUILD_DIR:-"$ROOT_DIR/.build/switchbar-manual"}"
RUN_TESTS=1
BUILD_ONLY=0
BACKGROUND=0

usage() {
  cat <<'EOF'
Usage: scripts/start.sh [options]

Options:
  --skip-tests   Build and start SwitchBar without running core tests.
  --build-only   Build SwitchBar and exit without starting the app.
  --background   Start SwitchBar in the background and return to the shell.
  -h, --help     Show this help message.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --skip-tests)
      RUN_TESTS=0
      ;;
    --build-only)
      BUILD_ONLY=1
      ;;
    --background)
      BACKGROUND=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if ! command -v swiftc >/dev/null 2>&1; then
  echo "swiftc not found. Please install Xcode or Command Line Tools." >&2
  exit 1
fi

mkdir -p "$BUILD_DIR"

echo "==> Building SwitchBarCore"
swiftc -emit-library -emit-module \
  -module-name SwitchBarCore \
  "$ROOT_DIR"/Sources/SwitchBarCore/*.swift \
  -o "$BUILD_DIR/libSwitchBarCore.dylib" \
  -emit-module-path "$BUILD_DIR/SwitchBarCore.swiftmodule"

if [ "$RUN_TESTS" -eq 1 ]; then
  echo "==> Building SwitchBarCoreTestRunner"
  swiftc -I "$BUILD_DIR" -L "$BUILD_DIR" -lSwitchBarCore \
    "$ROOT_DIR/Sources/SwitchBarCoreTestRunner/main.swift" \
    -o "$BUILD_DIR/SwitchBarCoreTestRunner"

  echo "==> Running core tests"
  DYLD_LIBRARY_PATH="$BUILD_DIR" "$BUILD_DIR/SwitchBarCoreTestRunner"
fi

echo "==> Building SwitchBar app"
swiftc -I "$BUILD_DIR" -L "$BUILD_DIR" -lSwitchBarCore \
  "$ROOT_DIR"/Sources/SwitchBar/*.swift \
  -o "$BUILD_DIR/SwitchBar"

if [ "$BUILD_ONLY" -eq 1 ]; then
  echo "==> Build complete: $BUILD_DIR/SwitchBar"
  exit 0
fi

echo "==> Starting SwitchBar"
if [ "$BACKGROUND" -eq 1 ]; then
  LOG_FILE="$BUILD_DIR/SwitchBar.log"
  DYLD_LIBRARY_PATH="$BUILD_DIR" "$BUILD_DIR/SwitchBar" >"$LOG_FILE" 2>&1 &
  echo "SwitchBar started in background. PID=$!, log=$LOG_FILE"
else
  echo "SwitchBar is running in the foreground. Press Ctrl+C to stop it."
  exec env DYLD_LIBRARY_PATH="$BUILD_DIR" "$BUILD_DIR/SwitchBar"
fi
