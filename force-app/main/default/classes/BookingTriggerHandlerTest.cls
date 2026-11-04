@IsTest
private class BookingTriggerHandlerTest {
    private static Datetime istDate(Integer day, Integer hour) {
        return Datetime.newInstanceGmt(2030, 1, day, hour, 0, 0).addMinutes(-330);
    }

    @IsTest
    static void triggerInsertsAndBlocksDeletion() {
        BookingTriggerHandler.bypassRules = true;
        Car__c car = new Car__c(Name = 'TN01-THT-001', Status__c = 'Available',
            Make__c = 'Maruti', Model__c = 'Swift', Category__c = 'Hatchback',
            Daily_Rate__c = 1800, Free_KM_Per_Day__c = 250, Extra_KM_Rate__c = 10,
            Current_Odometer__c = 1000);
        insert car;
        Contact customer = new Contact(LastName = 'Trigger Handler Test',
            Phone = '9876543210',
            Licence_Number__c = 'TN01LIC004',
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Licence_Expiry_Date__c = Date.newInstance(2032, 12, 31));
        insert customer;
        BookingTriggerHandler.bypassRules = false;
        DriveEasyTime.nowOverride = istDate(1, 6);

        Booking__c booking = new Booking__c(Car__c = car.Id, Customer__c = customer.Id,
            Pickup_Date_Time__c = istDate(5, 10), Return_Date_Time__c = istDate(7, 10),
            Status__c = 'Reserved');
        insert booking;

        System.assertEquals(1800, [SELECT Daily_Rate__c FROM Booking__c WHERE Id = :booking.Id].Daily_Rate__c);

        Test.startTest();
        try {
            delete booking;
            System.assert(false, 'Expected deletion to be rejected');
        } catch (DmlException expected) {
            System.assert(expected.getMessage().contains('cannot be deleted'));
        }
        Test.stopTest();
    }

    @IsTest
    static void validatesInsertAndUpdateRulesDirectly() {
        BookingTriggerHandler.bypassRules = true;
        Car__c available = new Car__c(Name = 'TN01-THT-002', Status__c = 'Available',
            Make__c = 'Maruti', Model__c = 'Swift', Category__c = 'Hatchback',
            Daily_Rate__c = 1800, Free_KM_Per_Day__c = 250, Extra_KM_Rate__c = 10,
            Current_Odometer__c = 1000);
        Car__c maintenance = available.clone(false, true, false, false);
        maintenance.Name = 'TN01-THT-003';
        maintenance.Status__c = 'Under_Maintenance';
        insert new List<Car__c>{available, maintenance};
        Contact customer = new Contact(LastName = 'Trigger Branch Test', Phone = '9876543212',
            Licence_Number__c = 'TN01LIC006', Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Licence_Expiry_Date__c = Date.newInstance(2032, 12, 31));
        insert customer;
        BookingTriggerHandler.bypassRules = false;
        DriveEasyTime.nowOverride = istDate(1, 6);

        Booking__c missingCustomer = new Booking__c(Car__c = available.Id,
            Pickup_Date_Time__c = istDate(5, 10), Return_Date_Time__c = istDate(7, 10));
        Booking__c invalidStatus = new Booking__c(Car__c = available.Id, Customer__c = customer.Id,
            Pickup_Date_Time__c = istDate(5, 10), Return_Date_Time__c = istDate(7, 10),
            Status__c = 'Picked Up');
        Booking__c maintenanceBooking = new Booking__c(Car__c = maintenance.Id, Customer__c = customer.Id,
            Pickup_Date_Time__c = istDate(5, 10), Return_Date_Time__c = istDate(7, 10),
            Status__c = 'Reserved');
        BookingTriggerHandler.beforeInsert(new List<Booking__c>{
            missingCustomer, invalidStatus, maintenanceBooking
        });
        System.assert(missingCustomer.hasErrors());
        System.assert(invalidStatus.hasErrors());
        System.assert(maintenanceBooking.hasErrors());

        Booking__c pickup = new Booking__c(Id = null, Car__c = available.Id, Customer__c = customer.Id,
            Pickup_Date_Time__c = istDate(5, 10), Return_Date_Time__c = istDate(7, 10),
            Status__c = 'Reserved');
        insert pickup;
        Id bookingId = pickup.Id;
        Booking__c pickupOld = pickup.clone(false, true, false, false);
        pickupOld.Status__c = 'Returned';
        pickupOld.Id = pickup.Id;
        Booking__c returned = pickup.clone(false, true, false, false);
        returned.Id = pickup.Id;
        BookingTriggerHandler.beforeUpdate(new List<Booking__c>{returned},
            new Map<Id, Booking__c>{pickup.Id => pickupOld});
        System.assert(returned.hasErrors());

        Booking__c cancelled = pickup.clone(false, true, false, false);
        cancelled.Id = bookingId;
        Booking__c cancelledOld = cancelled.clone(false, true, false, false);
        cancelledOld.Status__c = 'Reserved';
        cancelled.Status__c = 'Cancelled';
        BookingTriggerHandler.beforeUpdate(new List<Booking__c>{cancelled},
            new Map<Id, Booking__c>{cancelled.Id => cancelledOld});
        System.assert(cancelled.hasErrors());
        BookingTriggerHandler.bypassRules = true;
        BookingTriggerHandler.beforeDelete(new List<Booking__c>{new Booking__c(Id = cancelled.Id)});
    }

