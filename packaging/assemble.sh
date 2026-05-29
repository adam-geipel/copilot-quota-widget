#!/usr/bin/env bash
# assemble.sh — downloads and bundles SwiftBar + gh CLI into the .app Resources
# Run once before build-dmg.sh, and whenever updating bundled versions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESOURCES="$SCRIPT_DIR/CopilotQuotaWidget.app/Contents/Resources"

# ── version pins ──────────────────────────────────────────────────────────────
SWIFTBAR_VERSION="v2.0.1"
SWIFTBAR_URL="https://github.com/swiftbar/SwiftBar/releases/download/${SWIFTBAR_VERSION}/SwiftBar.${SWIFTBAR_VERSION}.b536.zip"

GH_VERSION="v2.93.0"
GH_BASE="https://github.com/cli/cli/releases/download/${GH_VERSION}"

echo "Assembling CopilotQuotaWidget.app/Contents/Resources..."

mkdir -p "$RESOURCES/widget"

# ── widget scripts ────────────────────────────────────────────────────────────
echo "  Copying widget scripts..."
cp "$REPO_ROOT/fetch_quota.sh"          "$RESOURCES/widget/fetch_quota.sh"
cp "$REPO_ROOT/copilot-quota.5m.sh"     "$RESOURCES/widget/copilot-quota.5m.sh"
chmod +x "$RESOURCES/widget/"*.sh

# ── SwiftBar ──────────────────────────────────────────────────────────────────
echo "  Downloading SwiftBar ${SWIFTBAR_VERSION}..."
rm -rf "$RESOURCES/SwiftBar.app"
TMP_ZIP=$(mktemp /tmp/swiftbar-XXXXXX.zip)
curl -fsSL --progress-bar "$SWIFTBAR_URL" -o "$TMP_ZIP"
unzip -qo "$TMP_ZIP" -d "$RESOURCES"
rm -f "$TMP_ZIP"
rm -rf "$RESOURCES/__MACOSX"
echo "  SwiftBar bundled: $(du -sh "$RESOURCES/SwiftBar.app" | awk '{print $1}')"

# ── gh CLI (universal binary) ─────────────────────────────────────────────────
echo "  Downloading gh CLI ${GH_VERSION} (amd64 + arm64)..."
TMP=$(mktemp -d)
GH_VER_NUM="${GH_VERSION#v}"
curl -fsSL --progress-bar "${GH_BASE}/gh_${GH_VER_NUM}_macOS_amd64.zip" -o "$TMP/amd64.zip"
curl -fsSL --progress-bar "${GH_BASE}/gh_${GH_VER_NUM}_macOS_arm64.zip" -o "$TMP/arm64.zip"
unzip -qo "$TMP/amd64.zip" -d "$TMP/amd64"
unzip -qo "$TMP/arm64.zip" -d "$TMP/arm64"
AMD=$(find "$TMP/amd64" -name "gh" -type f | head -1)
ARM=$(find "$TMP/arm64" -name "gh" -type f | head -1)
lipo -create -output "$RESOURCES/gh" "$AMD" "$ARM"
chmod +x "$RESOURCES/gh"
rm -rf "$TMP"
echo "  gh bundled: $(file "$RESOURCES/gh" | grep -o 'universal.*')"

echo ""
echo "Assembly complete. Run: bash packaging/build-dmg.sh"
