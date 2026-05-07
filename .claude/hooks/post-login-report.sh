#!/usr/bin/env bash
# PostToolUse — runs after login-history-report.sh; generates HTML anomaly report
set -euo pipefail

PAYLOAD=$(cat)
COMMAND=$(printf '%s' "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Trigger on login-history script or LoginHistory SOQL queries
if ! echo "$COMMAND" | grep -qiE "login-history-report\.sh|LoginHistory|VerificationHistory"; then
  exit 0
fi

REPORTS_DIR="reports"
mkdir -p "$REPORTS_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUT="$REPORTS_DIR/login-anomaly-${TIMESTAMP}.html"
DATE_HUMAN=$(date '+%B %d, %Y %H:%M UTC')
ORG=$(echo "$COMMAND" | grep -oE '\-\-target-org [^ ]+' | awk '{print $2}' || echo "unknown")

# Parse tool output (JSON) for login records
TOOL_OUTPUT=$(printf '%s' "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); r=d.get('tool_response',{}); print(r.get('output','') or r.get('content',''))" \
  2>/dev/null || echo "")

# Parse the JSON output from sf data query
STATS=$(echo "$TOOL_OUTPUT" | python3 - <<'PY' 2>/dev/null || echo "0|0|0|0|0")
import sys, json, re, html

raw = sys.stdin.read()

# Try to extract JSON from the sf CLI output
try:
    # sf --json output is wrapped in {"status":0,"result":{"records":[...]}}
    m = re.search(r'\{.*\}', raw, re.DOTALL)
    data = json.loads(m.group()) if m else {}
    records = data.get('result', {}).get('records', [])
except:
    records = []

total   = len(records)
failed  = sum(1 for r in records if r.get('Status','').lower() not in ('success',''))
new_countries = set()
high_volume = {}  # user -> count

rows_crit = []; rows_warn = []; rows_ok = []

for r in records:
    status  = r.get('Status', '')
    user    = r.get('Username', r.get('UserId', '?'))
    ip      = r.get('SourceIp', '?')
    country = r.get('CountryIso', '')
    ltype   = r.get('LoginType', '')
    ltime   = r.get('LoginTime', '')[:16] if r.get('LoginTime') else '?'
    browser = r.get('Browser', r.get('Platform', ''))

    esc_user = html.escape(str(user))
    esc_ip   = html.escape(str(ip))
    esc_st   = html.escape(str(status))
    esc_lt   = html.escape(str(ltype))

    high_volume[user] = high_volume.get(user, 0) + 1

    if status.lower() not in ('success', ''):
        rows_crit.append(
            f'<tr style="background:#fef2f2"><td>{esc_user}</td><td>{esc_ip}</td>'
            f'<td style="color:#dc2626;font-weight:700">{esc_st}</td>'
            f'<td>{esc_lt}</td><td>{html.escape(str(country))}</td></tr>'
        )

success = total - failed
# High-volume users (>5 logins today)
hv_rows = []
for u, cnt in sorted(high_volume.items(), key=lambda x: -x[1]):
    if cnt > 5:
        hv_rows.append(f'<tr style="background:#fffbeb"><td>{html.escape(str(u))}</td>'
                       f'<td style="font-weight:700;color:#d97706">{cnt}</td></tr>')

summary_line = f'{total}|{success}|{failed}|{len(rows_crit)}|{len(hv_rows)}'
crit_html  = '\n'.join(rows_crit)  or '<tr><td colspan="5" style="text-align:center;color:#16a34a;padding:12px">No failed logins found</td></tr>'
hv_html    = '\n'.join(hv_rows)    or '<tr><td colspan="2" style="text-align:center;color:#16a34a;padding:12px">No high-volume users</td></tr>'

print(summary_line)
print('---CRIT---')
print(crit_html)
print('---HV---')
print(hv_html)
PY
)

# Split output sections
SUMMARY_LINE=$(echo "$STATS" | head -1)
CRIT_ROWS=$(echo "$STATS"   | awk '/---CRIT---/{f=1;next} /---HV---/{f=0} f{print}')
HV_ROWS=$(echo "$STATS"     | awk '/---HV---/{f=1;next} f{print}')

