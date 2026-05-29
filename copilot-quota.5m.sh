#!/usr/bin/env bash
# <bitbar.title>GitHub Copilot Quota</bitbar.title>
# <bitbar.version>1.0.0</bitbar.version>
# <bitbar.author>Adam Geipel</bitbar.author>
# <bitbar.author.github>adam-geipel</bitbar.author.github>
# <bitbar.desc>Shows GitHub Copilot premium request quota with overage indicator</bitbar.desc>
# <bitbar.dependencies>gh,python3,curl</bitbar.dependencies>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>false</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>false</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>
# <swiftbar.environment>[WIDGET_DIR=~/.config/copilot-quota-widget]</swiftbar.environment>

WIDGET_DIR="${WIDGET_DIR:-$HOME/.config/copilot-quota-widget}"
QUOTA_FILE="$WIDGET_DIR/quota.json"
ERROR_FILE="$WIDGET_DIR/quota_error.txt"
CONFIG_FILE="$WIDGET_DIR/config.json"
FETCH_SCRIPT="$WIDGET_DIR/fetch_quota.sh"

# ── actions passed as env vars from SwiftBar menu clicks ───────────────────────
if [[ "${ACTION:-}" == "refresh" ]]; then
  bash "$FETCH_SCRIPT"
  exit 0
fi

if [[ "${ACTION:-}" == "toggle_overlay" ]]; then
  python3 - <<PYEOF
import json, os
cfg_path = os.path.expanduser("$CONFIG_FILE")
try:
    cfg = json.load(open(cfg_path))
except Exception:
    cfg = {}
cfg["overlay_enabled"] = not cfg.get("overlay_enabled", False)
json.dump(cfg, open(cfg_path, "w"), indent=2)
PYEOF
  exit 0
fi

if [[ "${ACTION:-}" == "open_settings" ]]; then
  open "https://github.com/settings/copilot"
  exit 0
fi

# ── trigger background refresh (non-blocking) ─────────────────────────────────
bash "$FETCH_SCRIPT" &>/dev/null &

# ── read cached data ──────────────────────────────────────────────────────────
if [[ -f "$ERROR_FILE" ]]; then
  ERROR_MSG=$(cat "$ERROR_FILE")
  echo "🤖 !"
  echo "---"
  echo "⚠️ Error fetching quota | color=red"
  echo "$ERROR_MSG | color=red"
  echo "---"
  echo "Refresh | bash='$0' param1=refresh terminal=false refresh=true"
  exit 0
fi

if [[ ! -f "$QUOTA_FILE" ]]; then
  echo "🤖 …"
  echo "---"
  echo "Loading quota data..."
  echo "Refresh | bash='$0' param1=refresh terminal=false refresh=true"
  exit 0
fi

# ── parse quota.json and render ───────────────────────────────────────────────
python3 - <<PYEOF
import json, os, datetime, math

quota_file  = os.path.expanduser("$QUOTA_FILE")
config_file = os.path.expanduser("$CONFIG_FILE")

with open(quota_file) as f:
    q = json.load(f)

try:
    cfg = json.load(open(config_file))
except Exception:
    cfg = {}

entitlement   = q.get("entitlement", 0)
used          = q.get("used", 0)
overage       = q.get("overage_count", 0)
unlimited     = q.get("unlimited", False)
pct_used      = q.get("percent_used", 0.0)
reset_date_s  = q.get("quota_reset_date", "")
fetched_at    = q.get("fetched_at", "")
overlay_on    = cfg.get("overlay_enabled", False)

# ── parse reset date ──────────────────────────────────────────────────────────
try:
    reset_dt   = datetime.datetime.fromisoformat(reset_date_s.replace("Z", "+00:00"))
    now_utc    = datetime.datetime.now(datetime.timezone.utc)
    days_left  = (reset_dt - now_utc).days + 1
    reset_label = reset_dt.strftime("%-d %b")
except Exception:
    days_left  = "?"
    reset_label = reset_date_s[:10] if reset_date_s else "?"

# ── menu bar title ─────────────────────────────────────────────────────────────
if unlimited:
    bar_title = "🤖 ∞"
    color_str = "color=#30d158"  # green
elif pct_used < 75:
    color_str = "color=#30d158"  # green
    bar_title = f"🤖 {pct_used:.0f}%"
elif pct_used < 100:
    color_str = "color=#ffd60a"  # yellow
    bar_title = f"🤖 {pct_used:.0f}%"
else:
    color_str = "color=#ff453a"  # red
    bar_title = f"🤖 {pct_used:.0f}% ↑"

print(f"{bar_title} | {color_str} font=Menlo size=12")
print("---")

if unlimited:
    print("✅ Unlimited quota (enterprise plan)")
    print(f"Plan: {q.get('plan','unknown')}")
else:
    # ── two-tone progress bar ─────────────────────────────────────────────────
    BAR_QUOTA_WIDTH = 20   # chars representing 100% of entitlement
    OVERAGE_MAX_WIDTH = 10 # max chars for overage extension

    quota_fill    = min(int(round(min(pct_used, 100) / 100 * BAR_QUOTA_WIDTH)), BAR_QUOTA_WIDTH)
    quota_empty   = BAR_QUOTA_WIDTH - quota_fill

    # overage segment: each char = 5% of entitlement (so 10 chars = +50% max display)
    overage_pct   = overage / entitlement * 100 if entitlement > 0 else 0
    overage_fill  = min(int(round(overage_pct / 5)), OVERAGE_MAX_WIDTH)

    GREEN  = "\033[32m"
    RED    = "\033[31m"
    YELLOW = "\033[33m"
    DIM    = "\033[2m"
    RESET  = "\033[0m"

    quota_bar   = GREEN  + ("█" * quota_fill)  + RESET
    empty_part  = DIM   + ("░" * quota_empty) + RESET
    overage_bar = RED   + ("█" * overage_fill) + RESET if overage_fill > 0 else ""
    separator   = (RED + "|" + RESET) if overage > 0 else ""

    bar_line = f"[{quota_bar}{empty_part}{separator}{overage_bar}] {pct_used:.0f}%"

    print(f"{bar_line} | ansi=true font=Menlo size=12 trim=false")
    print("---")

    if overage > 0:
        print(f"Used:  {used:,} / {entitlement:,}  (+{overage:,} overage) | color=#ff453a font=Menlo size=11")
    else:
        print(f"Used:  {used:,} / {entitlement:,} | font=Menlo size=11")

    print(f"Resets: {reset_label}  ({days_left}d) | font=Menlo size=11 color=#8e8e93")

print("---")

# ── fetched time ──────────────────────────────────────────────────────────────
try:
    ft = datetime.datetime.fromisoformat(fetched_at.replace("Z", "+00:00"))
    ft_local = ft.astimezone()
    time_str = ft_local.strftime("%-I:%M %p")
except Exception:
    time_str = fetched_at
print(f"Updated {time_str} | color=#8e8e93 size=10")

# ── actions ───────────────────────────────────────────────────────────────────
print("---")
print(f"Refresh Now | bash='{os.path.expanduser('$0')}' param1=refresh terminal=false refresh=true")
print(f"Open Copilot Settings | bash='{os.path.expanduser('$0')}' param1=open_settings terminal=false")

overlay_label = "✅ Desktop Overlay (on)" if overlay_on else "Desktop Overlay (off)"
print(f"{overlay_label} | bash='{os.path.expanduser('$0')}' param1=toggle_overlay terminal=false refresh=true")
PYEOF
