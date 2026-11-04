public with sharing class FleetBoardController {

    // Everything the Fleet Board screen needs, read only. Two queries for any number of cars.
    @AuraEnabled
    public static FleetBoardData getFleet() {
        Datetime nowTime = DriveEasyTime.now();

        List<Car__c> cars = [SELECT Id, Name, Make__c, Model__c, Category__c, Status__c,
                                    Current_Odometer__c, Daily_Rate__c
                             FROM Car__c WITH USER_MODE ORDER BY Category__c, Name LIMIT 200];

        // Active bookings: every Picked Up one, and Reserved ones that have not finished yet
        Map<Id, List<Booking__c>> byCar = new Map<Id, List<Booking__c>>();
        for (Booking__c b : [SELECT Id, Name, Car__c, Status__c, Customer__r.Name,
                                    Pickup_Date_Time__c, Return_Date_Time__c
                             FROM Booking__c
                             WHERE Status__c = 'Picked Up'
                                OR (Status__c = 'Reserved' AND Return_Date_Time__c >= :nowTime)
                             WITH USER_MODE
                             ORDER BY Pickup_Date_Time__c LIMIT 2000]) {
            if (!byCar.containsKey(b.Car__c)) { byCar.put(b.Car__c, new List<Booking__c>()); }
            byCar.get(b.Car__c).add(b);
        }

        FleetBoardData data = new FleetBoardData();
        data.total = cars.size();

        for (Car__c car : cars) {
            FleetCard c = new FleetCard();
            c.carId = car.Id;
            c.registrationNumber = car.Name;
            c.make = car.Make__c;
            c.model = car.Model__c;
            c.category = car.Category__c;
            c.status = canonicalStatus(car.Status__c);
            c.odometer = car.Current_Odometer__c;
            c.dailyRate = car.Daily_Rate__c;

            List<Booking__c> bookings = byCar.get(car.Id);
            if (bookings != null) {
                for (Booking__c b : bookings) {
                    if (b.Status__c == 'Picked Up') {
                        if (c.currentBooking == null) {
                            c.currentBooking = b.Name;
                            c.currentCustomer = b.Customer__r.Name;
                            c.currentPickup = b.Pickup_Date_Time__c;
                            c.currentReturn = b.Return_Date_Time__c;
                            c.availableFrom = b.Return_Date_Time__c.addMinutes(DriveEasySettings.bufferMinutes());
                            if (nowTime > b.Return_Date_Time__c) {
                                Long minutesLate = (nowTime.getTime() - b.Return_Date_Time__c.getTime()) / 60000;
                                c.overdue = true;
                                c.overdueHours = ((minutesLate + 59) / 60).intValue();   // started hours
                            }
                        }
                    } else {
                        c.upcomingCount++;
                        if (c.nextBooking == null) {
                            c.nextBooking = b.Name;
                            c.nextCustomer = b.Customer__r.Name;
                            c.nextPickup = b.Pickup_Date_Time__c;
                            c.nextReturn = b.Return_Date_Time__c;
                        }
                    }
                }
            }

            if (c.status == 'Available') { data.available++; }
            else if (c.status == 'On Rent') { data.onRent++; }
            else if (c.status == 'Under Maintenance') { data.maintenance++; }
            data.cards.add(c);
        }
        return data;
    }

    private static String canonicalStatus(String status) {
        if (String.isBlank(status)) { return status; }
        String value = status.trim().toLowerCase();
        if (value == 'available') { return 'Available'; }
        if (value == 'on rent' || value == 'on_rent') { return 'On Rent'; }
        if (value == 'under maintenance' || value == 'under_maintenance') { return 'Under Maintenance'; }
        return status;
    }
}