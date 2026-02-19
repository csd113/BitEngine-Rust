#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# build_bundle.sh
# Build bitcoin_node_manager in release mode and package it as a macOS .app.
#
# Usage:
#   ./build_bundle.sh [--target aarch64-apple-darwin|x86_64-apple-darwin]
#
# The resulting .app is placed in:
#   ./dist/BitcoinNodeManager.app
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
APP_NAME="BitcoinNodeManager"
BUNDLE_ID="com.bitcoinnodemanager.app"
VERSION="0.1.0"
BINARY_NAME="bitcoin_node_manager"

# Detect host architecture; default to Apple Silicon
HOST_ARCH=$(uname -m)
if [[ "${HOST_ARCH}" == "arm64" ]]; then
    DEFAULT_TARGET="aarch64-apple-darwin"
else
    DEFAULT_TARGET="x86_64-apple-darwin"
fi

TARGET="${1:-$DEFAULT_TARGET}"
# Allow overriding via CLI argument
if [[ "${1:-}" == "--target" && -n "${2:-}" ]]; then
    TARGET="$2"
fi

echo "==> Building for target: ${TARGET}"

# ── Ensure target is installed ────────────────────────────────────────────────
rustup target add "${TARGET}" 2>/dev/null || true

# ── Compile ───────────────────────────────────────────────────────────────────
cargo build --release --target "${TARGET}"

BINARY="target/${TARGET}/release/${BINARY_NAME}"
if [[ ! -f "${BINARY}" ]]; then
    echo "ERROR: Binary not found at ${BINARY}" >&2
    exit 1
fi

# ── Create .app structure ─────────────────────────────────────────────────────
DIST="dist/${APP_NAME}.app"
CONTENTS="${DIST}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

rm -rf "${DIST}"
mkdir -p "${MACOS}" "${RESOURCES}"

# Copy binary
cp "${BINARY}" "${MACOS}/${APP_NAME}"
chmod +x "${MACOS}/${APP_NAME}"

# ── Info.plist ────────────────────────────────────────────────────────────────
cat > "${CONTENTS}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>Bitcoin Node Manager</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <!-- Required for file-picker access -->
    <key>NSDocumentsFolderUsageDescription</key>
    <string>Bitcoin Node Manager needs access to read and write node data.</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>Bitcoin Node Manager may access the Desktop.</string>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>Bitcoin Node Manager reads binary builds from Downloads.</string>
</dict>
</plist>
PLIST

echo "==> Bundle created at: ${DIST}"
echo ""

# ── Optional: ad-hoc codesign ─────────────────────────────────────────────────
# Ad-hoc signing lets the app run on the same machine without Gatekeeper issues
# when SIP is disabled.  For distribution, replace "-" with your Developer ID.
if command -v codesign &>/dev/null; then
    echo "==> Codesigning (ad-hoc)…"
    codesign --force --deep --sign "-" "${DIST}"
    echo "    Done."
    echo ""
    echo "    For distribution signing:"
    echo "      codesign --force --deep --sign 'Developer ID Application: Your Name (TEAMID)' \\"
    echo "               --options runtime \\"
    echo "               '${DIST}'"
    echo "    Then notarise with:"
    echo "      xcrun notarytool submit '${DIST}' --apple-id YOU@EXAMPLE.COM \\"
    echo "               --team-id TEAMID --password APP_SPECIFIC_PASSWORD --wait"
fi

echo ""
echo "==> To run the app from the SSD root:"
echo "    Place ${APP_NAME}.app at the root of the SSD."
echo "    The app auto-detects the SSD root from its location."
echo ""
echo "    Or launch directly:"
echo "    open '${DIST}'"
