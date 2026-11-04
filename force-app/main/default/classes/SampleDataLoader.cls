public with sharing class SampleDataLoader {
    
    // Helper to generate IST Datetime at a given day offset and hour
    private static Datetime ist(Integer dayOffset, Integer hour) {
        return DriveEasyTime.ist(Date.today().addDays(dayOffset), hour, 0);
    }
    
    // Helper to build a base Booking__c record
    private static Booking__c mk(Car__c car, Contact cust, Integer startDay, Integer days, String status) {
        Datetime p = ist(startDay, 10);
        Datetime r = ist(startDay + days, 10);
        Booking__c b = new Booking__c(
            Car__c = car.Id, 
            Customer__c = cust.Id, 
            Status__c = status,
            Pickup_Date_Time__c = p, 
            Return_Date_Time__c = r, 
            Skip_Confirmation_Email__c = true,
            Daily_Rate__c = car.Daily_Rate__c, 
            Free_Km_Per_Day__c = car.Free_KM_Per_Day__c,
            Extra_Km_Rate__c = car.Extra_KM_Rate__c, 
            Car_Category__c = car.Category__c
        );
        b.Rental_Days__c = BillingService.rentalDays(p, r);
        b.Estimated_Rent__c = BillingService.money(car.Daily_Rate__c * b.Rental_Days__c);
        return b;
    }
    
    // Helper to build a Returned Booking__c record with full bill calculation
    private static Booking__c mkReturned(Car__c car, Contact cust, Integer startDay, Integer days, Integer lateHours, Integer km, Map<Id, Decimal> odo) {
        Booking__c b = mk(car, cust, startDay, days, 'Returned');
        b.Pickup_Odometer__c = odo.get(car.Id);
        b.Return_Odometer__c = odo.get(car.Id) + km;
        b.Actual_Return_Time__c = b.Return_Date_Time__c.addHours(lateHours);
        
        BillingService.Bill bill = BillingService.calculate(
            b.Daily_Rate__c, b.Free_Km_Per_Day__c, b.Extra_Km_Rate__c,
            b.Pickup_Date_Time__c, b.Return_Date_Time__c, b.Actual_Return_Time__c,
            b.Pickup_Odometer__c, b.Return_Odometer__c
        );
        
        b.Rent__c = bill.rent; 
        b.Extra_Km_Charge__c = bill.extraKmCharge; 
        b.Late_Fee__c = bill.lateFee;
        b.GST__c = bill.gst; 
        b.Total__c = bill.total;
        
        odo.put(car.Id, b.Return_Odometer__c);
        return b;
    }
    
    public class SampleDataException extends Exception {}

    // True when the running user has Modify All Data (from the profile or a permission set).
    // Users without setup access cannot even query this, which also means they are not administrators.
    private static Boolean isAdmin() {
        try {
            return ![SELECT Id FROM PermissionSetAssignment
                     WHERE AssigneeId = :UserInfo.getUserId()
                     AND PermissionSet.PermissionsModifyAllData = true LIMIT 1].isEmpty();
        } catch (QueryException e) {
            return false;
        }
    }

    public static void run() {
        // It deletes all bookings and cars and switches the booking rules off, so only an administrator may run it
        if (!isAdmin()) {
            throw new SampleDataException('Only a System Administrator can load the sample data.');
        }
        BookingTriggerHandler.bypassRules = true; // Bypass validation rules for historical sample data
        
        // 1. Clean up existing sample records
        delete [SELECT Id FROM Booking__c];
        delete [SELECT Id FROM Contact WHERE Licence_Number__c != null];
        delete [SELECT Id FROM Car__c];
        
        // 2. Ensure a shared Account exists so Contacts are not marked "Private"
        List<Account> existingAcc = [SELECT Id FROM Account WHERE Name = 'DriveEasy Customers' LIMIT 1];
        Account sharedAcc;
        if (existingAcc.isEmpty()) {
            sharedAcc = new Account(Name = 'DriveEasy Customers');
            insert sharedAcc;
        } else {
            sharedAcc = existingAcc[0];
        }
        
        // 3. Create 10 Cars across 3 categories (1 Under Maintenance)
        List<List<String>> carRows = new List<List<String>>{
            new List<String>{'TN37AB1001', 'Maruti', 'Swift', 'Hatchback'},
            new List<String>{'TN37AB1002', 'Hyundai', 'i20', 'Hatchback'},
            new List<String>{'TN37AB1003', 'Tata', 'Tiago', 'Hatchback'},
            new List<String>{'TN37AB1004', 'Maruti', 'Baleno', 'Hatchback'},
            new List<String>{'TN37AB2001', 'Honda', 'City', 'Sedan'},
            new List<String>{'TN37AB2002', 'Hyundai', 'Verna', 'Sedan'},
            new List<String>{'TN37AB2003', 'Maruti', 'Ciaz', 'Sedan'},
            new List<String>{'TN37AB3001', 'Hyundai', 'Creta', 'SUV'},
            new List<String>{'TN37AB3002', 'Mahindra', 'XUV700', 'SUV'},
            new List<String>{'TN37AB3003', 'Tata', 'Harrier', 'SUV'}
        };
        
        Map<String, List<Decimal>> rates = new Map<String, List<Decimal>>{
            'Hatchback' => new List<Decimal>{1800, 250, 10},
            'Sedan'     => new List<Decimal>{2500, 250, 12},
            'SUV'       => new List<Decimal>{3500, 300, 15}
        };
        
        List<Car__c> cars = new List<Car__c>();
        for (Integer i = 0; i < carRows.size(); i++) {
            List<String> r = carRows[i];
            List<Decimal> rt = rates.get(r[3]);
            cars.add(new Car__c(
                Name = r[0], 
                Make__c = r[1], 
                Model__c = r[2], 
                Category__c = r[3],
                Daily_Rate__c = rt[0], 
                Free_KM_Per_Day__c = rt[1], 
                Extra_KM_Rate__c = rt[2],
                Current_Odometer__c = 10000 + (i * 500), 
                Status__c = 'Available'
            ));
        }
        
        cars[9].Status__c = 'Under_Maintenance'; 
        insert cars;
        
        Map<Id, Decimal> odo = new Map<Id, Decimal>();
        for (Car__c c : cars) { 
            odo.put(c.Id, c.Current_Odometer__c); 
        }
        
        // 4. Create 15 Customers (Contacts) linked to shared Account
        List<String> names = new List<String>{
            'Priya Nair', 'Arjun Reddy', 'Meera Iyer', 'Karthik Raja', 'Anil Kumar',
            'Divya Menon', 'Suresh Babu', 'Lakshmi Devi', 'Vikram Singh', 'Anitha Raj', 
            'Rahul Verma', 'Sneha Pillai', 'Manoj Kumar', 'Kavya Shetty', 'Ramesh Gupta'
        };
        
        List<Contact> cs = new List<Contact>();
        for (Integer i = 0; i < names.size(); i++) {
            cs.add(new Contact(
                AccountId = sharedAcc.Id, 
                FirstName = names[i].substringBefore(' '), 
                LastName = names[i].substringAfter(' '), 
                Phone = String.valueOf(9876543200L + i), 
                Email = 'customer' + (i + 1) + '@example.com',
                Date_of_Birth__c = Date.today().addYears(-(28 + i)),
                Licence_Number__c = 'TN37-2021-' + String.valueOf(100000 + i),
                Licence_Expiry_Date__c = Date.today().addYears(3)
            ));
        }
        
        cs[3].Date_of_Birth__c = Date.today().addYears(-20).addDays(-60); // Karthik, aged 20 (underage test)
        cs[4].Licence_Expiry_Date__c = Date.today().addDays(-30);         // Anil, licence expired
        insert cs;
        
        // 5. Create 20 Bookings across all 4 statuses
        // Group A: 6 Returned bookings
        List<Booking__c> returned = new List<Booking__c>{
            mkReturned(cars[0], cs[0], -2, 1, 0, 400, odo), 
            mkReturned(cars[1], cs[1], -2, 1, 3, 900, odo), 
            mkReturned(cars[2], cs[2], -2, 1, 0, 520, odo), 
            mkReturned(cars[3], cs[5], -1, 1, 2, 300, odo), 
            mkReturned(cars[4], cs[6], -2, 1, 0, 650, odo), 
            mkReturned(cars[7], cs[7], -1, 1, 0, 200, odo)  
        };
        insert returned;
        
        // Group B: 2 Picked Up bookings
        Booking__c pu1 = mk(cars[1], cs[8], 0, 2, 'Picked Up');
        pu1.Pickup_Odometer__c = odo.get(cars[1].Id);
        Booking__c pu2 = mk(cars[2], cs[9], 0, 2, 'Picked Up');
        pu2.Pickup_Odometer__c = odo.get(cars[2].Id);
        insert new List<Booking__c>{pu1, pu2};
        
        // Group C: 8 Reserved bookings
        insert new List<Booking__c>{
            mk(cars[0], cs[10], 3, 2, 'Reserved'), 
            mk(cars[3], cs[11], 4, 3, 'Reserved'),
            mk(cars[4], cs[12], 5, 1, 'Reserved'), 
            mk(cars[5], cs[13], 6, 2, 'Reserved'),
            mk(cars[6], cs[14], 7, 4, 'Reserved'), 
            mk(cars[7], cs[0], 10, 2, 'Reserved'),
            mk(cars[8], cs[1], 12, 3, 'Reserved'), 
            mk(cars[1], cs[2], 6, 2, 'Reserved')
        };

        // Group D: 4 Cancelled bookings (Fixed API Name syntax typo here)
        List<Booking__c> cancelled = new List<Booking__c>{
            mk(cars[3], cs[5], 15, 2, 'Cancelled'), 
            mk(cars[4], cs[6], 16, 2, 'Cancelled'),
            mk(cars[5], cs[7], 17, 1, 'Cancelled'), 
            mk(cars[6], cs[8], 20, 3, 'Cancelled')
        };
        List<String> reasons = new List<String>{
            'plans changed', 'found another car', 'trip postponed', 'customer request'
        };
        for (Integer i = 0; i < cancelled.size(); i++) { 
            cancelled[i].Cancellation_Reason__c = reasons[i]; 
        }
        insert cancelled;
        
        // 6. Sync Car Odometers & set Picked Up cars to "On Rent" for Report R1
        for (Car__c c : cars) {
            c.Current_Odometer__c = odo.get(c.Id);
        }
        cars[1].Status__c = 'On_Rent';
        cars[2].Status__c = 'On_Rent';
        update cars;
        
        BookingTriggerHandler.bypassRules = false;
        System.debug('Sample data loaded: 10 cars, 15 customers, 20 bookings.');
    }
}