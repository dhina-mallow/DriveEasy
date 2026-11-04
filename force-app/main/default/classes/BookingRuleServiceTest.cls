@IsTest
private class BookingRuleServiceTest {
    private static Datetime istDate(Integer day, Integer hour) {
        return Datetime.newInstanceGmt(2030, 1, day, hour, 0, 0).addMinutes(-330);
    }

    private static void init() {
        DriveEasySettings.useDefaultsForTest();
    }

    @IsTest
    static void validatesTimesCarDriverAndClashes() {
        init();
        DriveEasyTime.nowOverride = istDate(1, 6);
        Datetime pickup = istDate(5, 10);
        Datetime plannedReturn = istDate(6, 10);

        System.assertEquals(null, BookingRuleService.checkTimes(pickup, plannedReturn, true));
        System.assertNotEquals(null, BookingRuleService.checkTimes(null, plannedReturn, true));
        System.assertNotEquals(null, BookingRuleService.checkTimes(pickup, pickup, true));

        System.assertEquals('Car not found.', BookingRuleService.checkCar(null));
        Car__c maintenance = new Car__c(Name = 'MAINT', Status__c = 'Under_Maintenance');
        System.assert(BookingRuleService.checkCar(maintenance).contains('Under Maintenance'));

        System.assertEquals('Customer not found.', BookingRuleService.checkDriver(null, pickup, plannedReturn));
        Contact missingDob = new Contact(LastName = 'Missing DOB');
        System.assertEquals('The customer date of birth is missing.',
            BookingRuleService.checkDriver(missingDob, pickup, plannedReturn));

        Contact valid = new Contact(LastName = 'Valid', Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Licence_Expiry_Date__c = Date.newInstance(2031, 12, 31));
        System.assertEquals(null, BookingRuleService.checkDriver(valid, pickup, plannedReturn));

        System.assertEquals(null, BookingRuleService.checkTimes(pickup, plannedReturn, false));
        System.assert(BookingRuleService.checkTimes(istDate(5, 7), plannedReturn, false).contains('between'));
        System.assert(BookingRuleService.checkTimes(pickup, istDate(6, 22), false).contains('between'));
        Datetime monthLater = pickup.addDays(31);
        System.assertEquals('The longest rental is 30 days.',
            BookingRuleService.checkTimes(pickup, monthLater, false));

        Contact expired = new Contact(LastName = 'Expired', Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Licence_Expiry_Date__c = Date.newInstance(2029, 12, 31));
        System.assert(BookingRuleService.checkDriver(expired, pickup, plannedReturn).contains('expires'));

        Contact young = new Contact(LastName = 'Young', Date_of_Birth__c = Date.newInstance(2015, 1, 1),
            Licence_Expiry_Date__c = Date.newInstance(2032, 12, 31));
        System.assert(BookingRuleService.checkDriver(young, pickup, plannedReturn).contains('21'));
    }

    @IsTest
    static void findsClashesAndValidatesReturns() {
        init();
        Datetime pickup = istDate(5, 10);
        Datetime plannedReturn = istDate(6, 10);
        Booking__c newBooking = new Booking__c(Pickup_Date_Time__c = pickup, Return_Date_Time__c = plannedReturn);
        Booking__c existing = new Booking__c(Pickup_Date_Time__c = pickup.addMinutes(120),
            Return_Date_Time__c = plannedReturn.addMinutes(120));

        System.assertEquals(existing, BookingRuleService.findClash(newBooking, new List<Booking__c>{existing}));
        System.assertEquals(null, BookingRuleService.findClash(newBooking, null));
        Car__c car = new Car__c(Name = 'TN01-BRS-001');
        System.assert(BookingRuleService.clashMessage(existing, car).contains('overlaps'));

        Booking__c returned = new Booking__c(Pickup_Date_Time__c = pickup, Pickup_Odometer__c = 100,
            Actual_Return_Time__c = plannedReturn, Return_Odometer__c = 150);
        System.assertEquals(null, BookingRuleService.checkReturn(returned));
        returned.Return_Odometer__c = 90;
        System.assert(BookingRuleService.checkReturn(returned).contains('cannot be lower'));
        returned.Return_Odometer__c = null;
        System.assertEquals('Enter the actual return time and the return odometer.',
            BookingRuleService.checkReturn(returned));
        returned.Return_Odometer__c = 150;
        returned.Actual_Return_Time__c = pickup.addHours(-1);
        System.assert(BookingRuleService.checkReturn(returned).contains('before the pickup'));
    }
}