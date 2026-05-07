---
name: lwc-jest
description: Run LWC Jest tests with @salesforce/sfdx-lwc-jest. Use when the user asks to test, run, or debug Lightning Web Component unit tests.
---

# lwc-jest

Run Jest unit tests for LWC bundles.

## One-time setup

```bash
npm install --save-dev @salesforce/sfdx-lwc-jest @lwc/jest-preset
```

`package.json` scripts (from the standard `force-app` template):
```json
{
  "scripts": {
    "test:unit": "sfdx-lwc-jest",
    "test:unit:watch": "sfdx-lwc-jest --watch",
    "test:unit:debug": "sfdx-lwc-jest --debug",
    "test:unit:coverage": "sfdx-lwc-jest --coverage"
  }
}
```

## Common runs

```bash
npm run test:unit                       # all LWC tests
npm run test:unit -- --testPathPattern  accountList   # only matching files
npm run test:unit:coverage              # with coverage
```

## Test layout

```
force-app/main/default/lwc/accountList/
├── accountList.html
├── accountList.js
├── accountList.js-meta.xml
└── __tests__/
    └── accountList.test.js
```

## Mocking patterns

**Apex imperative call:**
```js
jest.mock(
  '@salesforce/apex/AccountController.getAccounts',
  () => ({ default: jest.fn() }),
  { virtual: true }
);
```

**Wire adapter:**
```js
import { createApexTestWireAdapter } from '@salesforce/sfdx-lwc-jest';
import getAccounts from '@salesforce/apex/AccountController.getAccounts';

jest.mock(
  '@salesforce/apex/AccountController.getAccounts',
  () => ({ default: createApexTestWireAdapter(jest.fn()) }),
  { virtual: true }
);

// in the test:
getAccounts.emit([{ Id: '001...', Name: 'Acme' }]);
```

**`refreshApex`:** mock `@salesforce/apex` and assert it was called with the wire result.

## Coverage targets

LWC has no governor-driven 75% rule, but treat 80% per-component as the floor and 90% for shared utilities. Coverage is reported under `coverage/lcov-report/index.html`.

## Failures

If a test imports a Salesforce module the preset doesn't stub, add a virtual mock or extend `jest.config.js` `moduleNameMapper`.
