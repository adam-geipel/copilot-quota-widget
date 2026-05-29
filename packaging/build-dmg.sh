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
TMP_DMG="$DIST_DIR/${APP_NAME}-tmp.dmg"
VOL_NAME="CopilotQuotaWidget"
MOUNT_POINT="/Volumes/${VOL_NAME}"

mkdir -p "$DIST_DIR"
rm -f "$DMG_OUT" "$TMP_DMG"

# ── app bundle sanity checks ──────────────────────────────────────────────────
[[ -d "$APP_SRC" ]]                                         || { echo "ERROR: $APP_SRC not found"; exit 1; }
[[ -x "$APP_SRC/Contents/MacOS/install" ]]                  || { echo "ERROR: installer not executable"; exit 1; }
[[ -d "$APP_SRC/Contents/Resources/SwiftBar.app" ]]         || { echo "ERROR: SwiftBar.app not bundled"; exit 1; }
[[ -x "$APP_SRC/Contents/Resources/gh" ]]                   || { echo "ERROR: gh binary not bundled"; exit 1; }
[[ -f "$APP_SRC/Contents/Resources/widget/fetch_quota.sh" ]] || { echo "ERROR: fetch_quota.sh not bundled"; exit 1; }

echo "Building ${APP_NAME}.dmg..."

# ── calculate size (app + 20% headroom, min 60MB) ─────────────────────────────
APP_SIZE_KB=$(du -sk "$APP_SRC" | awk '{print $1}')
DMG_SIZE_KB=$(( APP_SIZE_KB * 12 / 10 ))
(( DMG_SIZE_KB < 61440 )) && DMG_SIZE_KB=61440   # 60MB minimum

# ── create writable DMG ───────────────────────────────────────────────────────
hdiutil create \
  -size "${DMG_SIZE_KB}k" \
  -fs HFS+ \
  -volname "$VOL_NAME" \
  -layout NONE \
  "$TMP_DMG" \
  -quiet

# ── mount ─────────────────────────────────────────────────────────────────────
hdiutil attach "$TMP_DMG" -mountpoint "$MOUNT_POINT" -quiet -noverify

# ── populate ──────────────────────────────────────────────────────────────────
cp -R "$APP_SRC" "$MOUNT_POINT/${APP_NAME}.app"

# Symlink to ~/Applications for drag-install
ln -s "$HOME/Applications" "$MOUNT_POINT/Applications"

# ── set DMG window appearance via AppleScript ─────────────────────────────────
osascript <<ASEOF
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {400, 200, 900, 480}
    set theViewOptions to icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 96
    set position of item "${APP_NAME}.app" of container window to {140, 130}
    set position of item "Applications" of container window to {360, 130}
    close
    open
    update without registering applications
    delay 2
    close
  end tell
end tell
ASEOF

sync
hdiutil detach "$MOUNT_POINT" -quiet

# ── convert to compressed read-only DMG ───────────────────────────────────────
hdiutil convert "$TMP_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_OUT" \
  -quiet

rm -f "$TMP_DMG"

SIZE=$(du -sh "$DMG_OUT" | awk '{print $1}')
echo "Done: $DMG_OUT  ($SIZE)"
