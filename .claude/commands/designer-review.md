---
description: Run a UX and design review of Salesforce LWC components and Experience Cloud pages — SLDS compliance, accessibility (WCAG 2.1 AA), responsiveness, and UX patterns.
argument-hint: [--target <path-or-component>] [--wcag]
---

Perform a design and accessibility review using the **ux-designer** agent.

## Steps

1. Parse arguments:
   - `--target`: defaults to `force-app/main/default/lwc` (all LWC)
   - `--wcag`: if present, run a strict WCAG 2.1 AA check

2. Gather all LWC component files:
   ```bash
   find "${TARGET:-force-app/main/default/lwc}" -name "*.html" -o -name "*.css" -o -name "*.js" | \
     grep -v "__tests__" | sort
   ```

3. Run the **ux-designer** agent on each component to check:

   **SLDS compliance:**
   ```bash
   # Custom CSS that should use SLDS tokens
   grep -rn "color:\s*#\|font-size:\|padding:\|margin:" \
     force-app --include="*.css" | grep -v "var(--slds"

   # Direct style attributes (should use SLDS classes)
   grep -rn 'style="' force-app --include="*.html"

   # Hardcoded hex colors
   grep -rn "#[0-9a-fA-F]\{3,6\}" force-app --include="*.css"
   ```

   **Accessibility:**
   ```bash
   # Missing alternative text on icons
   grep -rn "lightning-icon" force-app --include="*.html" | grep -v "alternative-text"

   # Images without alt
   grep -rn "<img" force-app --include="*.html" | grep -v "alt="

   # onclick without keyboard handler (onkeydown/onkeypress)
   grep -rn "onclick=" force-app --include="*.html" | grep -v "button\|lightning-button\|a "

   # XSS risks: innerHTML / lwc:dom="manual"
   grep -rn 'innerHTML\|lwc:dom="manual"' force-app --include="*.html" --include="*.js"

   # Missing aria attributes on custom interactive elements
   grep -rn "role=" force-app --include="*.html" | grep -v "aria-"
   ```

   **Responsive layout:**
   ```bash
   # Fixed pixel widths (should use SLDS grid)
   grep -rn "width:\s*[0-9]*px\|height:\s*[0-9]*px" force-app --include="*.css" | \
     grep -v "border\|outline\|shadow"

   # Missing responsive grid classes
   grep -rn "slds-col" force-app --include="*.html" | grep -v "slds-size"
   ```

   **LWC patterns:**
   ```bash
   # Loading states (should have spinner)
   grep -rn "@wire\|@AuraEnabled" force-app --include="*.js" | \
     xargs grep -L "isLoading\|lightning-spinner" 2>/dev/null | head -10

   # Error handling in templates
   grep -rn "if:true={error}\|{error.body.message}" force-app --include="*.html" | wc -l
   ```

4. If `--wcag` flag is present, check:
   - Focus management in modals and popovers
   - Tab order (positive `tabindex` values)
   - Color contrast (report component names with custom colors for manual check)
   - Form label associations
   - ARIA live regions for dynamic content

## Output

Produce a design review report:

1. **Design health**: 🟢 / 🟡 / 🔴 per component
2. **Findings table**:

| Severity | Component:Line | Category | Finding | Recommended Fix |
|----------|---------------|----------|---------|----------------|

Categories: **Accessibility** · **SLDS Violation** · **Responsiveness** · **UX Pattern** · **Security (XSS)**

3. **Top 5 improvements** ranked by user impact
4. **WCAG checklist** (if `--wcag` flag used)
