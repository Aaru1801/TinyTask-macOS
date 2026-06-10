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

# Stamp a monotonically-increasing build number (before signing — editing the
# plist afterwards would invalidate the signature).
BUILD_NUM=$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUM" "${CONTENTS}/Info.plist"

# Ad-hoc sign so accessibility permissions stick across rebuilds.
# A signing failure should abort the build loudly, not be swallowed.
echo "→ Ad-hoc signing..."
codesign --force --sign - "$APP_BUNDLE"

echo
echo "✅ Built: ${APP_BUNDLE}"
echo "   Run:  open \"${APP_BUNDLE}\""
echo "   Move to /Applications for stable permissions:"
echo "     mv \"${APP_BUNDLE}\" /Applications/"
