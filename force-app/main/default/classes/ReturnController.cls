public with sharing class ReturnController {
    private static Booking__c load(Id bookingId) {
        return [SELECT Id, Status__c, Daily_Rate__c, Free_Km_Per_Day__c, Extra_Km_Rate__c,
                       Pickup_Date_Time__c, Return_Date_Time__c, Pickup_Odometer__c
                FROM Booking__c WHERE Id = :bookingId WITH USER_MODE];
    }

    // Shows the bill WITHOUT saving anything (FR-11). Uses the same BillingService as the real return.
    @AuraEnabled
    public static BillingService.Bill previewBill(Id bookingId, Datetime actualReturn, Decimal returnOdometer) {
        Booking__c b = load(bookingId);
        if (b.Status__c != 'Picked Up') { throw err('Only a Picked Up booking can be returned.'); }
        b.Actual_Return_Time__c = actualReturn;
        b.Return_Odometer__c = returnOdometer;
        String msg = BookingRuleService.checkReturn(b);
        if (msg != null) { throw err(msg); }
        return BillingService.calculate(b.Daily_Rate__c, b.Free_Km_Per_Day__c, b.Extra_Km_Rate__c,
            b.Pickup_Date_Time__c, b.Return_Date_Time__c, actualReturn, b.Pickup_Odometer__c, returnOdometer);
    }

    // Saves the return. The trigger recalculates and stores the bill, the flow frees the car.
    // Only the fields the agent may edit are sent in the update. The copied-rate fields are read only
    // for agents, so they must NOT be part of this update.
    @AuraEnabled
    public static void confirmReturn(Id bookingId, Datetime actualReturn, Decimal returnOdometer) {
        Booking__c b = new Booking__c(
            Id = bookingId,
            Actual_Return_Time__c = actualReturn,
            Return_Odometer__c = returnOdometer,
            Status__c = 'Returned');
        try {
            // User mode: only users who may edit bookings and these fields can return a car
            update as user b;
        } catch (DmlException e) {
            throw err(e.getDmlMessage(0));
        } catch (SecurityException e) {
            throw err('You do not have permission to return this booking.');
        }
    }

    private static AuraHandledException err(String msg) {
        AuraHandledException e = new AuraHandledException(msg);
        e.setMessage(msg);
        return e;
    }
}