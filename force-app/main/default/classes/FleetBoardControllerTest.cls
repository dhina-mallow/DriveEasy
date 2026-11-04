@IsTest
private class FleetBoardControllerTest {
    private static Car__c makeCar(String registration, String category) {
        Car__c car = new Car__c(
            Name = registration,
            Make__c = 'Test Make',
            Model__c = 'Test Model',
            Category__c = category,
            Daily_Rate__c = 1800,
            Free_KM_Per_Day__c = 250,
            Extra_KM_Rate__c = 10,
            Current_Odometer__c = 1000,
            Status__c = 'Available'
        );
        insert car;
        return car;
    }

    private static Contact makeCustomer() {
        Contact customer = new Contact(LastName = 'Fleet Test Customer', Phone = '9876543210',
            Licence_Number__c = 'TN01FLEET001', Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Licence_Expiry_Date__c = Date.newInstance(2032, 12, 31));
        insert customer;
        return customer;
    }

    private static Booking__c makeBooking(Id carId, Id customerId, Datetime pickup, Datetime plannedReturn) {
        return new Booking__c(
            Car__c = carId,
            Customer__c = customerId,
            Pickup_Date_Time__c = pickup,
            Return_Date_Time__c = plannedReturn,
            Status__c = 'Reserved'
        );
    }

    private static Datetime ist(Integer day, Integer hour, Integer minute) {
        return Datetime.newInstanceGmt(2030, 1, day, hour, minute, 0).addMinutes(-330);
    }

    @IsTest static void boardShowsCountsAndBookingDetails() {
        DriveEasySettings.useDefaultsForTest();
        // Fix "now" so the 2030 dates below never depend on the real date
        DriveEasyTime.nowOverride = ist(1, 6, 0);
        Car__c free = makeCar('TN37-F-0001', 'Hatchback');
        Car__c rented = makeCar('TN37-F-0002', 'Sedan');
        Car__c shop = makeCar('TN37-F-0003', 'SUV');
        update new Car__c(Id = shop.Id, Status__c = 'Under_Maintenance');
        Contact cust = makeCustomer();
        String custName = [SELECT Name FROM Contact WHERE Id = :cust.Id].Name;

        // A future reservation on the free car
        Booking__c next = makeBooking(free.Id, cust.Id, ist(5, 10, 0), ist(7, 10, 0));
        insert next;

        // A car that is out on rent
        Booking__c out = makeBooking(rented.Id, cust.Id, ist(3, 10, 0), ist(4, 10, 0));
        insert out;
        out.Status__c = 'Picked Up';
        out.Pickup_Odometer__c = 12000;
        update out;
        update new Car__c(Id = rented.Id, Status__c = 'On_Rent');   // the flow already does this; keeps the test independent

        FleetBoardData data = FleetBoardController.getFleet();
        System.assertEquals(3, data.total);
        System.assertEquals(1, data.available);
        System.assertEquals(1, data.onRent);
        System.assertEquals(1, data.maintenance);

        String nextName = [SELECT Name FROM Booking__c WHERE Id = :next.Id].Name;
        String outName = [SELECT Name FROM Booking__c WHERE Id = :out.Id].Name;
        Integer checked = 0;
        for (FleetCard c : data.cards) {
            if (c.carId == free.Id) {
                System.assertEquals(nextName, c.nextBooking);
                System.assertEquals(custName, c.nextCustomer);
                System.assertEquals(1, c.upcomingCount);
                checked++;
            } else if (c.carId == rented.Id) {
                System.assertEquals(outName, c.currentBooking);
                System.assertEquals(custName, c.currentCustomer);
                System.assertEquals(ist(4, 11, 0), c.availableFrom);   // return 10:00 plus 1 hour buffer
                checked++;
            } else if (c.carId == shop.Id) {
                System.assertEquals('Under Maintenance', c.status);
                checked++;
            }
        }
        System.assertEquals(3, checked);
    }
}