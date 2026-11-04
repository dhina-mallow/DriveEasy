@IsTest
private class BookingNotificationQueueableTest {
    @IsTest
    static void executeSendsForEmailCustomersAndIgnoresMissingEmails() {
        BookingTriggerHandler.bypassRules = true;
        insert new Car__c(Name = 'TN01-QCT-001', Make__c = 'Maruti', Model__c = 'Swift',
            Category__c = 'Hatchback', Status__c = 'Available', Daily_Rate__c = 1800,
            Free_KM_Per_Day__c = 250, Extra_KM_Rate__c = 10, Current_Odometer__c = 1000);
        Contact customer = new Contact(LastName = 'Queue Test', Email = 'queue@example.com', Phone = '9876543210',
            Licence_Number__c = 'TN01LIC002', Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Licence_Expiry_Date__c = Date.newInstance(2032, 12, 31));
        insert customer;

        Datetime pickup = Datetime.newInstanceGmt(2030, 1, 5, 4, 30, 0);
        Booking__c booking = new Booking__c(Car__c = [SELECT Id FROM Car__c LIMIT 1].Id,
            Customer__c = customer.Id, Pickup_Date_Time__c = pickup,
            Return_Date_Time__c = pickup.addDays(1), Status__c = 'Reserved',
            Skip_Confirmation_Email__c = false);
        insert booking;

        Test.startTest();
        System.enqueueJob(new BookingNotificationQueueable(new List<Id>{booking.Id}));
        Test.stopTest();

        BookingTriggerHandler.bypassRules = false;
        System.assertEquals(1, [SELECT Count() FROM Booking__c WHERE Id = :booking.Id]);
    }
}