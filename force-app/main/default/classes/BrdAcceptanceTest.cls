/**
 * One test per acceptance scenario in BRD section 14 (AT-01 to AT-18).
 * Every test goes through real DML, the controllers or the flows, with the rules switched on.
 * Base booking (BRD section 14): Hatchback, 25 Oct 10:00 to 27 Oct 10:00 IST (48 hours),
 * picked up with the odometer at 12,000 km. The year is 2030 so the dates stay in the future.
 */
@IsTest
private class BrdAcceptanceTest {
    private static final Integer YEAR = 2030;

    private static Datetime ist(Integer month, Integer day, Integer hour, Integer minute) {
        return DriveEasyTime.ist(Date.newInstance(YEAR, month, day), hour, minute);
    }
    private static Datetime basePickup() { return ist(10, 25, 10, 0); }
    private static Datetime baseReturn() { return ist(10, 27, 10, 0); }

    @TestSetup
    static void setup() {
        insert new List<Car__c>{
            new Car__c(Name = 'TN37AT0001', Make__c = 'Maruti', Model__c = 'Swift', Category__c = 'Hatchback',
                Daily_Rate__c = 1800, Free_KM_Per_Day__c = 250, Extra_KM_Rate__c = 10,
                Current_Odometer__c = 12000, Status__c = 'Available'),
            new Car__c(Name = 'TN37AT0002', Make__c = 'Hyundai', Model__c = 'i20', Category__c = 'Hatchback',
                Daily_Rate__c = 1800, Free_KM_Per_Day__c = 250, Extra_KM_Rate__c = 10,
                Current_Odometer__c = 15000, Status__c = 'Available'),
            new Car__c(Name = 'TN37AT0003', Make__c = 'Honda', Model__c = 'City', Category__c = 'Sedan',
                Daily_Rate__c = 2500, Free_KM_Per_Day__c = 250, Extra_KM_Rate__c = 12,
                Current_Odometer__c = 20000, Status__c = 'Under_Maintenance')
        };
        Account acc = new Account(Name = 'DriveEasy Test Customers');
        insert acc;
        insert new List<Contact>{
            new Contact(AccountId = acc.Id, FirstName = 'Priya', LastName = 'Nair', Phone = '9876500001',
                Email = 'priya@example.com', Licence_Number__c = 'AT-LIC-0001',
                Date_of_Birth__c = Date.newInstance(1995, 5, 10), Licence_Expiry_Date__c = Date.newInstance(2035, 1, 1)),
            new Contact(AccountId = acc.Id, FirstName = 'Karthik', LastName = 'Raja', Phone = '9876500002',
                Email = 'karthik@example.com', Licence_Number__c = 'AT-LIC-0002',
                Date_of_Birth__c = Date.newInstance(2010, 3, 1), // 20 years old on 25 Oct 2030
                Licence_Expiry_Date__c = Date.newInstance(2035, 1, 1)),
            new Contact(AccountId = acc.Id, FirstName = 'Anil', LastName = 'Kumar', Phone = '9876500003',
                Email = 'anil@example.com', Licence_Number__c = 'AT-LIC-0003',
                Date_of_Birth__c = Date.newInstance(2006, 1, 15),
                Licence_Expiry_Date__c = Date.newInstance(2030, 10, 26)) // expires mid-trip
        };
    }

    // ---------- helpers ----------
    private static void setNow() { DriveEasyTime.nowOverride = ist(10, 20, 6, 0); }
    private static Id carId(String reg) { return [SELECT Id FROM Car__c WHERE Name = :reg].Id; }
    private static Id customerId(String firstName) { return [SELECT Id FROM Contact WHERE FirstName = :firstName].Id; }
    private static Id hatchback() { return carId('TN37AT0001'); }
    private static Id priya() { return customerId('Priya'); }

