public with sharing class DriveEasySettings {
    // Tests can put their own values here
    @TestVisible private static DriveEasy_Setting__mdt testSetting;

    private static DriveEasy_Setting__mdt settings() {
        if (testSetting != null) { return testSetting; }
        return DriveEasy_Setting__mdt.getInstance('Default');
    }

    // The Custom Metadata value, or the fallback when the record or the value is missing
    private static Decimal value(String fieldName, Decimal fallback) {
        DriveEasy_Setting__mdt s = settings();
        if (s == null) { return fallback; }
        Object v = s.get(fieldName);
        return (v == null) ? fallback : (Decimal) v;
    }

    public static Decimal gstPercent() { return value('GST_Percent__c', 18); }
    public static Decimal lateFeePercentPerHour() { return value('Late_Fee_Percent_Per_Hour__c', 10); }
    public static Integer graceMinutes() { return value('Grace_Minutes__c', 60).intValue(); }
    public static Integer bufferMinutes() { return value('Buffer_Minutes__c', 60).intValue(); }
    public static Integer minimumDriverAge() { return value('Minimum_Driver_Age__c', 21).intValue(); }
    public static Integer minimumLeadHours() { return value('Minimum_Lead_Hours__c', 2).intValue(); }
    public static Integer openHour() { return value('Branch_Open_Hour__c', 8).intValue(); }
    public static Integer closeHour() { return value('Branch_Close_Hour__c', 21).intValue(); }
    public static Integer maxRentalDays() { return value('Max_Rental_Days__c', 30).intValue(); }

    // 8 gives "8:00 AM", 21 gives "9:00 PM"
    public static String hourText(Integer hour24) {
        Integer h = Math.mod(hour24, 12);
        return (h == 0 ? 12 : h) + ':00 ' + (hour24 < 12 ? 'AM' : 'PM');
    }

    // Tests call this so they do not depend on what is saved in the org
    @TestVisible
    private static void useDefaultsForTest() {
        testSetting = new DriveEasy_Setting__mdt(
            GST_Percent__c = 18, Late_Fee_Percent_Per_Hour__c = 10, Grace_Minutes__c = 60,
            Buffer_Minutes__c = 60, Minimum_Driver_Age__c = 21, Minimum_Lead_Hours__c = 2,
            Branch_Open_Hour__c = 8, Branch_Close_Hour__c = 21, Max_Rental_Days__c = 30);
    }
}