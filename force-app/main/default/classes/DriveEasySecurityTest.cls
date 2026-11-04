/**
 * BRD section 10 (Security & Access) checked with real users:
 * a Rental Desk Agent (DriveEasy_Desk_Agent), a Branch Manager (Desk Agent + Manager Addon)
 * and a user with no DriveEasy permission set. The controllers run in user mode, so these
 * tests also prove that object and field access is enforced in Apex.
 */
@IsTest
private class DriveEasySecurityTest {
    private static final Integer YEAR = 2030;
    private static final String CAR_REG = 'TN37SEC001';

    private static Datetime ist(Integer month, Integer day, Integer hour) {
        return DriveEasyTime.ist(Date.newInstance(YEAR, month, day), hour, 0);
    }
    private static Datetime pickup() { return ist(10, 25, 10); }
    private static Datetime returnDt() { return ist(10, 27, 10); }

    @TestSetup
    static void setup() {
        insert new Car__c(Name = CAR_REG, Make__c = 'Maruti', Model__c = 'Swift', Category__c = 'Hatchback',
            Daily_Rate__c = 1800, Free_KM_Per_Day__c = 250, Extra_KM_Rate__c = 10,
            Current_Odometer__c = 12000, Status__c = 'Available');
        // Customers sit under a shared account, as in the sample data; a contact without an account is private to its owner
        Account acc = new Account(Name = 'DriveEasy Customers');
        insert acc;
        insert new Contact(AccountId = acc.Id, FirstName = 'Priya', LastName = 'Security', Phone = '9876511111',
            Email = 'priya.security@example.com', Licence_Number__c = 'SEC-LIC-0001',
            Date_of_Birth__c = Date.newInstance(1995, 5, 10), Licence_Expiry_Date__c = Date.newInstance(2035, 1, 1));
        System.runAs(new User(Id = UserInfo.getUserId())) {
            makeUser('secagt', new List<String>{ 'DriveEasy_Desk_Agent' });
            makeUser('secmgr', new List<String>{ 'DriveEasy_Desk_Agent', 'DriveEasy_Manager_Addon' });
            makeUser('secnone', new List<String>());
        }
    }

