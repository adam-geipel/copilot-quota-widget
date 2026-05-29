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
UBERSICHT_DIR="$HOME/Library/Application Support/Übersicht/Widgets"

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

# ── brew check ────────────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  error "Homebrew not found. Install it first:"
  echo "    /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  exit 1
fi

# ── gh CLI check ──────────────────────────────────────────────────────────────
section "1 / 5  Checking gh CLI"
if ! command -v gh &>/dev/null; then
  if [[ "$UPDATE_MODE" == false ]]; then
    warn "gh CLI not found. Installing..."
    brew install gh
  else
    error "gh CLI not found — run: brew install gh"
    exit 1
  fi
fi
info "gh CLI found: $(gh --version | head -1)"

if ! gh auth status &>/dev/null; then
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
if [[ -d "/Applications/SwiftBar.app" ]]; then
  info "SwiftBar already installed"
else
  if [[ "$UPDATE_MODE" == false ]]; then
    warn "SwiftBar not found. Installing via brew..."
    brew install --cask swiftbar
    info "SwiftBar installed"
  else
    warn "SwiftBar not found — install with: brew install --cask swiftbar"
  fi
fi

# ── detect SwiftBar plugins directory ─────────────────────────────────────────
SWIFTBAR_PLUGINS=""
# Check SwiftBar's stored preference for plugin directory
SWIFTBAR_PLIST="$HOME/Library/Preferences/com.ameba.SwiftBar.plist"
if [[ -f "$SWIFTBAR_PLIST" ]]; then
  SWIFTBAR_PLUGINS=$(defaults read com.ameba.SwiftBar PluginsDirectory 2>/dev/null || true)
fi
if [[ -z "$SWIFTBAR_PLUGINS" ]]; then
  SWIFTBAR_PLUGINS="$HOME/Library/Application Support/SwiftBar/Plugins"
fi
mkdir -p "$SWIFTBAR_PLUGINS"
info "SwiftBar plugins dir: $SWIFTBAR_PLUGINS"

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

install_file "fetch_quota.sh"                                         "$WIDGET_DIR/fetch_quota.sh"
install_file "copilot-quota.5m.sh"                                    "$WIDGET_DIR/copilot-quota.5m.sh"
install_file "ubersicht/copilot-quota.widget/index.jsx"               "$WIDGET_DIR/ubersicht/copilot-quota.widget/index.jsx"

chmod +x "$WIDGET_DIR/fetch_quota.sh"
chmod +x "$WIDGET_DIR/copilot-quota.5m.sh"

# Write default config if not present
if [[ ! -f "$WIDGET_DIR/config.json" ]]; then
  echo '{"overlay_enabled": false}' > "$WIDGET_DIR/config.json"
  info "  config.json (defaults)"
fi

# ── symlink SwiftBar plugin ───────────────────────────────────────────────────
section "4 / 5  Linking SwiftBar plugin"
PLUGIN_LINK="$SWIFTBAR_PLUGINS/copilot-quota.5m.sh"
# Remove stale link or file
rm -f "$PLUGIN_LINK"
ln -s "$WIDGET_DIR/copilot-quota.5m.sh" "$PLUGIN_LINK"
info "Symlinked: $PLUGIN_LINK → $WIDGET_DIR/copilot-quota.5m.sh"

# ── optional Übersicht overlay ────────────────────────────────────────────────
section "5 / 5  Übersicht desktop overlay (optional)"
INSTALL_UBERSICHT=false

if [[ -d "/Applications/Übersicht.app" ]]; then
  info "Übersicht already installed"
  INSTALL_UBERSICHT=true
elif [[ "$UPDATE_MODE" == false ]]; then
  read -r -p "  Install Übersicht for desktop overlay widget? [y/N] " yn
  if [[ "${yn,,}" == "y" ]]; then
    brew install --cask ubersicht
    INSTALL_UBERSICHT=true
  else
    info "Skipping Übersicht. Enable later from the SwiftBar menu if desired."
  fi
fi

if [[ "$INSTALL_UBERSICHT" == true ]]; then
  mkdir -p "$UBERSICHT_DIR"
  WIDGET_LINK="$UBERSICHT_DIR/copilot-quota.widget"
  rm -f "$WIDGET_LINK"
  ln -s "$WIDGET_DIR/ubersicht/copilot-quota.widget" "$WIDGET_LINK"
  info "Symlinked: $WIDGET_LINK"
  info "Enable overlay from the SwiftBar ⬇ menu → 'Desktop Overlay (off)'"
fi

# ── initial fetch ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Fetching quota data...${NC}"
if bash "$WIDGET_DIR/fetch_quota.sh"; then
  QUOTA_PCT=$(python3 -c "import json; d=json.load(open('$WIDGET_DIR/quota.json')); print(f\"{d['percent_used']:.0f}%  ({d['used']:,} / {d['entitlement']:,})\")" 2>/dev/null || echo "see $WIDGET_DIR/quota.json")
  info "Quota fetched: $QUOTA_PCT"
else
  warn "Initial fetch failed — plugin will retry automatically every 5 min"
fi

# ── done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}✓ Installation complete!${NC}"
echo ""
echo "  • Open SwiftBar (or restart it) to see 🤖 in your menu bar"
echo "  • Click the icon → 'Refresh Now' to force an immediate update"
if [[ "$INSTALL_UBERSICHT" == true ]]; then
  echo "  • Enable desktop overlay: click 🤖 → 'Desktop Overlay (off)'"
fi
echo ""
echo "  Update later:  cd \$(dirname \$(readlink \"$PLUGIN_LINK\")) && git pull && ./install.sh --update"
echo "  Repo:          $REPO_URL"
echo ""
