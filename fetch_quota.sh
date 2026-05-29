#!/usr/bin/env bash
# Fetches GitHub Copilot premium request quota and writes quota.json cache.
# Called by the SwiftBar plugin on each refresh cycle.
# Requires: gh CLI (authenticated), python3, curl

set -euo pipefail

WIDGET_DIR="$HOME/.config/copilot-quota-widget"
QUOTA_FILE="$WIDGET_DIR/quota.json"
ERROR_FILE="$WIDGET_DIR/quota_error.txt"

GH_BIN="$(command -v gh 2>/dev/null || echo '/opt/homebrew/bin/gh')"

if [[ ! -x "$GH_BIN" ]]; then
  echo "gh CLI not found — install with: brew install gh" >"$ERROR_FILE"
  exit 1
fi

TOKEN="$("$GH_BIN" auth token 2>/dev/null || true)"
if [[ -z "$TOKEN" ]]; then
  echo "Not authenticated — run: gh auth login" >"$ERROR_FILE"
  exit 1
fi

RESPONSE=$(curl -sf \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/json" \
  -H "Editor-Version: vscode/1.99.0" \
  "https://api.github.com/copilot_internal/user" 2>&1) || {
  echo "API request failed. Check network or token scopes." >"$ERROR_FILE"
  exit 1
}

python3 - <<PYEOF
import sys, json, datetime

try:
    data = json.loads("""$RESPONSE""")
except json.JSONDecodeError as e:
    with open("$ERROR_FILE", "w") as f:
        f.write(f"JSON parse error: {e}")
    sys.exit(1)

snap        = data.get("quota_snapshots", {}).get("premium_interactions", {})
entitlement = int(snap.get("entitlement", 0))
remaining   = int(snap.get("remaining", 0))
overage     = int(snap.get("overage_count", 0))
unlimited   = bool(snap.get("unlimited", False))
reset_date  = data.get("quota_reset_date_utc", data.get("quota_reset_date", ""))
plan        = data.get("copilot_plan", "unknown")

# used = everything consumed including overage
used = (entitlement + overage) if remaining <= 0 else (entitlement - remaining)
used = max(0, used)

pct_used = round(used / entitlement * 100, 1) if entitlement > 0 else 0.0

output = {
    "fetched_at":      datetime.datetime.utcnow().isoformat() + "Z",
    "plan":            plan,
    "entitlement":     entitlement,
    "used":            used,
    "remaining":       remaining,
    "overage_count":   overage,
    "unlimited":       unlimited,
    "quota_reset_date": reset_date,
    "percent_used":    pct_used,
}

import os
os.makedirs("$WIDGET_DIR", exist_ok=True)
with open("$QUOTA_FILE", "w") as f:
    json.dump(output, f, indent=2)

print("OK")
PYEOF

rm -f "$ERROR_FILE"
