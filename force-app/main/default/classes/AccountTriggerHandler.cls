/**
 * AccountTriggerHandler
 *
 * Trigger handler for the Account object. Extends TriggerHandler and
 * overrides the context methods relevant to Account business logic.
 * Delegates business rules to AccountService to keep the handler thin.
 */
public with sharing class AccountTriggerHandler extends TriggerHandler {

    /**
     * beforeInsert — normalize Account names before new records are saved.
     */
    protected override void beforeInsert() {
        AccountService.normalizeNames(Trigger.new);
    }

    /**
     * beforeUpdate — normalize Account names before existing records are updated.
     */
    protected override void beforeUpdate() {
        AccountService.normalizeNames(Trigger.new);
    }
}
