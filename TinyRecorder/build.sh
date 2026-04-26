#!/bin/bash
# Build a proper TinyRecorder.app bundle (required for menu bar apps so
# Accessibility / Input Monitoring permissions remain stable).
set -euo pipefail

APP_NAME="TinyRecorder"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${ROOT}/.build/release"
APP_BUNDLE="${ROOT}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"

cd "$ROOT"

# Regenerate the icon if the source script is newer than the .icns (or it's missing).
if [ ! -f "AppIcon.icns" ] || [ "tools/make_icon.swift" -nt "AppIcon.icns" ]; then
    echo "→ Generating AppIcon.icns..."
    swift tools/make_icon.swift
    iconutil -c icns AppIcon.iconset -o AppIcon.icns
fi

echo "→ Compiling (release)..."
swift build -c release

echo "→ Bundling ${APP_NAME}.app..."
rm -rf "$APP_BUNDLE"
mkdir -p "${CONTENTS}/MacOS"
mkdir -p "${CONTENTS}/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${CONTENTS}/MacOS/${APP_NAME}"
cp "${ROOT}/Info.plist" "${CONTENTS}/Info.plist"
cp "${ROOT}/AppIcon.icns" "${CONTENTS}/Resources/AppIcon.icns"
chmod +x "${CONTENTS}/MacOS/${APP_NAME}"

# Ad-hoc sign so accessibility permissions stick across rebuilds.
echo "→ Ad-hoc signing..."
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true

echo
echo "✅ Built: ${APP_BUNDLE}"
echo "   Run:  open \"${APP_BUNDLE}\""
echo "   Move to /Applications for stable permissions:"
echo "     mv \"${APP_BUNDLE}\" /Applications/"
echo
echo "ℹ️  Note: do NOT distribute the built .app directly."
echo "   macOS Gatekeeper will block unsigned/unnotarized binaries downloaded"
echo "   from the internet with a 'damaged' error. Users should build from source."
echo "   If you must share a pre-built binary, run:"
echo "     xattr -cr \"${APP_BUNDLE}\""
echo "   on the *recipient's* machine after downloading to strip the quarantine flag."
