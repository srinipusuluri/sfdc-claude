#!/usr/bin/env bash
# PostToolUse — runs after org-scan.sh; generates HTML audit report in reports/
set -euo pipefail

PAYLOAD=$(cat)
COMMAND=$(printf '%s' "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Only act on org-scan.sh invocations
if ! echo "$COMMAND" | grep -q "org-scan.sh"; then
  exit 0
fi

REPORTS_DIR="reports"
mkdir -p "$REPORTS_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUT="$REPORTS_DIR/org-scan-${TIMESTAMP}.html"

# Find most recent org-scan report directory
REPORT_DIR=$(ls -td /tmp/org-scan-* 2>/dev/null | head -1 || echo "")

# Extract org alias from command
ORG=$(echo "$COMMAND" | grep -oE '\-\-target-org [^ ]+' | awk '{print $2}' || echo "unknown")
DATE_HUMAN=$(date '+%B %d, %Y %H:%M UTC')

# Collect summary counts from JSON files if report dir exists
CRITICAL=0; WARN=0; CLEAN=0; DOMAINS=0
if [[ -n "$REPORT_DIR" && -d "$REPORT_DIR" ]]; then
  DOMAINS=$(ls "$REPORT_DIR"/*.json 2>/dev/null | wc -l | tr -d ' ')
fi

# Pull tool output for inline display
TOOL_OUTPUT=$(printf '%s' "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); r=d.get('tool_response',{}); print(r.get('output','') or r.get('content',''))" \
  2>/dev/null || echo "")

# Count severity lines from tool output
CRITICAL=$(echo "$TOOL_OUTPUT" | grep -c "🔴\|CRITICAL\|\[CRIT\]" 2>/dev/null || echo 0)
WARN=$(echo "$TOOL_OUTPUT"    | grep -c "🟡\|WARNING\|\[WARN\]"   2>/dev/null || echo 0)
CLEAN=$(echo "$TOOL_OUTPUT"   | grep -c "🟢\|CLEAN\|\[OK\]"       2>/dev/null || echo 0)

# Determine overall status colour
if   [[ "$CRITICAL" -gt 0 ]]; then BADGE_COLOR="#dc2626"; BADGE_TEXT="CRITICAL"; BADGE_BG="#fef2f2"
elif [[ "$WARN"     -gt 0 ]]; then BADGE_COLOR="#d97706"; BADGE_TEXT="WARNING";  BADGE_BG="#fffbeb"
else                                BADGE_COLOR="#16a34a"; BADGE_TEXT="HEALTHY";  BADGE_BG="#f0fdf4"
fi

# Convert plain-text output to HTML rows (colour-code by prefix)
HTML_ROWS=""
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  esc=$(printf '%s' "$line" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
  if   echo "$line" | grep -qE "🔴|CRITICAL|\[CRIT\]"; then ROW_CLASS="crit"
  elif echo "$line" | grep -qE "🟡|WARNING|\[WARN\]";  then ROW_CLASS="warn"
  elif echo "$line" | grep -qE "🟢|CLEAN|\[OK\]";      then ROW_CLASS="ok"
  else ROW_CLASS="plain"
  fi
  HTML_ROWS="${HTML_ROWS}<tr class=\"${ROW_CLASS}\"><td><pre>${esc}</pre></td></tr>"
done <<< "$TOOL_OUTPUT"

cat > "$OUT" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Org Scan Report — ${ORG} — ${DATE_HUMAN}</title>
<style>
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#f8fafc;color:#1e293b}
  header{background:#1e293b;color:#fff;padding:24px 32px;display:flex;align-items:center;gap:16px}
  header h1{font-size:1.4rem;font-weight:700;flex:1}
  header .meta{font-size:.8rem;opacity:.7;line-height:1.6}
  .badge{padding:6px 16px;border-radius:20px;font-weight:700;font-size:.9rem;
         color:${BADGE_COLOR};background:${BADGE_BG};border:2px solid ${BADGE_COLOR}}
  .cards{display:flex;gap:16px;padding:24px 32px;flex-wrap:wrap}
  .card{flex:1;min-width:140px;background:#fff;border-radius:8px;padding:20px;
        border:1px solid #e2e8f0;text-align:center}
  .card .num{font-size:2.2rem;font-weight:800;line-height:1}
  .card .label{font-size:.75rem;text-transform:uppercase;letter-spacing:.05em;margin-top:6px;opacity:.6}
  .card.crit .num{color:#dc2626} .card.warn .num{color:#d97706} .card.ok .num{color:#16a34a}
  .card.info .num{color:#2563eb}
  section{margin:0 32px 32px;background:#fff;border-radius:8px;border:1px solid #e2e8f0;overflow:hidden}
  section h2{padding:14px 20px;font-size:.9rem;text-transform:uppercase;letter-spacing:.05em;
             background:#f1f5f9;border-bottom:1px solid #e2e8f0;color:#475569}
  table{width:100%;border-collapse:collapse}
  tr.crit td{background:#fef2f2;border-left:4px solid #dc2626}
  tr.warn td{background:#fffbeb;border-left:4px solid #d97706}
  tr.ok  td{background:#f0fdf4;border-left:4px solid #16a34a}
  tr.plain td{background:#fff;border-left:4px solid transparent}
  td{padding:6px 14px;vertical-align:top;border-bottom:1px solid #f1f5f9}
  pre{font-family:'SF Mono','Fira Code',monospace;font-size:.78rem;white-space:pre-wrap;word-break:break-word}
  footer{text-align:center;padding:20px;font-size:.75rem;color:#94a3b8}
  @media print{header{-webkit-print-color-adjust:exact;print-color-adjust:exact}}
</style>
</head>
<body>
<header>
  <div style="flex:1">
    <h1>🔍 Org Scan Report</h1>
    <div class="meta">Org: <strong>${ORG}</strong> &nbsp;|&nbsp; ${DATE_HUMAN} &nbsp;|&nbsp; ${DOMAINS} domains checked</div>
  </div>
  <div class="badge">${BADGE_TEXT}</div>
</header>

<div class="cards">
  <div class="card crit"><div class="num">${CRITICAL}</div><div class="label">🔴 Critical</div></div>
  <div class="card warn"><div class="num">${WARN}</div><div class="label">🟡 Warnings</div></div>
  <div class="card ok"><div class="num">${CLEAN}</div><div class="label">🟢 Clean</div></div>
  <div class="card info"><div class="num">${DOMAINS}</div><div class="label">Domains</div></div>
</div>

<section>
  <h2>Scan Output</h2>
  <table>${HTML_ROWS}</table>
</section>

<footer>Generated by Claude Code salesforce-audit plugin &nbsp;|&nbsp; ${DATE_HUMAN}</footer>
</body>
</html>
HTML

echo ""
echo "📊 Audit report saved → ${OUT}"
echo "   Open in browser: open ${OUT}"
HTML
