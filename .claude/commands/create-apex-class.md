---
description: Scaffold a new Apex class with a matching test class
argument-hint: <ClassName> [--with-trigger <ObjectName>]
---

Create a new Apex class named `$ARGUMENTS` under `force-app/main/default/classes/` with:

1. **Class file** (`$ARGUMENTS.cls`):
   - `public with sharing` by default
   - Class-level Javadoc summarizing purpose
   - One private constructor if it's a utility class

2. **Metadata file** (`$ARGUMENTS.cls-meta.xml`):
   - API version matching `sfdx-project.json`
   - `<status>Active</status>`

3. **Test class** (`$ARGUMENTS_Test.cls`):
   - `@IsTest` annotation
   - `@TestSetup` method for shared data
   - At least one positive and one negative test method
   - Aim for ≥ 90% coverage

If `--with-trigger <ObjectName>` is provided, also generate:
- A trigger `<ObjectName>Trigger.trigger` covering all events
- A handler class `<ObjectName>TriggerHandler.cls` extending a base handler
- The class `$ARGUMENTS` should be wired into the handler

After scaffolding, run `sf project deploy start --dry-run` to validate.
