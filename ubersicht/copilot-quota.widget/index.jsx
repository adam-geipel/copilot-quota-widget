// GitHub Copilot Quota — Übersicht desktop overlay widget
// Reads ~/.config/copilot-quota-widget/quota.json (written by fetch_quota.sh)
// Toggled on/off from the SwiftBar plugin dropdown menu

export const command = `
  CONFIG="$HOME/.config/copilot-quota-widget/config.json"
  QUOTA="$HOME/.config/copilot-quota-widget/quota.json"

  # If overlay disabled in config, output sentinel and exit
  ENABLED=$(python3 -c "
import json, os
try:
    c = json.load(open(os.path.expanduser('$CONFIG')))
    print('true' if c.get('overlay_enabled', False) else 'false')
except:
    print('false')
" 2>/dev/null)

  if [ "$ENABLED" = "false" ]; then
    echo "__HIDDEN__"
    exit 0
  fi

  [ -f "$QUOTA" ] && cat "$QUOTA" || echo '{"error":"No data"}'
`

export const refreshFrequency = 30000  // 30 seconds

export const className = `
  bottom: 20px;
  right: 20px;
  font-family: -apple-system, "SF Pro Display", "Helvetica Neue", sans-serif;
  font-size: 13px;
  color: #ffffff;
  z-index: 1000;
`

export const render = ({ output }) => {
  if (!output || output.trim() === "__HIDDEN__") return <div />

  let data
  try {
    data = JSON.parse(output)
  } catch (e) {
    return (
      <div style={styles.card}>
        <div style={styles.title}>🤖 Copilot Quota</div>
        <div style={{ color: "#ff453a", fontSize: "11px" }}>Parse error</div>
      </div>
    )
  }

  if (data.error) {
    return (
      <div style={styles.card}>
        <div style={styles.title}>🤖 Copilot Quota</div>
        <div style={{ color: "#ff453a", fontSize: "11px" }}>{data.error}</div>
      </div>
    )
  }

  const {
    entitlement = 0,
    used = 0,
    overage_count: overage = 0,
    unlimited = false,
    percent_used: pctUsed = 0,
    quota_reset_date: resetDate = "",
    fetched_at: fetchedAt = "",
  } = data

  // ── colors ────────────────────────────────────────────────────────────────
  const GREEN  = "#30d158"
  const YELLOW = "#ffd60a"
  const RED    = "#ff453a"
  const DIM    = "rgba(255,255,255,0.25)"

  const quotaColor = pctUsed < 75 ? GREEN : pctUsed < 100 ? YELLOW : RED

  // ── bar geometry ──────────────────────────────────────────────────────────
  // Total bar = 240px wide.
  // Green portion = min(pctUsed, 100)% of 240px.
  // Red portion appended: (overage / entitlement * 100)% of 240px, capped at 60px.
  const BAR_WIDTH     = 240
  const OVERAGE_CAP   = 60
  const quotaFillPx   = Math.min((Math.min(pctUsed, 100) / 100) * BAR_WIDTH, BAR_WIDTH)
  const overagePct    = entitlement > 0 ? (overage / entitlement) * 100 : 0
  const overageFillPx = Math.min((overagePct / 100) * BAR_WIDTH, OVERAGE_CAP)

  // ── reset date label ──────────────────────────────────────────────────────
  let resetLabel = "—"
  let daysLeft   = "?"
  try {
    const resetDt  = new Date(resetDate)
    const now      = new Date()
    const diffMs   = resetDt - now
    daysLeft       = Math.max(0, Math.ceil(diffMs / 86400000))
    resetLabel     = resetDt.toLocaleDateString("en-US", { month: "short", day: "numeric" })
  } catch (_) {}

  // ── fetch time ────────────────────────────────────────────────────────────
  let timeLabel = ""
  try {
    const ft = new Date(fetchedAt)
    timeLabel = ft.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" })
  } catch (_) {}

  return (
    <div style={styles.card}>
      {/* Header */}
      <div style={styles.header}>
        <span style={styles.title}>🤖 Copilot Quota</span>
        {timeLabel && (
          <span style={styles.subtitle}>{timeLabel}</span>
        )}
      </div>

      {unlimited ? (
        <div style={{ color: GREEN, fontSize: "12px", marginTop: "6px" }}>
          Unlimited (enterprise)
        </div>
      ) : (
        <>
          {/* Stats row */}
          <div style={styles.statsRow}>
            <span style={{ color: overage > 0 ? RED : quotaColor, fontVariantNumeric: "tabular-nums" }}>
              {used.toLocaleString()}
            </span>
            <span style={{ color: "rgba(255,255,255,0.45)" }}>
              {" / "}{entitlement.toLocaleString()}
            </span>
            {overage > 0 && (
              <span style={{ color: RED, marginLeft: "6px" }}>
                +{overage.toLocaleString()} over
              </span>
            )}
          </div>

          {/* Progress bar */}
          <div style={{ ...styles.barTrack, width: BAR_WIDTH }}>
            {/* Quota fill */}
            {quotaFillPx > 0 && (
              <div style={{
                ...styles.barSegment,
                width: quotaFillPx,
                background: quotaColor,
              }} />
            )}
            {/* Empty track (within quota) */}
            {quotaFillPx < BAR_WIDTH && overage === 0 && (
              <div style={{
                ...styles.barSegment,
                width: BAR_WIDTH - quotaFillPx,
                background: DIM,
              }} />
            )}
            {/* Boundary marker when at 100%+ */}
            {overage > 0 && (
              <div style={styles.boundaryMarker} />
            )}
            {/* Overage fill */}
            {overageFillPx > 0 && (
              <div style={{
                ...styles.barSegment,
                width: overageFillPx,
                background: RED,
                borderRadius: "0 3px 3px 0",
              }} />
            )}
          </div>

          {/* Percent + reset */}
          <div style={styles.footer}>
            <span style={{ color: quotaColor }}>{pctUsed.toFixed(0)}%</span>
            <span style={styles.subtitle}>
              Resets {resetLabel} ({daysLeft}d)
            </span>
          </div>
        </>
      )}
    </div>
  )
}

