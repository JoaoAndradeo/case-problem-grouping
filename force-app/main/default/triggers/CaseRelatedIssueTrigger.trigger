trigger CaseRelatedIssueTrigger on CaseRelatedIssue (after insert, after delete, after undelete) {
    if (Trigger.isDelete) {
        CaseRelatedIssueTriggerHandler.afterDelete(Trigger.old);
    } else {
        CaseRelatedIssueTriggerHandler.afterInsert(Trigger.new);
    }
}