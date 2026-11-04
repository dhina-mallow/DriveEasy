trigger BookingTrigger on Booking__c (before insert, before update, before delete, after insert) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            BookingTriggerHandler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            BookingTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            BookingTriggerHandler.beforeDelete(Trigger.old);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            BookingTriggerHandler.afterInsert(Trigger.new);
        }
    }
}