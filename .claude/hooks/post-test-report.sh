#!/usr/bin/env bash
# PostToolUse — runs after sf apex run test; generates HTML coverage report
set -euo pipefail

PAYLOAD=$(cat)
COMMAND=$(printf '%s' "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

if ! echo "$COMMAND" | grep -q "sf apex run test"; then
  exit 0
fi

REPORTS_DIR="reports"
mkdir -p "$REPORTS_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUT="$REPORTS_DIR/test-coverage-${TIMESTAMP}.html"
DATE_HUMAN=$(date '+%B %d, %Y %H:%M UTC')
ORG=$(echo "$COMMAND" | grep -oE '\-\-target-org [^ ]+' | awk '{print $2}' || echo "unknown")
RESULTS_DIR="/tmp/apex-test-results"

# Parse coverage data from JSON results if available
COVERAGE_ROWS=""
FAILED_ROWS=""
TOTAL=0; PASSED=0; FAILED=0; ORG_COVERAGE="N/A"

if [[ -d "$RESULTS_DIR" ]]; then
  # Org-wide coverage
  COV_FILE=$(ls "$RESULTS_DIR"/*codecoverage*.json 2>/dev/null | head -1 || echo "")
  if [[ -n "$COV_FILE" ]]; then
    python3 - "$COV_FILE" <<'PY'
import sys, json
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    # Handle both array and dict result formats
    classes = data if isinstance(data, list) else data.get('coverage', {}).get('coverage', [])
    rows = []
    for c in sorted(classes, key=lambda x: x.get('coveragePercent', 0) if isinstance(x, dict) else 0):
        if not isinstance(c, dict): continue
        name = c.get('name', c.get('apexClassOrTriggerName', '?'))
        pct  = c.get('coveragePercent', 0)
        covered   = c.get('coveredLines', 0)
        uncovered = c.get('uncoveredLines', 0)
        total_lines = covered + uncovered
        bar_w = int(pct)
        if pct < 75:   cls = '#dc2626'; bg = '#fef2f2'
        elif pct < 90: cls = '#d97706'; bg = '#fffbeb'
        else:          cls = '#16a34a'; bg = '#f0fdf4'
        bar = (f'<div style="background:#e2e8f0;border-radius:4px;height:10px;width:120px">'
               f'<div style="background:{cls};width:{bar_w}%;height:10px;border-radius:4px"></div></div>')
        rows.append(
            f'<tr style="background:{bg}">'
            f'<td>{name}</td><td style="text-align:right;font-weight:700;color:{cls}">{pct:.1f}%</td>'
            f'<td>{bar}</td><td style="text-align:right">{covered}</td>'
            f'<td style="text-align:right">{uncovered}</td><td style="text-align:right">{total_lines}</td></tr>'
        )
    print('\n'.join(rows))
PY
  fi

  # Test results summary
  RES_FILE=$(ls "$RESULTS_DIR"/*test-result*.json 2>/dev/null | head -1 || echo "")
  if [[ -n "$RES_FILE" ]]; then
    SUMMARY=$(python3 - "$RES_FILE" <<'PY'
import sys, json
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    summary = data.get('summary', {})
    total   = summary.get('testsRan', 0)
    passing = summary.get('passing', 0)
    failing = summary.get('failing', 0)
    cov     = summary.get('orgWideCoverage', 'N/A')
    print(f"{total}|{passing}|{failing}|{cov}")
    # Print failed tests
    tests = data.get('tests', [])
    for t in tests:
        if t.get('Outcome') == 'Fail':
            cls = t.get('ApexClass', {}).get('Name', '?')
            method = t.get('MethodName', '?')
            msg    = t.get('Message', '')[:200]
            stack  = (t.get('StackTrace') or '')[:300]
            print(f"FAIL|{cls}.{method}|{msg}|{stack}")
except Exception as e:
    print(f"0|0|0|N/A")
PY
    )
    while IFS='|' read -r a b c d e; do
      if [[ "$a" =~ ^[0-9]+$ ]]; then TOTAL=$a; PASSED=$b; FAILED=$c; ORG_COVERAGE="${d}%"
      elif [[ "$a" == "FAIL" ]]; then
        FAILED_ROWS="${FAILED_ROWS}<tr style='background:#fef2f2'>"
        FAILED_ROWS="${FAILED_ROWS}<td style='color:#dc2626;font-weight:700'>${b}</td>"
        FAILED_ROWS="${FAILED_ROWS}<td>${c}</td><td><small>${d}</small></td></tr>"
      fi
    done <<< "$SUMMARY"
  fi

  # Build coverage rows from file if python didn't output above
  COVERAGE_ROWS=$(python3 - "$COV_FILE" <<'PY' 2>/dev/null || echo ""
import sys, json
try:
    with open(sys.argv[1]) as f: data = json.load(f)
    classes = data if isinstance(data, list) else data.get('coverage',{}).get('coverage',[])
    rows = []
    for c in sorted(classes, key=lambda x: x.get('coveragePercent',0) if isinstance(x,dict) else 0):
        if not isinstance(c,dict): continue
        name=c.get('name',c.get('apexClassOrTriggerName','?'))
        pct=c.get('coveragePercent',0)
        covered=c.get('coveredLines',0); uncovered=c.get('uncoveredLines',0)
        bar_w=int(pct)
        cls='#dc2626' if pct<75 else '#d97706' if pct<90 else '#16a34a'
        bg='#fef2f2' if pct<75 else '#fffbeb' if pct<90 else '#f0fdf4'
        bar=(f'<div style="background:#e2e8f0;border-radius:4px;height:10px;width:120px">'
             f'<div style="background:{cls};width:{bar_w}%;height:10px;border-radius:4px"></div></div>')
        rows.append(f'<tr style="background:{bg}"><td>{name}</td>'
                    f'<td style="text-align:right;font-weight:700;color:{cls}">{pct:.1f}%</td>'
                    f'<td>{bar}</td><td style="text-align:right">{covered}</td>'
                    f'<td style="text-align:right">{uncovered}</td></tr>')
    print('\n'.join(rows))
except: pass
PY
  )
fi

# Determine badge
if   [[ "$FAILED" -gt 0 ]];                                            then BADGE_COLOR="#dc2626"; BADGE_TEXT="FAILING"
elif [[ "$ORG_COVERAGE" != "N/A" ]] && \
     python3 -c "import sys; sys.exit(0 if float('${ORG_COVERAGE%\%}') >= 75 else 1)" 2>/dev/null; then
     BADGE_COLOR="#16a34a"; BADGE_TEXT="PASSING"
else BADGE_COLOR="#d97706"; BADGE_TEXT="WARNINGS"
fi

cat > "$OUT" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Test Coverage Report — ${ORG} — ${DATE_HUMAN}</title>
<style>
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#f8fafc;color:#1e293b}
  header{background:#1e293b;color:#fff;padding:24px 32px;display:flex;align-items:center;gap:16px}
  header h1{font-size:1.4rem;font-weight:700;flex:1}
  header .meta{font-size:.8rem;opacity:.7;line-height:1.6}
  .badge{padding:6px 16px;border-radius:20px;font-weight:700;font-size:.9rem;
         color:${BADGE_COLOR};background:#fff;border:2px solid ${BADGE_COLOR}}
  .cards{display:flex;gap:16px;padding:24px 32px;flex-wrap:wrap}
  .card{flex:1;min-width:140px;background:#fff;border-radius:8px;padding:20px;
        border:1px solid #e2e8f0;text-align:center}
  .card .num{font-size:2.2rem;font-weight:800;line-height:1}
  .card .label{font-size:.75rem;text-transform:uppercase;letter-spacing:.05em;margin-top:6px;opacity:.6}
  section{margin:0 32px 28px;background:#fff;border-radius:8px;border:1px solid #e2e8f0;overflow:hidden}
  section h2{padding:14px 20px;font-size:.9rem;text-transform:uppercase;letter-spacing:.05em;
             background:#f1f5f9;border-bottom:1px solid #e2e8f0;color:#475569}
  table{width:100%;border-collapse:collapse}
  th{padding:10px 14px;background:#f8fafc;font-size:.78rem;text-transform:uppercase;
     letter-spacing:.04em;color:#64748b;border-bottom:2px solid #e2e8f0;text-align:left}
  td{padding:8px 14px;border-bottom:1px solid #f1f5f9;font-size:.85rem}
  footer{text-align:center;padding:20px;font-size:.75rem;color:#94a3b8}
</style>
</head>
<body>
<header>
  <div style="flex:1">
    <h1>🧪 Apex Test Coverage Report</h1>
    <div class="meta">Org: <strong>${ORG}</strong> &nbsp;|&nbsp; ${DATE_HUMAN}</div>
  </div>
  <div class="badge">${BADGE_TEXT}</div>
</header>

<div class="cards">
  <div class="card" style="border-top:4px solid #2563eb">
    <div class="num" style="color:#2563eb">${TOTAL}</div><div class="label">Tests Run</div>
  </div>
  <div class="card" style="border-top:4px solid #16a34a">
    <div class="num" style="color:#16a34a">${PASSED}</div><div class="label">Passed</div>
  </div>
  <div class="card" style="border-top:4px solid #dc2626">
    <div class="num" style="color:#dc2626">${FAILED}</div><div class="label">Failed</div>
  </div>
  <div class="card" style="border-top:4px solid #7c3aed">
    <div class="num" style="color:#7c3aed">${ORG_COVERAGE}</div><div class="label">Org Coverage</div>
  </div>
</div>

$(if [[ -n "$FAILED_ROWS" ]]; then cat <<FSEC
<section>
  <h2>🔴 Failed Tests</h2>
  <table>
    <tr><th>Test Method</th><th>Error Message</th><th>Stack Trace</th></tr>
    ${FAILED_ROWS}
  </table>
</section>
FSEC
fi)

<section>
  <h2>Coverage by Class</h2>
  <table>
    <tr><th>Class / Trigger</th><th style="text-align:right">Coverage</th><th>Bar</th>
        <th style="text-align:right">Covered</th><th style="text-align:right">Uncovered</th></tr>
    ${COVERAGE_ROWS:-<tr><td colspan="5" style="text-align:center;padding:24px;color:#94a3b8">No coverage data found in /tmp/apex-test-results/</td></tr>}
  </table>
</section>

<footer>Generated by Claude Code salesforce-audit plugin &nbsp;|&nbsp; ${DATE_HUMAN}</footer>
</body>
</html>
HTML

echo ""
echo "🧪 Test coverage report saved → ${OUT}"
echo "   Open in browser: open ${OUT}"