    private static Booking__c newBooking(Id car, Id customer, Datetime pickup, Datetime returnDt) {
        return new Booking__c(Car__c = car, Customer__c = customer, Pickup_Date_Time__c = pickup,
            Return_Date_Time__c = returnDt, Status__c = 'Reserved', Skip_Confirmation_Email__c = true);
    }
    private static Id insertBase() {
        Booking__c b = newBooking(hatchback(), priya(), basePickup(), baseReturn());
        insert b;
        return b.Id;
    }
    private static Id pickedUpBase() {
        Id bookingId = insertBase();
        update new Booking__c(Id = bookingId, Status__c = 'Picked Up', Pickup_Odometer__c = 12000);
        return bookingId;
    }
    private static String firstError(Database.SaveResult sr) {
        return sr.isSuccess() ? '' : sr.getErrors()[0].getMessage();
    }
    private static void assertMoney(Decimal expected, Decimal actual, String label) {
        Assert.isNotNull(actual, label + ' is blank');
        Assert.isTrue(actual.setScale(2) == expected.setScale(2), label + ': expected ' + expected + ' but was ' + actual);
    }
    private static Booking__c load(Id bookingId) {
        return [SELECT Name, Status__c, Rental_Days__c, Estimated_Rent__c, Rent__c, Extra_Km_Charge__c,
                       Late_Fee__c, GST__c, Total__c
                FROM Booking__c WHERE Id = :bookingId];
    }
    private static User makeUser(String alias, List<String> permissionSetNames) {
        Profile p = [SELECT Id FROM Profile WHERE Name IN ('Minimum Access - Salesforce', 'Standard User')
                     ORDER BY Name LIMIT 1];
        String unique = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User u = new User(Alias = alias, LastName = alias, Email = alias + '@driveeasy.test',
            Username = alias + '.' + unique + '@driveeasy.test', ProfileId = p.Id,
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_IN',
            TimeZoneSidKey = 'Asia/Kolkata');
        if (permissionSetNames.contains('DriveEasy_Manager_Addon')) {
            u.UserRoleId = [SELECT Id FROM UserRole WHERE DeveloperName = 'Branch_Manager' LIMIT 1].Id;
        }
        insert u;
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        for (PermissionSet ps : [SELECT Id FROM PermissionSet WHERE Name IN :permissionSetNames]) {
            assignments.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id));
        }
        insert assignments;
        return u;
    }

    // ---------- AT-01 to AT-18 ----------

    @IsTest static void at01_createBaseBookingFromSearchResults() {
        setNow();
        // FR-05: the search shows the car with 2 rental days and an estimate of 3,600
        CarSearchController.CarResult found;
        for (CarSearchController.CarResult r : CarSearchController.searchCars('Hatchback', basePickup(), baseReturn())) {
            if (r.carId == hatchback()) { found = r; }
        }
        Assert.isNotNull(found, 'The free Hatchback must appear in the search');
        Assert.areEqual(2, found.rentalDays);
        assertMoney(3600, found.estimatedRent, 'Search estimate');
        Test.startTest();
        String bookingName = BookingController.createBooking(hatchback(), priya(), basePickup(), baseReturn());
        Test.stopTest();
        Booking__c b = [SELECT Status__c, Rental_Days__c, Estimated_Rent__c FROM Booking__c WHERE Name = :bookingName];
        Assert.areEqual('Reserved', b.Status__c);
        Assert.areEqual(2, b.Rental_Days__c.intValue());
        assertMoney(3600, b.Estimated_Rent__c, 'Estimated rent');
    }

    @IsTest static void at02_overlappingBookingIsRejected() {
        setNow();
        Id baseId = insertBase();
        String baseName = load(baseId).Name;
        Database.SaveResult sr = Database.insert(
            newBooking(hatchback(), priya(), ist(10, 26, 9, 0), ist(10, 28, 9, 0)), false);
        Assert.isFalse(sr.isSuccess());
        Assert.isTrue(firstError(sr).contains('overlaps ' + baseName), firstError(sr));
    }

    @IsTest static void at03_turnaroundBufferBlocksTheNextHour() {
        setNow();
        insertBase();
        Database.SaveResult atReturnTime = Database.insert(
            newBooking(hatchback(), priya(), ist(10, 27, 10, 0), ist(10, 28, 10, 0)), false);
        Assert.isFalse(atReturnTime.isSuccess(), '10:00 AM must be rejected (inside the 1-hour buffer)');
        Database.SaveResult afterBuffer = Database.insert(
            newBooking(hatchback(), priya(), ist(10, 27, 11, 0), ist(10, 28, 11, 0)), false);
        Assert.isTrue(afterBuffer.isSuccess(), '11:00 AM must be accepted: ' + firstError(afterBuffer));
    }

    @IsTest static void at04_underMaintenanceCarIsHiddenAndCannotBeBooked() {
        setNow();
        Id sedan = carId('TN37AT0003');
        for (CarSearchController.CarResult r : CarSearchController.searchCars('Sedan', basePickup(), baseReturn())) {
            Assert.areNotEqual(sedan, r.carId, 'Under Maintenance car must not appear in search');
        }
        Database.SaveResult sr = Database.insert(newBooking(sedan, priya(), basePickup(), baseReturn()), false);
        Assert.isFalse(sr.isSuccess());
        Assert.isTrue(firstError(sr).contains('Under Maintenance'), firstError(sr));
    }

    @IsTest static void at05_driverAged20IsRejected() {
        setNow();
        Database.SaveResult sr = Database.insert(
            newBooking(hatchback(), customerId('Karthik'), basePickup(), baseReturn()), false);
        Assert.isFalse(sr.isSuccess());
        Assert.isTrue(firstError(sr).contains('at least 21'), firstError(sr));
    }

    @IsTest static void at06_licenceExpiringBeforeReturnIsRejected() {
        setNow();
        Database.SaveResult sr = Database.insert(
            newBooking(hatchback(), customerId('Anil'), basePickup(), baseReturn()), false);
        Assert.isFalse(sr.isSuccess());
        Assert.isTrue(firstError(sr).contains('licence expires'), firstError(sr));
    }

    @IsTest static void at07_pickupTooSoonOrOutsideBranchHoursIsRejected() {
        DriveEasyTime.nowOverride = ist(10, 25, 8, 0);
        Database.SaveResult tooSoon = Database.insert(
            newBooking(hatchback(), priya(), ist(10, 25, 9, 0), ist(10, 26, 10, 0)), false);
        Assert.isFalse(tooSoon.isSuccess());
        Assert.isTrue(firstError(tooSoon).contains('at least 2 hours'), firstError(tooSoon));
        Database.SaveResult tenPm = Database.insert(
            newBooking(hatchback(), priya(), ist(10, 26, 22, 0), ist(10, 27, 10, 0)), false);
        Assert.isFalse(tenPm.isSuccess());
        Assert.isTrue(firstError(tenPm).contains('between 8:00 AM and 9:00 PM'), firstError(tenPm));
    }

    @IsTest static void at08_pickupMarksBookingPickedUpAndCarOnRent() {
        setNow();
        Id bookingId = pickedUpBase();
        Assert.areEqual('Picked Up', load(bookingId).Status__c);
        Car__c car = [SELECT Status__c FROM Car__c WHERE Id = :hatchback()];
        Assert.areEqual('On_Rent', car.Status__c);
    }

    @IsTest static void at09_lateReturnWithExtraKmMatchesWorkedExample() {
        setNow();
        Id bookingId = pickedUpBase();
        Test.startTest();
        BillingService.Bill preview = ReturnController.previewBill(bookingId, ist(10, 27, 13, 0), 12620);
        ReturnController.confirmReturn(bookingId, ist(10, 27, 13, 0), 12620);
        Test.stopTest();
        Booking__c b = load(bookingId);
        Assert.areEqual('Returned', b.Status__c);
        assertMoney(3600, b.Rent__c, 'Rent');
        assertMoney(1200, b.Extra_Km_Charge__c, 'Extra km');
        assertMoney(360, b.Late_Fee__c, 'Late fee');
        assertMoney(928.80, b.GST__c, 'GST');
        assertMoney(6088.80, b.Total__c, 'Total');
        assertMoney(b.Total__c, preview.total, 'Preview total must equal saved total');
    }

    @IsTest static void at10_returnInsideGraceAndFreeKm() {
        setNow();
        Id bookingId = pickedUpBase();
        ReturnController.confirmReturn(bookingId, ist(10, 27, 10, 30), 12450);
        Booking__c b = load(bookingId);
        assertMoney(0, b.Extra_Km_Charge__c, 'Extra km');
        assertMoney(0, b.Late_Fee__c, 'Late fee');
        assertMoney(648, b.GST__c, 'GST');
        assertMoney(4248, b.Total__c, 'Total');
    }

    @IsTest static void at11_returnOdometerBelowPickupIsRejected() {
        setNow();
        Id bookingId = pickedUpBase();
        try {
            ReturnController.confirmReturn(bookingId, ist(10, 27, 13, 0), 11900);
            Assert.fail('A return odometer below the pickup reading must be rejected');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('cannot be lower'), e.getMessage());
        }
        Assert.areEqual('Picked Up', load(bookingId).Status__c);
    }

    @IsTest static void at12_returnMakesCarAvailableWithNewOdometer() {
        setNow();
        Id bookingId = pickedUpBase();
        ReturnController.confirmReturn(bookingId, ist(10, 27, 13, 0), 12620);
        Car__c car = [SELECT Status__c, Current_Odometer__c FROM Car__c WHERE Id = :hatchback()];
        Assert.areEqual('Available', car.Status__c);
        Assert.areEqual(12620, car.Current_Odometer__c.intValue());
    }

    @IsTest static void at13_returnedBookingCannotGoBackToReserved() {
        setNow();
        Id bookingId = pickedUpBase();
        ReturnController.confirmReturn(bookingId, ist(10, 27, 13, 0), 12620);
        try {
            update new Booking__c(Id = bookingId, Status__c = 'Reserved');
            Assert.fail('Returned to Reserved must be rejected');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('cannot be changed'), e.getMessage());
        }
    }

    @IsTest static void at14_deskAgentCannotChangeRatesButManagerCan() {
        User agent;
        User manager;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            agent = makeUser('deagent', new List<String>{ 'DriveEasy_Desk_Agent' });
            manager = makeUser('demgr', new List<String>{ 'DriveEasy_Desk_Agent', 'DriveEasy_Manager_Addon' });
        }
        Id car = hatchback();
        System.runAs(agent) {
            Assert.isFalse(Schema.sObjectType.Car__c.isUpdateable(), 'Desk agent must not be able to edit cars');
            Boolean blocked = false;
            Car__c agentChange = new Car__c(Id = car, Daily_Rate__c = 2000);
            try {
                update as user agentChange;
            } catch (Exception e) {
                blocked = true;
            }
            Assert.isTrue(blocked, 'Desk agent rate change must be refused');
        }
        System.runAs(manager) {
            Assert.isTrue(Schema.sObjectType.Car__c.isUpdateable(), 'Branch Manager must be able to edit cars');
            Car__c adminCar = [SELECT Id, Daily_Rate__c FROM Car__c WHERE Id = :car];
            adminCar.Daily_Rate__c = 2000;
            update as user adminCar;
        }
        assertMoney(2000, [SELECT Daily_Rate__c FROM Car__c WHERE Id = :car].Daily_Rate__c, 'New daily rate');
    }

    @IsTest static void at15_rateChangeDoesNotAlterAPastBill() {
        setNow();
        Id bookingId = pickedUpBase();
        ReturnController.confirmReturn(bookingId, ist(10, 27, 13, 0), 12620);
        update new Car__c(Id = hatchback(), Daily_Rate__c = 2000);
        assertMoney(6088.80, load(bookingId).Total__c, 'Old bill after rate change');

        Booking__c later = newBooking(hatchback(), priya(), ist(11, 1, 10, 0), ist(11, 3, 10, 0));
        insert later;
        assertMoney(4000, load(later.Id).Estimated_Rent__c, 'New booking uses the new rate');
    }

    @IsTest static void at16_bulkImportOf200With10Overlaps() {
        setNow();
        Id car = hatchback();
        Id customer = priya();
        Date firstDay = Date.newInstance(YEAR, 11, 1);
        List<Booking__c> rows = new List<Booking__c>();
        for (Integer i = 0; i < 190; i++) {
            Date d = firstDay.addDays(i);
            rows.add(newBooking(car, customer, DriveEasyTime.ist(d, 10, 0), DriveEasyTime.ist(d, 20, 0)));
        }
        for (Integer i = 0; i < 10; i++) { // the same days again: each clashes with a row earlier in the import
            Date d = firstDay.addDays(i);
            rows.add(newBooking(car, customer, DriveEasyTime.ist(d, 12, 0), DriveEasyTime.ist(d, 18, 0)));
        }
        Test.startTest();
        List<Database.SaveResult> results = Database.insert(rows, false);
        Test.stopTest();
        Integer saved = 0;
        Integer rejected = 0;
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                saved++;
            } else {
                rejected++;
                Assert.isTrue(firstError(sr).contains('overlaps'), firstError(sr));
            }
        }
        Assert.areEqual(190, saved);
        Assert.areEqual(10, rejected);
        Assert.areEqual(190, [SELECT COUNT() FROM Booking__c WHERE Car__c = :car]);
    }

    @IsTest static void at17_onlyManagerCancelsAndAReasonIsRequired() {
        setNow();
        Id bookingId = insertBase();
        User agent;
        User manager;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            agent = makeUser('deagt2', new List<String>{ 'DriveEasy_Desk_Agent' });
            manager = makeUser('demgr2', new List<String>{ 'DriveEasy_Desk_Agent', 'DriveEasy_Manager_Addon' });
        }
        System.runAs(agent) {
            try {
                update new Booking__c(Id = bookingId, Status__c = 'Cancelled', Cancellation_Reason__c = 'plans changed');
                Assert.fail('A desk agent must not cancel');
            } catch (DmlException e) {
                Assert.isTrue(e.getMessage().contains('Only the Branch Manager'), e.getMessage());
            }
        }
        System.runAs(manager) {
            try {
                update new Booking__c(Id = bookingId, Status__c = 'Cancelled');
                Assert.fail('Cancelling without a reason must be rejected');
            } catch (DmlException e) {
                Assert.isTrue(e.getMessage().contains('cancellation reason'), e.getMessage());
            }
            update new Booking__c(Id = bookingId, Status__c = 'Cancelled', Cancellation_Reason__c = 'plans changed');
        }
        Assert.areEqual('Cancelled', load(bookingId).Status__c);
    }

    @IsTest static void at18_confirmationEmailIsQueuedAndSent() {
        setNow();
        Booking__c b = newBooking(hatchback(), priya(), basePickup(), baseReturn());
        b.Skip_Confirmation_Email__c = false;
        Test.startTest();
        insert b;
        Test.stopTest();
        List<AsyncApexJob> jobs = [SELECT Status, NumberOfErrors FROM AsyncApexJob
                                   WHERE ApexClass.Name = 'BookingNotificationQueueable'];
        Assert.areEqual(1, jobs.size(), 'One confirmation job must be queued');
        Assert.areEqual('Completed', jobs[0].Status);
        Assert.areEqual(0, jobs[0].NumberOfErrors);

        // FR-15: one email to the customer with the car, dates and estimated rent
        Assert.isNull(BookingNotificationQueueable.lastError, 'Email sending failed: ' + BookingNotificationQueueable.lastError);
        Assert.areEqual(1, BookingNotificationQueueable.sentEmails.size(), 'One confirmation email must be sent');
        Messaging.SingleEmailMessage mail = BookingNotificationQueueable.sentEmails[0];
        String bookingName = load(b.Id).Name;
        Assert.areEqual(new List<String>{ 'priya@example.com' }, mail.getToAddresses());
        Assert.isTrue(mail.getSubject().contains(bookingName), mail.getSubject());
        String body = mail.getHtmlBody();
        Assert.isTrue(body.contains('Maruti Swift (TN37AT0001)'), 'Car missing: ' + body);
        Assert.isTrue(body.contains(DriveEasyTime.display(basePickup())), 'Pickup missing: ' + body);
        Assert.isTrue(body.contains(DriveEasyTime.display(baseReturn())), 'Return missing: ' + body);
        Assert.isTrue(body.contains('3600'), 'Estimated rent missing: ' + body);
    }

    // FR-15: a booking marked to skip the email (sample data) sends nothing
    @IsTest static void at18_skipFlagSendsNoEmail() {
        setNow();
        Test.startTest();
        insertBase();
        Test.stopTest();
        Assert.areEqual(0, [SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = 'BookingNotificationQueueable']);
    }

    // BRD section 10: bill amounts cannot be typed or changed by any user
    @IsTest static void billAmountsCannotBeEditedByUsers() {
        setNow();
        Id bookingId = insertBase();
        Database.SaveResult sr = Database.update(new Booking__c(Id = bookingId, Estimated_Rent__c = 1), false);
        Assert.isFalse(sr.isSuccess());
        Assert.isTrue(firstError(sr).contains('calculated by the system'), firstError(sr));
        sr = Database.update(new Booking__c(Id = bookingId, Daily_Rate__c = 1), false);
        Assert.isFalse(sr.isSuccess(), 'Copied daily rate must not be editable');
    }

    // FR-02 / BRD section 9: licence number is unique
    @IsTest static void duplicateLicenceNumberIsRejected() {
        Contact dup = new Contact(LastName = 'Duplicate', Phone = '9876500009', Licence_Number__c = 'AT-LIC-0001',
            Date_of_Birth__c = Date.newInstance(1990, 1, 1), Licence_Expiry_Date__c = Date.newInstance(2035, 1, 1));
        Database.SaveResult sr = Database.insert(dup, false);
        Assert.isFalse(sr.isSuccess(), 'A second customer with the same licence number must be rejected');
    }
}