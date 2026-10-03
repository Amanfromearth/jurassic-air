#!/usr/bin/env bash
#
# Build JurassicAir.app from the SPM target.
#
# Usage:
#   ./build.sh           # release build, package into JurassicAir.app
#   ./build.sh --open    # ...then open the app
#
# The first time you open the resulting .app, macOS will complain about an
# unidentified developer. Right-click → Open (or run: xattr -d com.apple.quarantine JurassicAir.app).

set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="JurassicAir"
DISPLAY_NAME="Jurassic Air"
BUNDLE_ID="com.anurag.jurassicair"
APP_DIR="${APP_NAME}.app"
RELEASE_DIR=".build/release"

echo "→ swift build -c release"
swift build -c release

echo "→ packaging ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Executable
cp "${RELEASE_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# SPM places resource bundles next to the binary as ${PackageName}_${TargetName}.bundle.
# Bundle.module locates them by walking from the executable, so we put it in MacOS/.
if [ -d "${RELEASE_DIR}/${APP_NAME}_${APP_NAME}.bundle" ]; then
    cp -R "${RELEASE_DIR}/${APP_NAME}_${APP_NAME}.bundle" "${APP_DIR}/Contents/MacOS/"
fi

# App icon: build AppIcon.icns from the 1024×1024 master PNG.
ICON_SRC="Assets/AppIcon.png"
ICONSET=".build/AppIcon.iconset"
rm -rf "${ICONSET}"
mkdir -p "${ICONSET}"
for size in 16 32 128 256 512; do
    sips -z ${size} ${size} "${ICON_SRC}" --out "${ICONSET}/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) "${ICON_SRC}" --out "${ICONSET}/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "${ICONSET}" -o "${APP_DIR}/Contents/Resources/AppIcon.icns"

# Info.plist — LSUIElement hides the Dock icon (menu-bar-only agent app).
cat > "${APP_DIR}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>${DISPLAY_NAME} reads upcoming events to fly a plane with the meeting title before each one starts.</string>
    <key>NSCalendarsUsageDescription</key>
    <string>${DISPLAY_NAME} reads upcoming events to fly a plane with the meeting title before each one starts.</string>
</dict>
</plist>
EOF

# Ad-hoc codesign so SMAppService can identify the bundle.
#
# Why we need each step:
#  1. Strip Swift's linker-signature on the executable. The linker pre-signs
#     with identifier=executable-name and no Info.plist binding, which makes
#     SMAppService.mainApp.status return .notFound.
#  2. Give the SPM resource bundle a minimal Info.plist + sign it. Otherwise
#     deep-signing the .app fails with "bundle format unrecognized" because
#     `*.bundle` directories without an Info.plist confuse codesign.
#  3. Sign the .app with the explicit bundle identifier so the Code Directory
#     uses CFBundleIdentifier (com.anurag.jurassicair) and binds Info.plist.
codesign --remove-signature "${APP_DIR}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true

RESOURCE_BUNDLE="${APP_DIR}/Contents/MacOS/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "${RESOURCE_BUNDLE}" ] && [ ! -f "${RESOURCE_BUNDLE}/Info.plist" ]; then
    cat > "${RESOURCE_BUNDLE}/Info.plist" <<RBPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}.resources</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}Resources</string>
</dict>
</plist>
RBPLIST
fi

codesign --force --sign - "${RESOURCE_BUNDLE}" 2>/dev/null || true
codesign --force --sign - --identifier "${BUNDLE_ID}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
codesign --force --sign - --identifier "${BUNDLE_ID}" "${APP_DIR}"

# Strip quarantine xattr that gets added when downloaded from web.
xattr -cr "${APP_DIR}" 2>/dev/null || true

echo
echo "✓ ${APP_DIR} ready ($(du -sh "${APP_DIR}" | cut -f1))"
echo "  Launch:                open ./${APP_DIR}"
echo "  Auto-launch on boot:   open the settings panel (menu bar ✈ → Settings…) and toggle 'Launch at login'"

if [[ "${1:-}" == "--open" ]]; then
    open "./${APP_DIR}"
fi
