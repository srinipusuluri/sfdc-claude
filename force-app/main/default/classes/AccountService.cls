/**
 * AccountService
 *
 * Service class encapsulating Account-related business logic.
 * Intended to be called by AccountTriggerHandler (and other callers that need
 * programmatic Account operations).
 *
 * Design notes:
 *  - All methods are static to keep callers free of instantiation overhead.
 *  - Every method accepts a List so the class is inherently bulk-safe.
 *  - No SOQL or DML is performed inside any loop.
 *  - Declared with sharing to respect the running user's record visibility.
 */
public with sharing class AccountService {

    // ───────────────────────────────────────────────────────────
    // Public API
    // ───────────────────────────────────────────────────────────

    /**
     * normalizeNames
     *
     * Trims leading and trailing whitespace from the Name field of every
     * Account in the supplied list.  Safe to call from before-insert and
     * before-update contexts; no SOQL or DML is performed.
     *
     * @param accounts  List of Account records to normalize (Trigger.new).
     *                  A null or empty list is silently ignored.
     */
    public static void normalizeNames(List<Account> accounts) {
        if (accounts == null || accounts.isEmpty()) {
            return;
        }

        for (Account acc : accounts) {
            if (acc.Name != null) {
                acc.Name = acc.Name.trim();
            }
        }
    }
}
