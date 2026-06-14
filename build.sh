#!/bin/bash
# Build TinyRecorder.app and install it to /Applications.
#
# Why /Applications: macOS ties Accessibility / Input Monitoring (TCC) grants to a
# bundle's path *and* code signature. A single bundle at the standard, immutable
# location is the most reliable place for those grants to persist — far better
# than running a copy out of ~/Documents, and it avoids the "every copy needs its
# own grant" trap.
#
# Caveat: we ad-hoc sign (no paid Developer ID), so the bundle has no stable
# signing identity and TCC falls back to the binary's cdhash. The cdhash changes
# on every rebuild, so macOS may ask you to re-grant after an update. The only
# full fix is signing with a stable Developer ID certificate.
set -euo pipefail

APP_NAME="TinyRecorder"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${ROOT}/.build/release"
STAGE="${ROOT}/.build/${APP_NAME}.app"        # assembled here first (gitignored)
INSTALL_DIR="/Applications"
APP_BUNDLE="${INSTALL_DIR}/${APP_NAME}.app"   # final, stable location
CONTENTS="${STAGE}/Contents"

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
rm -rf "$STAGE"
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

echo "→ Installing to ${INSTALL_DIR}..."
rm -rf "$APP_BUNDLE"
mkdir -p "$INSTALL_DIR"
cp -R "$STAGE" "$APP_BUNDLE"

# Strip extended attributes (Finder info / resource forks accreted from copies,
# screenshots, launches) — codesign refuses to sign a bundle that carries them.
xattr -cr "$APP_BUNDLE"

# Ad-hoc sign the installed bundle (see header note on why this doesn't fully
# survive rebuilds). A signing failure should abort the build loudly.
echo "→ Ad-hoc signing..."
codesign --force --sign - "$APP_BUNDLE"

echo
echo "✅ Installed: ${APP_BUNDLE}"
echo "   Run:  open \"${APP_BUNDLE}\""