    private static void makeUser(String alias, List<String> permissionSetNames) {
        Profile p = [SELECT Id FROM Profile WHERE Name IN ('Minimum Access - Salesforce', 'Standard User')
                     ORDER BY Name LIMIT 1];
        String unique = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User u = new User(Alias = alias, LastName = alias, Email = alias + '@driveeasy.test',
            Username = alias + '.' + unique + '@driveeasy.test', ProfileId = p.Id,
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_IN',
            TimeZoneSidKey = 'Asia/Kolkata');
        insert u;
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        for (PermissionSet ps : [SELECT Id FROM PermissionSet WHERE Name IN :permissionSetNames]) {
            assignments.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id));
        }
        insert assignments;
    }

    private static User user(String alias) { return [SELECT Id FROM User WHERE Alias = :alias LIMIT 1]; }
    private static Id carId() { return [SELECT Id FROM Car__c WHERE Name = :CAR_REG].Id; }
    private static Id customerId() { return [SELECT Id FROM Contact WHERE Licence_Number__c = 'SEC-LIC-0001'].Id; }
    private static void setNow() { DriveEasyTime.nowOverride = ist(10, 20, 6); }

    private static Id insertBooking() {
        Booking__c b = new Booking__c(Car__c = carId(), Customer__c = customerId(),
            Pickup_Date_Time__c = pickup(), Return_Date_Time__c = returnDt(),
            Status__c = 'Reserved', Skip_Confirmation_Email__c = true);
        insert b;
        return b.Id;
    }

    // "Create bookings, record pickups and returns: agent Yes" through the same controllers the screens use
    @IsTest static void deskAgentRunsTheWholeBookingInUserMode() {
        setNow();
        Id car = carId();
        Id customer = customerId();
        System.runAs(user('secagt')) {
            Boolean found = false;
            for (CarSearchController.CarResult r : CarSearchController.searchCars('Hatchback', pickup(), returnDt())) {
                if (r.carId == car) { found = true; }
            }
            Assert.isTrue(found, 'The agent must see the free car in the search');

            String name = BookingController.createBooking(car, customer, pickup(), returnDt());
            Booking__c b = [SELECT Id FROM Booking__c WHERE Name = :name];

            Booking__c pickupUpdate = new Booking__c(Id = b.Id, Status__c = 'Picked Up', Pickup_Odometer__c = 12000);
            update as user pickupUpdate;

            BillingService.Bill preview = ReturnController.previewBill(b.Id, ist(10, 27, 13), 12620);
            Assert.areEqual(6088.80, preview.total);
            ReturnController.confirmReturn(b.Id, ist(10, 27, 13), 12620);

            Booking__c saved = [SELECT Status__c, Total__c FROM Booking__c WHERE Id = :b.Id];
            Assert.areEqual('Returned', saved.Status__c);
            Assert.areEqual(6088.80, saved.Total__c);
        }
    }

    // "Create and edit customers: Yes" for both roles
    @IsTest static void bothRolesCreateAndEditCustomers() {
        for (String alias : new List<String>{ 'secagt', 'secmgr' }) {
            System.runAs(user(alias)) {
                Contact c = new Contact(FirstName = 'New', LastName = 'Customer ' + alias, Phone = '9876522222',
                    Email = alias + '@example.com', Licence_Number__c = 'SEC-' + alias,
                    Date_of_Birth__c = Date.newInstance(1990, 1, 1), Licence_Expiry_Date__c = Date.newInstance(2035, 1, 1));
                insert as user c;
                c.Phone = '9876533333';
                update as user c;
                Assert.areEqual('9876533333', [SELECT Phone FROM Contact WHERE Id = :c.Id].Phone);
            }
        }
    }

    // "View cars: Yes" for both; "Create and edit cars and rates: manager only"
    @IsTest static void onlyManagerCreatesAndEditsCars() {
        System.runAs(user('secagt')) {
            Assert.isTrue(Schema.sObjectType.Car__c.isAccessible(), 'Agent must view cars');
            Assert.isFalse(Schema.sObjectType.Car__c.isCreateable(), 'Agent must not create cars');
            Assert.isFalse(Schema.sObjectType.Car__c.isUpdateable(), 'Agent must not edit cars');
            Car__c newCar = new Car__c(Name = 'TN37SEC999', Make__c = 'Tata', Model__c = 'Tiago',
                Category__c = 'Hatchback', Daily_Rate__c = 1800, Free_KM_Per_Day__c = 250,
                Extra_KM_Rate__c = 10, Current_Odometer__c = 100, Status__c = 'Available');
            Database.SaveResult sr = Database.insert(newCar, false, AccessLevel.USER_MODE);
            Assert.isFalse(sr.isSuccess(), 'Agent car insert must be refused');
        }
        System.runAs(user('secmgr')) {
            Assert.isTrue(Schema.sObjectType.Car__c.isCreateable(), 'Manager must create cars');
            Assert.isTrue(Schema.sObjectType.Car__c.isUpdateable(), 'Manager must edit cars');
            Car__c newCar = new Car__c(Name = 'TN37SEC998', Make__c = 'Tata', Model__c = 'Tiago',
                Category__c = 'Hatchback', Daily_Rate__c = 1800, Free_KM_Per_Day__c = 250,
                Extra_KM_Rate__c = 10, Current_Odometer__c = 100, Status__c = 'Available');
            insert as user newCar;
            newCar.Daily_Rate__c = 1900;
            update as user newCar;
        }
        Assert.areEqual(1900, [SELECT Daily_Rate__c FROM Car__c WHERE Name = 'TN37SEC998'].Daily_Rate__c);
    }

    // "Cancel bookings: manager only" is a custom permission; "View reports and dashboard: manager only"
    @IsTest static void cancelAndReportsAreManagerOnly() {
        User agent = user('secagt');
        User manager = user('secmgr');
        System.runAs(agent) {
            Assert.isFalse(FeatureManagement.checkPermission('Can_Cancel_Booking'), 'Agent must not cancel');
        }
        System.runAs(manager) {
            Assert.isTrue(FeatureManagement.checkPermission('Can_Cancel_Booking'), 'Manager must cancel');
        }
        Assert.areEqual(0, [SELECT COUNT() FROM PermissionSetAssignment
                            WHERE AssigneeId = :agent.Id AND PermissionSet.PermissionsRunReports = true],
            'Agent must not run reports');
        Assert.isTrue([SELECT COUNT() FROM PermissionSetAssignment
                       WHERE AssigneeId = :manager.Id AND PermissionSet.PermissionsRunReports = true] > 0,
            'Manager must run reports');
    }

    // "Delete bookings: No" for every role
    @IsTest static void nobodyDeletesBookings() {
        setNow();
        Id bookingId = insertBooking();
        for (String alias : new List<String>{ 'secagt', 'secmgr' }) {
            System.runAs(user(alias)) {
                Assert.isFalse(Schema.sObjectType.Booking__c.isDeletable(), alias + ' must not delete bookings');
            }
        }
        // Even an administrator is stopped by the trigger
        Database.DeleteResult dr = Database.delete(bookingId, false);
        Assert.isFalse(dr.isSuccess());
        Assert.isTrue(dr.getErrors()[0].getMessage().contains('cannot be deleted'), dr.getErrors()[0].getMessage());
    }

    // "Edit bill amounts: No" for every role; bill fields are read only
    @IsTest static void billAmountsAreReadOnlyForEveryRole() {
        setNow();
        Id bookingId = insertBooking();
        List<Schema.SObjectField> billFields = new List<Schema.SObjectField>{
            Booking__c.Rent__c, Booking__c.Extra_Km_Charge__c, Booking__c.Late_Fee__c, Booking__c.GST__c,
            Booking__c.Total__c, Booking__c.Estimated_Rent__c, Booking__c.Daily_Rate__c, Booking__c.Rental_Days__c
        };
        for (String alias : new List<String>{ 'secagt', 'secmgr' }) {
            System.runAs(user(alias)) {
                for (Schema.SObjectField field : billFields) {
                    // Describe inside runAs so the field access is that user's
                    Schema.DescribeFieldResult f = field.getDescribe();
                    Assert.isTrue(f.isAccessible(), alias + ' must see ' + f.getName());
                    Assert.isFalse(f.isUpdateable(), alias + ' must not edit ' + f.getName());
                }
                Database.SaveResult sr = Database.update(new Booking__c(Id = bookingId, Total__c = 1), false,
                    AccessLevel.USER_MODE);
                Assert.isFalse(sr.isSuccess(), alias + ' must not change the total');
            }
        }
    }

    // A user without a DriveEasy permission set is refused by every screen controller (user mode works)
    @IsTest static void userWithoutAccessIsRefused() {
        setNow();
        Id bookingId = insertBooking();
        Id car = carId();
        Id customer = customerId();
        System.runAs(user('secnone')) {
            Boolean searchRefused = false;
            try {
                CarSearchController.searchCars('Hatchback', ist(11, 5, 10), ist(11, 6, 10));
            } catch (Exception e) {
                searchRefused = true;
            }
            Assert.isTrue(searchRefused, 'Search must be refused');

            Boolean bookRefused = false;
            try {
                BookingController.createBooking(car, customer, ist(11, 5, 10), ist(11, 6, 10));
            } catch (Exception e) {
                bookRefused = true;
            }
            Assert.isTrue(bookRefused, 'Booking must be refused');

            Boolean returnRefused = false;
            try {
                ReturnController.confirmReturn(bookingId, ist(10, 27, 13), 12620);
            } catch (Exception e) {
                returnRefused = true;
            }
            Assert.isTrue(returnRefused, 'Return must be refused');

            Boolean fleetRefused = false;
            try {
                FleetBoardController.getFleet();
            } catch (Exception e) {
                fleetRefused = true;
            }
            Assert.isTrue(fleetRefused, 'Fleet board must be refused');
        }
        Assert.areEqual(1, [SELECT COUNT() FROM Booking__c], 'No booking may be created');
        Assert.areEqual('Reserved', [SELECT Status__c FROM Booking__c WHERE Id = :bookingId].Status__c);
    }

    // The sample data loader deletes data and switches the rules off, so only an administrator may run it
    @IsTest static void sampleDataLoaderIsAdminOnly() {
        System.runAs(user('secagt')) {
            try {
                SampleDataLoader.run();
                Assert.fail('A desk agent must not load sample data');
            } catch (SampleDataLoader.SampleDataException e) {
                Assert.isTrue(e.getMessage().contains('System Administrator'), e.getMessage());
            }
        }
        Assert.areEqual(1, [SELECT COUNT() FROM Car__c], 'Nothing may be deleted');
    }
}