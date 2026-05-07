/**
 * TriggerHandler
 *
 * Generic base class for the trigger handler pattern.
 * Extend this class and override the relevant virtual methods.
 * Call run() from the trigger body to dispatch to the correct override.
 */
public virtual with sharing class TriggerHandler {

    // ───────────────────────────────────────────────────────────
    // Dispatcher — call this from every trigger body
    // ───────────────────────────────────────────────────────────

    public void run() {
        switch on Trigger.operationType {
            when BEFORE_INSERT  { beforeInsert(); }
            when BEFORE_UPDATE  { beforeUpdate(); }
            when BEFORE_DELETE  { beforeDelete(); }
            when AFTER_INSERT   { afterInsert(); }
            when AFTER_UPDATE   { afterUpdate(); }
            when AFTER_DELETE   { afterDelete(); }
            when AFTER_UNDELETE { afterUndelete(); }
        }
    }

    // ───────────────────────────────────────────────────────────
    // Virtual no-op methods — override in subclasses as needed
    // ───────────────────────────────────────────────────────────

    protected virtual void beforeInsert()   {}
    protected virtual void beforeUpdate()   {}
    protected virtual void beforeDelete()   {}
    protected virtual void afterInsert()    {}
    protected virtual void afterUpdate()    {}
    protected virtual void afterDelete()    {}
    protected virtual void afterUndelete()  {}
}
