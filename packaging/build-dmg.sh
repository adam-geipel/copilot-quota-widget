#!/usr/bin/env bash
# build-dmg.sh — builds CopilotQuotaWidget.dmg
#
# Output: packaging/dist/CopilotQuotaWidget.dmg
#
# Before running:
#   1. Ensure packaging/CopilotQuotaWidget.app is fully assembled
#      (SwiftBar.app + gh + widget scripts in Resources/)
#   2. Run from repo root: bash packaging/build-dmg.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="CopilotQuotaWidget"
APP_SRC="$SCRIPT_DIR/${APP_NAME}.app"
DIST_DIR="$SCRIPT_DIR/dist"
DMG_OUT="$DIST_DIR/${APP_NAME}.dmg"
VOL_NAME="Copilot Quota Widget"

mkdir -p "$DIST_DIR"
rm -f "$DMG_OUT"

# ── app bundle sanity checks ──────────────────────────────────────────────────
[[ -d "$APP_SRC" ]]                                         || { echo "ERROR: $APP_SRC not found"; exit 1; }
[[ -x "$APP_SRC/Contents/MacOS/install" ]]                  || { echo "ERROR: installer not executable"; exit 1; }
[[ -d "$APP_SRC/Contents/Resources/SwiftBar.app" ]]         || { echo "ERROR: SwiftBar.app not bundled"; exit 1; }
[[ -x "$APP_SRC/Contents/Resources/gh" ]]                   || { echo "ERROR: gh binary not bundled"; exit 1; }
[[ -f "$APP_SRC/Contents/Resources/widget/fetch_quota.sh" ]] || { echo "ERROR: fetch_quota.sh not bundled"; exit 1; }

echo "Building ${APP_NAME}.dmg..."

# ── build staging dir ─────────────────────────────────────────────────────────
STAGING=$(mktemp -d)
cp -R "$APP_SRC" "$STAGING/${APP_NAME}.app"
ln -s "$HOME/Applications" "$STAGING/Applications"

# ── create DMG directly from staging folder (no intermediate writable image) ──
hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDRO \
  "$DMG_OUT" \
  -quiet

rm -rf "$STAGING"

SIZE=$(du -sh "$DMG_OUT" | awk '{print $1}')
echo "Done: $DMG_OUT  ($SIZE)"
