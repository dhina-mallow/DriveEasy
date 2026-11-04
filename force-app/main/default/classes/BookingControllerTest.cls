@IsTest
private class BookingControllerTest {
    private static Datetime istDate(Integer day) {
        return Datetime.newInstanceGmt(2030, 1, day, 10, 0, 0).addMinutes(-330);
    }

    @IsTest
    static void createBookingCreatesReservedBooking() {
        BookingTriggerHandler.bypassRules = true;
        Car__c car = new Car__c(Name = 'TN01-BCT-001', Make__c = 'Maruti', Model__c = 'Swift',
            Category__c = 'Hatchback', Status__c = 'Available', Daily_Rate__c = 1800,
            Free_KM_Per_Day__c = 250, Extra_KM_Rate__c = 10, Current_Odometer__c = 1000);
        insert car;
        Contact customer = new Contact(LastName = 'Booking Controller Test', Phone = '9876543210',
            Licence_Number__c = 'TN01LIC001', Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Licence_Expiry_Date__c = Date.newInstance(2032, 12, 31));
        insert customer;

        Test.startTest();
        String bookingName = BookingController.createBooking(
            car.Id, customer.Id, istDate(5), istDate(6));
        Test.stopTest();

        Booking__c booking = [SELECT Name, Status__c FROM Booking__c WHERE Id != null LIMIT 1];
        System.assertEquals('Reserved', booking.Status__c);
        System.assertEquals(bookingName, booking.Name);
        BookingTriggerHandler.bypassRules = false;
    }

    @IsTest
    static void createBookingConvertsDmlErrorToAuraException() {
        Test.startTest();
        try {
            BookingController.createBooking(null, null, istDate(5), istDate(6));
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
        Test.stopTest();
    }
}