    @IsTest
    static void validatesPickupAndReturnUpdatesDirectly() {
        BookingTriggerHandler.bypassRules = true;
        Car__c available = new Car__c(Name = 'TN01-THT-004', Status__c = 'Available',
            Make__c = 'Maruti', Model__c = 'Swift', Category__c = 'Hatchback',
            Daily_Rate__c = 1800, Free_KM_Per_Day__c = 250, Extra_KM_Rate__c = 10,
            Current_Odometer__c = 1000);
        insert available;
        Contact customer = new Contact(LastName = 'Trigger Pickup Test', Phone = '9876543213',
            Licence_Number__c = 'TN01LIC007', Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Licence_Expiry_Date__c = Date.newInstance(2032, 12, 31));
        insert customer;
        insert new Booking__c(Car__c = available.Id, Customer__c = customer.Id,
            Pickup_Date_Time__c = istDate(5, 10), Return_Date_Time__c = istDate(7, 10),
            Status__c = 'Reserved');
        BookingTriggerHandler.bypassRules = false;

        Id bookingId = [SELECT Id FROM Booking__c WHERE Customer__c = :customer.Id LIMIT 1].Id;
        Booking__c oldBooking = new Booking__c(Id = bookingId, Car__c = available.Id,
            Customer__c = customer.Id, Pickup_Date_Time__c = istDate(5, 10),
            Return_Date_Time__c = istDate(7, 10), Status__c = 'Reserved');
        Booking__c pickedUp = new Booking__c(Id = bookingId, Car__c = available.Id,
            Customer__c = customer.Id, Pickup_Date_Time__c = oldBooking.Pickup_Date_Time__c,
            Return_Date_Time__c = oldBooking.Return_Date_Time__c, Status__c = 'Picked Up');
        BookingTriggerHandler.beforeUpdate(new List<Booking__c>{pickedUp},
            new Map<Id, Booking__c>{bookingId => oldBooking});
        System.assert(pickedUp.hasErrors());

        Booking__c returnOld = new Booking__c(Id = bookingId, Car__c = available.Id,
            Customer__c = customer.Id, Pickup_Date_Time__c = oldBooking.Pickup_Date_Time__c,
            Return_Date_Time__c = oldBooking.Return_Date_Time__c, Status__c = 'Picked Up',
            Pickup_Odometer__c = 1000, Daily_Rate__c = 1800, Free_Km_Per_Day__c = 250,
            Extra_Km_Rate__c = 10);
        Booking__c returned = new Booking__c(Id = bookingId, Car__c = available.Id,
            Customer__c = customer.Id, Pickup_Date_Time__c = oldBooking.Pickup_Date_Time__c,
            Return_Date_Time__c = oldBooking.Return_Date_Time__c, Status__c = 'Returned',
            Pickup_Odometer__c = 1000, Actual_Return_Time__c = istDate(7, 10).addHours(1),
            Return_Odometer__c = 1200, Daily_Rate__c = 1800, Free_Km_Per_Day__c = 250,
            Extra_Km_Rate__c = 10);
        BookingTriggerHandler.beforeUpdate(new List<Booking__c>{returned},
            new Map<Id, Booking__c>{bookingId => returnOld});
        System.assertEquals(false, returned.hasErrors());
    }
}