IFS='|' read -r TOTAL SUCCESS FAILED ANOMALIES HV_COUNT <<< "$SUMMARY_LINE"
TOTAL="${TOTAL:-0}"; SUCCESS="${SUCCESS:-0}"; FAILED="${FAILED:-0}"

if   [[ "${FAILED:-0}" -gt 0 ]]; then BADGE_COLOR="#dc2626"; BADGE_TEXT="ANOMALIES DETECTED"
elif [[ "${HV_COUNT:-0}" -gt 0 ]]; then BADGE_COLOR="#d97706"; BADGE_TEXT="WARNINGS"
else                                    BADGE_COLOR="#16a34a"; BADGE_TEXT="CLEAN"
fi

cat > "$OUT" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Login Anomaly Report — ${ORG} — ${DATE_HUMAN}</title>
<style>
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#f8fafc;color:#1e293b}
  header{background:#1e293b;color:#fff;padding:24px 32px;display:flex;align-items:center;gap:16px}
  header h1{font-size:1.4rem;font-weight:700;flex:1}
  header .meta{font-size:.8rem;opacity:.7;line-height:1.6}
  .badge{padding:6px 16px;border-radius:20px;font-weight:700;font-size:.9rem;
         color:${BADGE_COLOR};background:#fff;border:2px solid ${BADGE_COLOR}}
  .cards{display:flex;gap:16px;padding:24px 32px;flex-wrap:wrap}
  .card{flex:1;min-width:130px;background:#fff;border-radius:8px;padding:18px;
        border:1px solid #e2e8f0;text-align:center}
  .card .num{font-size:2rem;font-weight:800;line-height:1}
  .card .label{font-size:.72rem;text-transform:uppercase;letter-spacing:.05em;margin-top:5px;opacity:.6}
  section{margin:0 32px 28px;background:#fff;border-radius:8px;border:1px solid #e2e8f0;overflow:hidden}
  section h2{padding:14px 20px;font-size:.9rem;text-transform:uppercase;letter-spacing:.05em;
             background:#f1f5f9;border-bottom:1px solid #e2e8f0;color:#475569}
  table{width:100%;border-collapse:collapse}
  th{padding:10px 14px;background:#f8fafc;font-size:.78rem;text-transform:uppercase;
     letter-spacing:.04em;color:#64748b;border-bottom:2px solid #e2e8f0}
  td{padding:8px 14px;border-bottom:1px solid #f1f5f9;font-size:.83rem}
  footer{text-align:center;padding:20px;font-size:.75rem;color:#94a3b8}
</style>
</head>
<body>
<header>
  <div style="flex:1">
    <h1>🔐 Login Anomaly Report</h1>
    <div class="meta">Org: <strong>${ORG}</strong> &nbsp;|&nbsp; ${DATE_HUMAN}</div>
  </div>
  <div class="badge">${BADGE_TEXT}</div>
</header>

<div class="cards">
  <div class="card" style="border-top:4px solid #2563eb">
    <div class="num">${TOTAL}</div><div class="label">Total Logins</div>
  </div>
  <div class="card" style="border-top:4px solid #16a34a">
    <div class="num" style="color:#16a34a">${SUCCESS}</div><div class="label">Successful</div>
  </div>
  <div class="card" style="border-top:4px solid #dc2626">
    <div class="num" style="color:#dc2626">${FAILED}</div><div class="label">Failed</div>
  </div>
  <div class="card" style="border-top:4px solid #d97706">
    <div class="num" style="color:#d97706">${HV_COUNT:-0}</div><div class="label">High-Volume Users</div>
  </div>
</div>

<section>
  <h2>🔴 Failed Logins</h2>
  <table>
    <tr><th>User</th><th>Source IP</th><th>Status</th><th>Login Time</th><th>Country</th></tr>
    ${CRIT_ROWS}
  </table>
</section>

<section>
  <h2>🟡 High-Volume Users (&gt;5 logins in window)</h2>
  <table>
    <tr><th>User</th><th>Login Count</th></tr>
    ${HV_ROWS}
  </table>
</section>

<footer>Generated by Claude Code salesforce-audit plugin &nbsp;|&nbsp; ${DATE_HUMAN}</footer>
</body>
</html>
HTML

echo ""
echo "🔐 Login anomaly report saved → ${OUT}"
echo "   Open in browser: open ${OUT}"