// ── styles ────────────────────────────────────────────────────────────────────
const styles = {
  card: {
    background:   "rgba(28, 28, 30, 0.88)",
    backdropFilter: "blur(20px)",
    WebkitBackdropFilter: "blur(20px)",
    border:       "1px solid rgba(255,255,255,0.10)",
    borderRadius: "14px",
    padding:      "14px 16px",
    minWidth:     "270px",
    boxShadow:    "0 4px 24px rgba(0,0,0,0.55)",
  },
  header: {
    display:        "flex",
    justifyContent: "space-between",
    alignItems:     "center",
    marginBottom:   "8px",
  },
  title: {
    fontWeight: "600",
    fontSize:   "13px",
    color:      "#ffffff",
  },
  subtitle: {
    fontSize: "11px",
    color:    "rgba(255,255,255,0.40)",
  },
  statsRow: {
    fontSize:     "13px",
    fontVariantNumeric: "tabular-nums",
    marginBottom: "8px",
    fontWeight:   "500",
  },
  barTrack: {
    height:        "6px",
    borderRadius:  "3px",
    background:    "rgba(255,255,255,0.12)",
    display:       "flex",
    flexDirection: "row",
    overflow:      "visible",
    position:      "relative",
    marginBottom:  "8px",
  },
  barSegment: {
    height:       "6px",
    borderRadius: "3px",
    flexShrink:   0,
  },
  boundaryMarker: {
    width:        "2px",
    height:       "10px",
    marginTop:    "-2px",
    background:   "rgba(255,255,255,0.60)",
    borderRadius: "1px",
    flexShrink:   0,
  },
  footer: {
    display:        "flex",
    justifyContent: "space-between",
    alignItems:     "center",
    fontSize:       "12px",
    fontWeight:     "500",
  },
}
