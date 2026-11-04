@IsTest
private class CarSearchControllerTest {
    private static Datetime istDate(Integer day, Integer hour) {
        return Datetime.newInstanceGmt(2030, 1, day, hour, 0, 0).addMinutes(-330);
    }

    @IsTest
    static void searchCarsReturnsAvailableCars() {
        BookingTriggerHandler.bypassRules = true;
        insert new List<Car__c>{
            new Car__c(Name = 'TN01-CSC-001', Make__c = 'Maruti', Model__c = 'Swift',
                Category__c = 'Hatchback', Status__c = 'Available', Daily_Rate__c = 1800,
                Free_KM_Per_Day__c = 250, Extra_KM_Rate__c = 10, Current_Odometer__c = 1000),
            new Car__c(Name = 'TN01-CSC-002', Make__c = 'Honda', Model__c = 'City',
                Category__c = 'Sedan', Status__c = 'Available', Daily_Rate__c = 2500,
                Free_KM_Per_Day__c = 250, Extra_KM_Rate__c = 12, Current_Odometer__c = 1000),
            new Car__c(Name = 'TN01-CSC-003', Make__c = 'Honda', Model__c = 'City',
                Category__c = 'Sedan', Status__c = 'Under_Maintenance', Daily_Rate__c = 2500,
                Free_KM_Per_Day__c = 250, Extra_KM_Rate__c = 12, Current_Odometer__c = 1000)
        };

        DriveEasyTime.nowOverride = istDate(1, 6);
        Test.startTest();
        List<CarSearchController.CarResult> allCars =
            CarSearchController.searchCars('All', istDate(5, 10), istDate(7, 10));
        List<CarSearchController.CarResult> sedans =
            CarSearchController.searchCars('Sedan', istDate(5, 10), istDate(7, 10));
        Test.stopTest();

        System.assertEquals(2, allCars.size());
        System.assertEquals(1, sedans.size());
        System.assertEquals(2500, sedans[0].dailyRate);
        BookingTriggerHandler.bypassRules = false;
    }

    @IsTest
    static void searchCarsRejectsInvalidTimes() {
        Datetime pickup = istDate(5, 10);
        try {
            CarSearchController.searchCars('All', pickup, pickup);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException expected) {
            System.assert(expected.getMessage().contains('Return'));
        }
    }
}