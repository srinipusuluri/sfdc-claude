---
name: apex-test-coverage
description: Run Apex tests, measure coverage, detect test quality issues (no assertions, test isolation failures, hard-coded IDs), and identify classes below threshold. Works on any org — scratch, sandbox, or production (read-only coverage query for prod).
argument-hint: [--target-org <alias>] [--threshold <pct>] [--run-tests]
---

# apex-test-coverage

## Mode A — Query existing coverage (fast, no test run)

Use when you want current coverage without re-running tests.

```bash
# Org-wide coverage percentage
sf data query \
  --query "SELECT PercentCovered FROM ApexOrgWideCoverage" \
  --target-org "${TARGET_ORG:-dev}" --use-tooling-api --json 2>/dev/null

# Per-class coverage — sorted worst first
sf data query \
  --query "SELECT ApexClassOrTrigger.Name, NumLinesCovered, NumLinesUncovered FROM ApexCodeCoverageAggregate WHERE NumLinesCovered + NumLinesUncovered > 0 ORDER BY NumLinesCovered ASC LIMIT 50" \
  --target-org "${TARGET_ORG:-dev}" --use-tooling-api --json 2>/dev/null

# Classes with zero coverage
sf data query \
  --query "SELECT ApexClassOrTrigger.Name FROM ApexCodeCoverageAggregate WHERE NumLinesCovered = 0 AND NumLinesUncovered > 0 ORDER BY ApexClassOrTrigger.Name" \
  --target-org "${TARGET_ORG:-dev}" --use-tooling-api --json 2>/dev/null
```

## Mode B — Run tests and report (slower, authoritative)

```bash
# Run all local tests with coverage
sf apex run test \
  --target-org "${TARGET_ORG:-dev}" \
  --test-level RunLocalTests \
  --code-coverage \
  --result-format human \
  --wait 15

# Run with JSON output for parsing
sf apex run test \
  --target-org "${TARGET_ORG:-dev}" \
  --test-level RunLocalTests \
  --code-coverage \
  --result-format json \
  --output-dir /tmp/apex-test-results \
  --wait 15
```

## Mode C — Run specific class(es)

```bash
sf apex run test \
  --target-org "${TARGET_ORG:-dev}" \
  --class-names "AccountService_Test,ContactService_Test" \
  --code-coverage \
  --result-format human \
  --wait 10
```

## Test quality checks (static analysis)

### 1. Test classes with no assertions (meaningless coverage)
```bash
grep -rl "testMethod\|@isTest" force-app --include="*.cls" | \
  xargs grep -L "System\.assert\|Assert\." 2>/dev/null
```

### 2. Test classes with hard-coded IDs
```bash
grep -rn "'001\|'003\|'005\|'006\|'00T\|'00U" force-app --include="*.cls" | \
  grep -i "test\|spec" | head -20
```

### 3. Test classes using SeeAllData=true (anti-pattern)
```bash
grep -rn "SeeAllData\s*=\s*true" force-app --include="*.cls"
```

### 4. Test classes calling Test.startTest() without Test.stopTest()
```bash
for f in $(grep -rl "Test\.startTest" force-app --include="*.cls"); do
  starts=$(grep -c "Test\.startTest" "$f" 2>/dev/null || echo 0)
  stops=$(grep -c "Test\.stopTest" "$f" 2>/dev/null || echo 0)
  [[ "$starts" != "$stops" ]] && echo "UNBALANCED: $f (start:$starts stop:$stops)"
done
```

### 5. Test classes missing @TestSetup (data setup repeated per test method — slow)
```bash
grep -rl "@isTest" force-app --include="*.cls" | \
  xargs grep -L "@testSetup\|TestDataFactory" 2>/dev/null | \
  head -10
```

### 6. Triggers without test coverage
```bash
# Find triggers
find force-app -name "*.trigger" | while read t; do
  trigger=$(basename "$t" .trigger)
  # Check if any test class references this trigger's handler
  if ! grep -rl "$trigger" force-app --include="*.cls" | grep -qi "test"; then
    echo "NO TEST COVERAGE: $trigger"
  fi
done
```

### 7. Test methods that catch exceptions silently (mask real failures)
```bash
grep -rn "catch.*Exception" force-app --include="*.cls" | \
  grep -i "test\|@isTest" | \
  grep -v "System\.assert\|Assert\." | head -20
```

## Coverage threshold enforcement

```python
# Threshold check (default 75%)
THRESHOLD = int("${THRESHOLD:-75}")

import json, sys
with open("/tmp/apex-test-results/test-result-codecoverage.json") as f:
    results = json.load(f)

below = [(r['name'], r['coveragePercent'])
         for r in results
         if r.get('coveragePercent', 100) < THRESHOLD]

if below:
    print(f"FAIL: {len(below)} classes below {THRESHOLD}%:")
    for name, pct in sorted(below, key=lambda x: x[1]):
        print(f"  {pct:5.1f}%  {name}")
    sys.exit(1)
else:
    print(f"PASS: All classes >= {THRESHOLD}%")
```

## Coverage report output

```
=== APEX TEST COVERAGE REPORT ===
Org-wide coverage:  82%  ✅ (threshold: 75%)
Classes analysed:   47
Classes passing:    44  ✅
Classes failing:    3   🔴

🔴 Below 75% threshold:
  12.0%  InvoiceCalloutService
  45.0%  BatchAccountSync
  68.0%  TriggerHandler (base class)

⚠️  Test quality issues:
  SeeAllData=true:     2 classes
  No assertions:       1 class
  Hard-coded IDs:      0 classes
  Unbalanced start/stop: 0 classes

Recent test failures:
  AccountService_Test.testNullName    FAIL  System.NullPointerException
```
