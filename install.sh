#!/usr/bin/env bash
# install.sh — one-shot setup for copilot-quota-widget
# Works both as a direct run and as the target of:
#   curl -fsSL https://raw.githubusercontent.com/adam-geipel/copilot-quota-widget/main/install.sh | bash
#
# Flags:
#   --update   Re-symlink files, skip brew installs and interactive prompts

set -euo pipefail

# ── colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "  ${GREEN}✓${NC}  $*"; }
warn()    { echo -e "  ${YELLOW}!${NC}  $*"; }
error()   { echo -e "  ${RED}✗${NC}  $*"; }
section() { echo -e "\n${BOLD}$*${NC}"; }

UPDATE_MODE=false
for arg in "$@"; do [[ "$arg" == "--update" ]] && UPDATE_MODE=true; done

REPO_URL="https://github.com/adam-geipel/copilot-quota-widget"
RAW_BASE="https://raw.githubusercontent.com/adam-geipel/copilot-quota-widget/main"
WIDGET_DIR="$HOME/.config/copilot-quota-widget"

# ── detect if running from curl (no local files) vs local repo ────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-/dev/stdin}")" 2>/dev/null && pwd || echo "")"
if [[ -f "$SCRIPT_DIR/fetch_quota.sh" ]]; then
  LOCAL_REPO="$SCRIPT_DIR"
else
  LOCAL_REPO=""
fi

# ─────────────────────────────────────────────────────────────────────────────
section "GitHub Copilot Quota Widget — Installer"
echo "  Repo: $REPO_URL"
echo ""

# ── macOS check ───────────────────────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
  error "macOS required. Exiting."
  exit 1
fi

# ── brew check (optional — used only for gh CLI formula install) ─────────────
HAS_BREW=false
command -v brew &>/dev/null && HAS_BREW=true

# ── helper: install a .app from a zip URL ────────────────────────────────────
# Usage: download_app <AppName.app> <zip_url>
# Installs to ~/Applications/ (no sudo, no MDM cask policy).
# Falls back to /Applications/ if user opts in.
download_app() {
  local app_name="$1"
  local zip_url="$2"
  local tmp_zip
  tmp_zip="$(mktemp /tmp/widget-install-XXXXXX.zip)"
  local install_dir="$HOME/Applications"

  mkdir -p "$install_dir"

  warn "$app_name not found. Downloading directly (no brew cask)..."
  if ! curl -fsSL --progress-bar -o "$tmp_zip" "$zip_url"; then
    error "Download failed: $zip_url"
    rm -f "$tmp_zip"
    return 1
  fi

  # Unzip — suppress output, overwrite existing
  unzip -qo "$tmp_zip" -d "$install_dir"
  rm -f "$tmp_zip"

  local app_path="$install_dir/$app_name"
  if [[ ! -d "$app_path" ]]; then
    # Some zips nest inside a subdirectory — find it
    app_path="$(find "$install_dir" -maxdepth 2 -name "$app_name" -type d 2>/dev/null | head -1)"
  fi

  if [[ -z "$app_path" || ! -d "$app_path" ]]; then
    error "Could not find $app_name after unzip."
    return 1
  fi

  # Remove Gatekeeper quarantine flag — required or macOS blocks first launch
  xattr -dr com.apple.quarantine "$app_path" 2>/dev/null || true

  info "$app_name installed → $app_path"
}

# ── helper: find installed .app in /Applications or ~/Applications ────────────
find_app() {
  local app_name="$1"
  if   [[ -d "/Applications/$app_name" ]];      then echo "/Applications/$app_name"
  elif [[ -d "$HOME/Applications/$app_name" ]]; then echo "$HOME/Applications/$app_name"
  else echo ""
  fi
}

# ── gh CLI check ──────────────────────────────────────────────────────────────
section "1 / 5  Checking gh CLI"
if ! command -v gh &>/dev/null; then
  if [[ "$HAS_BREW" == true && "$UPDATE_MODE" == false ]]; then
    warn "gh CLI not found. Installing via brew..."
    brew install gh
  else
    error "gh CLI not found."
    echo ""
    echo "    Install options:"
    echo "      brew install gh"
    echo "      or download from: https://github.com/cli/cli/releases/latest"
    exit 1
  fi
fi
info "gh CLI found: $(gh --version | head -1)"

GH_AUTH_OUT=$(gh auth status 2>&1 || true)
if ! echo "$GH_AUTH_OUT" | grep -q "Logged in"; then
  error "gh CLI not authenticated."
  echo ""
  echo "    Run:  gh auth login"
  echo "    Then re-run this installer."
  exit 1
fi
GH_USER=$(gh api /user --jq '.login' 2>/dev/null || echo "unknown")
info "Authenticated as: $GH_USER"

# ── install SwiftBar ──────────────────────────────────────────────────────────
section "2 / 5  SwiftBar (menu bar host)"
SWIFTBAR_PATH="$(find_app SwiftBar.app)"

if [[ -n "$SWIFTBAR_PATH" ]]; then
  info "SwiftBar already installed: $SWIFTBAR_PATH"
