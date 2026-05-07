#!/usr/bin/env bash
# PostToolUse — runs after sf scanner run; converts SARIF → HTML findings report
set -euo pipefail

PAYLOAD=$(cat)
COMMAND=$(printf '%s' "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

if ! echo "$COMMAND" | grep -q "sf scanner run"; then
  exit 0
fi

REPORTS_DIR="reports"
mkdir -p "$REPORTS_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUT="$REPORTS_DIR/pmd-findings-${TIMESTAMP}.html"
DATE_HUMAN=$(date '+%B %d, %Y %H:%M UTC')

SARIF_FILE=$(echo "$COMMAND" | grep -oE '\-\-outfile [^ ]+' | awk '{print $2}' || echo "")
[[ -z "$SARIF_FILE" ]] && SARIF_FILE=$(ls reports/*.sarif 2>/dev/null | tail -1 || echo "")

FINDINGS_HTML=""
TOTAL=0; CRITICAL=0; HIGH=0; MEDIUM=0; LOW=0

# Write SARIF parser to a temp file — avoids heredoc-inside-$() bash parse error
_PY=$(mktemp /tmp/pmd-sarif-XXXXXX.py)
cat > "$_PY" << 'PY'
import sys, json, html as h

try:
    with open(sys.argv[1]) as f:
        sarif = json.load(f)

    rows = []
    counts = {"critical": 0, "high": 0, "medium": 0, "low": 0, "total": 0}

    for run in sarif.get("runs", []):
        rules = {r["id"]: r for r in run.get("tool", {}).get("driver", {}).get("rules", [])}
        for result in run.get("results", []):
            rule_id  = result.get("ruleId", "unknown")
            message  = h.escape(result.get("message", {}).get("text", "")[:180])
            severity = result.get("properties", {}).get("severity", "").lower()
            if not severity:
                lvl = result.get("level", "warning")
                severity = {"error": "critical", "warning": "high", "note": "medium"}.get(lvl, "low")

            locs = result.get("locations", [])
            if locs:
                uri  = locs[0].get("physicalLocation", {}).get("artifactLocation", {}).get("uri", "?")
                line = locs[0].get("physicalLocation", {}).get("region", {}).get("startLine", "?")
            else:
                uri = "?"; line = "?"

            file_short = uri.split("/")[-1] if "/" in uri else uri
            counts["total"] += 1
            counts[severity] = counts.get(severity, 0) + 1

            COLOR = {"critical": "#dc2626", "high": "#d97706", "medium": "#2563eb", "low": "#64748b"}.get(severity, "#64748b")
            BG    = {"critical": "#fef2f2", "high": "#fffbeb", "medium": "#eff6ff", "low": "#f8fafc"}.get(severity, "#f8fafc")
            LABEL = severity.upper()

            rows.append(
                '<tr style="background:' + BG + '">'
                '<td><span style="background:' + COLOR + ';color:#fff;padding:2px 8px;border-radius:4px;'
                'font-size:.72rem;font-weight:700">' + LABEL + '</span></td>'
                '<td style="font-family:monospace;font-size:.8rem">' + h.escape(rule_id) + '</td>'
                '<td style="font-size:.82rem">' + h.escape(file_short) + '</td>'
                '<td style="text-align:center">' + str(line) + '</td>'
                '<td style="font-size:.8rem">' + message + '</td>'
                '</tr>'
            )

    summary = (str(counts["total"]) + '|' + str(counts.get("critical", 0)) + '|' +
               str(counts.get("high", 0)) + '|' + str(counts.get("medium", 0)) + '|' +
               str(counts.get("low", 0)))
    print(summary)
    print('\n'.join(rows))

except Exception as e:
    print('0|0|0|0|0')
    print('<tr><td colspan="5" style="text-align:center;padding:24px;color:#94a3b8">Could not parse SARIF: ' + h.escape(str(e)) + '</td></tr>')
PY

if [[ -n "$SARIF_FILE" && -f "$SARIF_FILE" ]]; then
  PARSED=$(python3 "$_PY" "$SARIF_FILE" 2>/dev/null || echo "0|0|0|0|0")
  SUMMARY_LINE=$(echo "$PARSED" | head -1)
  FINDINGS_HTML=$(echo "$PARSED" | tail -n +2)
  IFS='|' read -r TOTAL CRITICAL HIGH MEDIUM LOW <<< "$SUMMARY_LINE"
fi

rm -f "$_PY"

if   [[ "$CRITICAL" -gt 0 ]]; then BADGE_COLOR="#dc2626"; BADGE_TEXT="CRITICAL FINDINGS"
elif [[ "$HIGH"     -gt 0 ]]; then BADGE_COLOR="#d97706"; BADGE_TEXT="HIGH FINDINGS"
elif [[ "$TOTAL"    -gt 0 ]]; then BADGE_COLOR="#2563eb"; BADGE_TEXT="FINDINGS PRESENT"
else                                BADGE_COLOR="#16a34a"; BADGE_TEXT="CLEAN"
fi

cat > "$OUT" << HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>PMD Findings — ${DATE_HUMAN}</title>
<style>
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#f8fafc;color:#1e293b}
  header{background:#1e293b;color:#fff;padding:24px 32px;display:flex;align-items:center;gap:16px}
  header h1{font-size:1.4rem;font-weight:700;flex:1}
  header .meta{font-size:.8rem;opacity:.7;line-height:1.6}
  .badge{padding:6px 16px;border-radius:20px;font-weight:700;font-size:.9rem;
         color:${BADGE_COLOR};background:#fff;border:2px solid ${BADGE_COLOR}}
  .cards{display:flex;gap:16px;padding:24px 32px;flex-wrap:wrap}
  .card{flex:1;min-width:120px;background:#fff;border-radius:8px;padding:18px;
        border:1px solid #e2e8f0;text-align:center}
  .card .num{font-size:2rem;font-weight:800;line-height:1}
  .card .label{font-size:.72rem;text-transform:uppercase;letter-spacing:.05em;margin-top:5px;opacity:.6}
  section{margin:0 32px 28px;background:#fff;border-radius:8px;border:1px solid #e2e8f0;overflow:hidden}
  section h2{padding:14px 20px;font-size:.9rem;text-transform:uppercase;letter-spacing:.05em;
             background:#f1f5f9;border-bottom:1px solid #e2e8f0;color:#475569}
  table{width:100%;border-collapse:collapse}
  th{padding:10px 14px;background:#f8fafc;font-size:.78rem;text-transform:uppercase;
     letter-spacing:.04em;color:#64748b;border-bottom:2px solid #e2e8f0}
  td{padding:8px 14px;border-bottom:1px solid #f1f5f9;vertical-align:top}
  footer{text-align:center;padding:20px;font-size:.75rem;color:#94a3b8}
</style>
</head>
<body>
<header>
  <div style="flex:1">
    <h1>🔬 PMD / Code Analyzer Findings</h1>
    <div class="meta">Source: <strong>${SARIF_FILE:-reports/*.sarif}</strong> &nbsp;|&nbsp; ${DATE_HUMAN}</div>
  </div>
  <div class="badge">${BADGE_TEXT}</div>
</header>
<div class="cards">
  <div class="card" style="border-top:4px solid #64748b">
    <div class="num">${TOTAL}</div><div class="label">Total</div>
  </div>
  <div class="card" style="border-top:4px solid #dc2626">
    <div class="num" style="color:#dc2626">${CRITICAL}</div><div class="label">Critical</div>
  </div>
  <div class="card" style="border-top:4px solid #d97706">
    <div class="num" style="color:#d97706">${HIGH}</div><div class="label">High</div>
  </div>
  <div class="card" style="border-top:4px solid #2563eb">
    <div class="num" style="color:#2563eb">${MEDIUM}</div><div class="label">Medium</div>
  </div>
  <div class="card" style="border-top:4px solid #64748b">
    <div class="num" style="color:#64748b">${LOW}</div><div class="label">Low</div>
  </div>
</div>
<section>
  <h2>Findings (sorted by severity)</h2>
  <table>
    <tr>
      <th style="width:90px">Severity</th>
      <th style="width:200px">Rule</th>
      <th>File</th>
      <th style="width:60px;text-align:center">Line</th>
      <th>Message</th>
    </tr>
    ${FINDINGS_HTML:-<tr><td colspan="5" style="text-align:center;padding:24px;color:#94a3b8">No SARIF file found — run /pmd-scan first</td></tr>}
  </table>
</section>
<footer>Generated by Claude Code salesforce-audit plugin &nbsp;|&nbsp; ${DATE_HUMAN}</footer>
</body>
</html>
HTML

echo ""
echo "🔬 PMD findings report saved → ${OUT}"
echo "   Open in browser: open ${OUT}"
