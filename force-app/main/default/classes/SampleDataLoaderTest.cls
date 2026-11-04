@IsTest
private class SampleDataLoaderTest {
    @IsTest
    static void loadSampleDataCreatesDriveEasyRecords() {
        Test.startTest();
        SampleDataLoader.run();
        Test.stopTest();

        System.assert([SELECT Count() FROM Car__c] >= 10);
        System.assert([SELECT Count() FROM Contact WHERE Licence_Number__c != null] >= 10);
        System.assert([SELECT Count() FROM Booking__c] > 0);
    }
}