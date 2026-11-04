@IsTest
private class DriveEasySettingsTest {
    @IsTest
    static void defaultsApplyWhenNothingIsConfigured() {
        DriveEasySettings.testSetting = new DriveEasy_Setting__mdt();
        System.assertEquals(18, DriveEasySettings.gstPercent());
        System.assertEquals(10, DriveEasySettings.lateFeePercentPerHour());
        System.assertEquals(60, DriveEasySettings.graceMinutes());
        System.assertEquals(60, DriveEasySettings.bufferMinutes());
        System.assertEquals(21, DriveEasySettings.minimumDriverAge());
        System.assertEquals(2, DriveEasySettings.minimumLeadHours());
        System.assertEquals(8, DriveEasySettings.openHour());
        System.assertEquals(21, DriveEasySettings.closeHour());
        System.assertEquals(30, DriveEasySettings.maxRentalDays());
    }

    @IsTest
    static void configuredValuesAreUsed() {
        DriveEasySettings.testSetting = new DriveEasy_Setting__mdt(
            Minimum_Driver_Age__c = 25, Branch_Open_Hour__c = 9, Branch_Close_Hour__c = 20);
        System.assertEquals(25, DriveEasySettings.minimumDriverAge());
        System.assertEquals('9:00 AM', DriveEasySettings.hourText(DriveEasySettings.openHour()));
        System.assertEquals('8:00 PM', DriveEasySettings.hourText(DriveEasySettings.closeHour()));
    }

    @IsTest
    static void hourTextHandlesNoonAndMidnight() {
        System.assertEquals('12:00 PM', DriveEasySettings.hourText(12));
        System.assertEquals('12:00 AM', DriveEasySettings.hourText(0));
        System.assertEquals('9:00 PM', DriveEasySettings.hourText(21));
    }

    @IsTest
    static void aStricterAgeRuleIsApplied() {
        DriveEasySettings.testSetting = new DriveEasy_Setting__mdt(Minimum_Driver_Age__c = 25);
        Contact c = new Contact(LastName = 'X',
            Date_of_Birth__c = Date.today().addYears(-23),
            Licence_Expiry_Date__c = Date.today().addYears(3));
        Datetime p = DriveEasyTime.ist(Date.today().addDays(5), 10, 0);
        String msg = BookingRuleService.checkDriver(c, p, p.addDays(2));
        System.assertNotEquals(null, msg);
        System.assert(msg.contains('25'));
    }
}