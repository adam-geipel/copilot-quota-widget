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
# <swiftbar.environment>[]</swiftbar.environment>

# Resolve HOME robustly — SwiftBar may not set it
if [[ -z "${HOME:-}" ]]; then
  HOME=$(dscl . -read /Users/"$(whoami)" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
fi
export HOME

# SwiftBar runs with a stripped PATH — add common binary locations
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

WIDGET_DIR="${WIDGET_DIR:-$HOME/.config/copilot-quota-widget}"
# Force-expand any literal tilde that SwiftBar may have injected via environment metadata
WIDGET_DIR="${WIDGET_DIR/#\~/$HOME}"
QUOTA_FILE="$WIDGET_DIR/quota.json"
ERROR_FILE="$WIDGET_DIR/quota_error.txt"
CONFIG_FILE="$WIDGET_DIR/config.json"
FETCH_SCRIPT="$WIDGET_DIR/fetch_quota.sh"

# ── actions passed as positional args from SwiftBar menu clicks ($1) ──────────
if [[ "${1:-}" == "refresh" ]]; then
  bash "$FETCH_SCRIPT"
  exit 0
fi

if [[ "${1:-}" == "open_settings" ]]; then
  open "https://github.com/settings/copilot"
  exit 0
fi

# ── ensure Python venv with Pillow exists ─────────────────────────────────────
VENV_DIR="$WIDGET_DIR/.venv"
VENV_PYTHON="$VENV_DIR/bin/python3"
if [[ ! -x "$VENV_PYTHON" ]]; then
  python3 -m venv "$VENV_DIR" --system-site-packages
fi
if ! "$VENV_PYTHON" -c "from PIL import Image" &>/dev/null; then
  "$VENV_PYTHON" -m pip install --quiet pillow --disable-pip-version-check
fi
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
"$VENV_PYTHON" - <<PYEOF
import json, os, datetime, base64, io
from PIL import Image, ImageDraw

quota_file  = os.path.expanduser("$QUOTA_FILE")

with open(quota_file) as f:
    q = json.load(f)

entitlement   = q.get("entitlement", 0)
used          = q.get("used", 0)
overage       = q.get("overage_count", 0)
unlimited     = q.get("unlimited", False)
pct_used      = q.get("percent_used", 0.0)
reset_date_s  = q.get("quota_reset_date", "")
fetched_at    = q.get("fetched_at", "")

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
    # ── PNG progress bar ──────────────────────────────────────────────────────
    W, H, R = 240, 14, 7
    OVERAGE_MAX_PX = int(W * 0.20)

    quota_fill_px   = int(min(pct_used, 100) / 100 * W)
    overage_pct     = (overage / entitlement * 100) if entitlement > 0 else 0
    overage_fill_px = min(int(overage_pct / 100 * W), OVERAGE_MAX_PX)
    total_w         = W + overage_fill_px

    GREEN  = (48, 209, 88)
    YELLOW = (255, 214, 10)
    RED    = (255, 69, 58)
    TRACK  = (60, 60, 65)
    WHITE  = (255, 255, 255)
    quota_color = GREEN if pct_used < 75 else YELLOW if pct_used < 100 else RED

    img = Image.new("RGBA", (total_w, H), (0, 0, 0, 0))
    d   = ImageDraw.Draw(img)

    # track (quota region only)
    d.rounded_rectangle([0, 0, W - 1, H - 1], radius=R, fill=TRACK)
    # quota fill
    if quota_fill_px > 0:
        d.rounded_rectangle([0, 0, quota_fill_px - 1, H - 1], radius=R, fill=quota_color)
    # overage extension
    if overage_fill_px > 0:
        d.rectangle([W, 0, W + overage_fill_px - 1, H - 1], fill=RED)
        d.rounded_rectangle([W + overage_fill_px - R * 2, 0,
                              W + overage_fill_px - 1,     H - 1], radius=R, fill=RED)
        # white boundary divider
        d.rectangle([W - 2, 0, W + 1, H - 1], fill=WHITE)

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    b64 = base64.b64encode(buf.getvalue()).decode()

    print(f"| image={b64} trim=false")
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
PYEOF
