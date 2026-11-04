@IsTest
private class ReturnControllerTest {
    private static Datetime istDate(Integer day, Integer hour) {
        return Datetime.newInstanceGmt(2030, 1, day, hour, 0, 0).addMinutes(-330);
    }

    @IsTest
    static void previewAndConfirmReturn() {
        BookingTriggerHandler.bypassRules = true;
        Car__c car = new Car__c(Name = 'TN01-RCT-001', Status__c = 'Available',
            Make__c = 'Maruti', Model__c = 'Swift', Category__c = 'Hatchback',
            Daily_Rate__c = 1800, Free_KM_Per_Day__c = 250, Extra_KM_Rate__c = 10,
            Current_Odometer__c = 1000);
        insert car;
        Contact customer = new Contact(LastName = 'Return Controller Test', Phone = '9876543210',
            Licence_Number__c = 'TN01LIC003', Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Licence_Expiry_Date__c = Date.newInstance(2032, 12, 31));
        insert customer;
        Datetime pickup = istDate(5, 10);
        Datetime plannedReturn = istDate(7, 10);
        Booking__c booking = new Booking__c(Car__c = car.Id, Customer__c = customer.Id,
            Pickup_Date_Time__c = pickup, Return_Date_Time__c = plannedReturn,
            Status__c = 'Picked Up', Pickup_Odometer__c = 1000, Daily_Rate__c = 1800,
            Free_Km_Per_Day__c = 250, Extra_Km_Rate__c = 10);
        insert booking;

        Datetime actualReturn = plannedReturn.addMinutes(120);
        Test.startTest();
        BillingService.Bill preview = ReturnController.previewBill(booking.Id, actualReturn, 1500);
        ReturnController.confirmReturn(booking.Id, actualReturn, 1500);
        Test.stopTest();

        System.assert(preview.total > 0);
        Booking__c returned = [SELECT Status__c, Actual_Return_Time__c, Return_Odometer__c
                               FROM Booking__c WHERE Id = :booking.Id];
        System.assertEquals('Returned', returned.Status__c);
        System.assertEquals(1500, returned.Return_Odometer__c);
        BookingTriggerHandler.bypassRules = false;
    }

    @IsTest
    static void previewBillRejectsInvalidStatusAndReturnValues() {
        BookingTriggerHandler.bypassRules = true;
        Car__c car = new Car__c(Name = 'TN01-RCT-002', Make__c = 'Maruti', Model__c = 'Swift',
            Category__c = 'Hatchback', Status__c = 'Available', Daily_Rate__c = 1800,
            Free_KM_Per_Day__c = 250, Extra_KM_Rate__c = 10, Current_Odometer__c = 1000);
        insert car;
        Contact customer = new Contact(LastName = 'Return Error Test', Phone = '9876543211',
            Licence_Number__c = 'TN01LIC005', Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Licence_Expiry_Date__c = Date.newInstance(2032, 12, 31));
        insert customer;
        Datetime pickup = istDate(5, 10);
        Booking__c reserved = new Booking__c(Car__c = car.Id, Customer__c = customer.Id,
            Pickup_Date_Time__c = pickup, Return_Date_Time__c = pickup.addDays(1),
            Status__c = 'Reserved');
        insert reserved;

        try {
            ReturnController.previewBill(reserved.Id, pickup.addDays(1), 1200);
            System.assert(false, 'Expected Reserved booking error');
        } catch (AuraHandledException expected) {
            System.assert(expected.getMessage().contains('Picked Up'));
        }

        reserved.Status__c = 'Picked Up';
        reserved.Pickup_Odometer__c = 1000;
        update reserved;
        try {
            ReturnController.previewBill(reserved.Id, pickup.addHours(-1), 900);
            System.assert(false, 'Expected lower odometer error');
        } catch (AuraHandledException expected) {
            System.assert(expected.getMessage().contains('cannot be lower'));
        }
        BookingTriggerHandler.bypassRules = false;
    }

    @IsTest
    static void confirmReturnConvertsDmlError() {
        BookingTriggerHandler.bypassRules = true;
        Car__c car = new Car__c(Name = 'TN01-RCT-003', Make__c = 'Maruti', Model__c = 'Swift',
            Category__c = 'Hatchback', Status__c = 'Available', Daily_Rate__c = 1800,
            Free_KM_Per_Day__c = 250, Extra_KM_Rate__c = 10, Current_Odometer__c = 1000);
        insert car;
        Contact customer = new Contact(LastName = 'Return DML Error', Phone = '9876543214',
            Licence_Number__c = 'TN01LIC008', Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Licence_Expiry_Date__c = Date.newInstance(2032, 12, 31));
        insert customer;
        Booking__c anchor = new Booking__c(Car__c = car.Id, Customer__c = customer.Id,
            Pickup_Date_Time__c = istDate(5, 10), Return_Date_Time__c = istDate(6, 10),
            Status__c = 'Reserved');
        insert anchor;
        String missingId = String.valueOf(anchor.Id).substring(0, 15) + '000';
        Test.startTest();
        try {
            ReturnController.confirmReturn(missingId, istDate(5, 10), 1200);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
        Test.stopTest();
        BookingTriggerHandler.bypassRules = false;
    }
}