elif [[ "$UPDATE_MODE" == false ]]; then
  download_app "SwiftBar.app" "https://github.com/swiftbar/SwiftBar/releases/latest/download/SwiftBar.zip"
else
  warn "SwiftBar not found — download from: https://github.com/swiftbar/SwiftBar/releases/latest"
fi

# ── configure SwiftBar plugins directory ─────────────────────────────────────
# Read existing pref first — may already be set if SwiftBar was previously used
SWIFTBAR_PLUGINS=$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)

if [[ -z "$SWIFTBAR_PLUGINS" ]]; then
  DEFAULT_PLUGINS="$HOME/.swiftbar/plugins"
  echo ""
  echo "  SwiftBar needs a plugins folder. Choose:"
  echo "    1) $DEFAULT_PLUGINS  (recommended)"
  echo "    2) Enter a custom path"
  echo ""
  read -r -p "  Choice [1]: " plugins_choice
  plugins_choice="${plugins_choice:-1}"

  if [[ "$plugins_choice" == "2" ]]; then
    read -r -p "  Enter full path: " custom_path
    # Expand ~ manually since read won't do it
    SWIFTBAR_PLUGINS="${custom_path/#\~/$HOME}"
  else
    SWIFTBAR_PLUGINS="$DEFAULT_PLUGINS"
  fi

  # Write pref before launching SwiftBar so it never shows the GUI dialog
  defaults write com.ameba.SwiftBar PluginDirectory "$SWIFTBAR_PLUGINS"
  info "SwiftBar plugins dir set: $SWIFTBAR_PLUGINS"
else
  info "SwiftBar plugins dir (existing): $SWIFTBAR_PLUGINS"
fi

mkdir -p "$SWIFTBAR_PLUGINS"

# ── download / update widget files ───────────────────────────────────────────
section "3 / 5  Installing widget files → $WIDGET_DIR"
mkdir -p "$WIDGET_DIR"

install_file() {
  local src_name="$1"
  local dest="$2"
  local dest_dir
  dest_dir="$(dirname "$dest")"
  mkdir -p "$dest_dir"

  if [[ -n "$LOCAL_REPO" && -f "$LOCAL_REPO/$src_name" ]]; then
    cp "$LOCAL_REPO/$src_name" "$dest"
  else
    curl -fsSL "$RAW_BASE/$src_name" -o "$dest"
  fi
  chmod +x "$dest" 2>/dev/null || true
  info "  $src_name"
}

install_file "fetch_quota.sh"          "$WIDGET_DIR/fetch_quota.sh"
install_file "copilot-quota.5m.sh"     "$WIDGET_DIR/copilot-quota.5m.sh"

chmod +x "$WIDGET_DIR/fetch_quota.sh"
chmod +x "$WIDGET_DIR/copilot-quota.5m.sh"

# ── symlink SwiftBar plugin ───────────────────────────────────────────────────
section "4 / 4  Linking SwiftBar plugin"
PLUGIN_LINK="$SWIFTBAR_PLUGINS/copilot-quota.5m.sh"
rm -f "$PLUGIN_LINK"
ln -s "$WIDGET_DIR/copilot-quota.5m.sh" "$PLUGIN_LINK"
info "Symlinked: $PLUGIN_LINK → $WIDGET_DIR/copilot-quota.5m.sh"

# ── initial fetch ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Fetching quota data...${NC}"
if bash "$WIDGET_DIR/fetch_quota.sh"; then
  QUOTA_PCT=$(python3 -c "
import json
d = json.load(open('$WIDGET_DIR/quota.json'))
used, ent = d['used'], d['entitlement']
pct = d['percent_used']
overage = d['overage_count']
overage_str = f'  +{overage:,} overage' if overage > 0 else ''
print(f\"{pct:.0f}%  ({used:,} / {ent:,}){overage_str}\")
" 2>/dev/null || echo "see $WIDGET_DIR/quota.json")
  info "Quota fetched: $QUOTA_PCT"
else
  warn "Initial fetch failed — plugin will retry automatically every 5 min"
fi

# ── open SwiftBar if it isn't running ─────────────────────────────────────────
SWIFTBAR_PATH="$(find_app SwiftBar.app)"
if [[ -n "$SWIFTBAR_PATH" ]]; then
  if ! pgrep -x SwiftBar &>/dev/null; then
    info "Launching SwiftBar..."
    open "$SWIFTBAR_PATH"
  else
    # Tell running SwiftBar to reload plugins
    open -g "swiftbar://refreshAllPlugins" 2>/dev/null || true
    info "SwiftBar refreshed"
  fi
fi

# ── done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}✓ Installation complete!${NC}"
echo ""
echo "  • 🤖 should appear in your menu bar within a few seconds"
echo "  • Click the icon → 'Refresh Now' to force an immediate update"
echo ""
echo "  Update later:"
echo "    cd $WIDGET_DIR && curl -fsSL $RAW_BASE/install.sh | bash -s -- --update"
echo "  Repo: $REPO_URL"
echo ""
