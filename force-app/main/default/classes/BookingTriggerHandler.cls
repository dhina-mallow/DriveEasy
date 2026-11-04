public with sharing class BookingTriggerHandler {
 // Only the sample data loader and special tests turn this on
 public static Boolean bypassRules = false;
 public static void beforeInsert(List<Booking__c> newList) { process(newList, null); }
 public static void beforeUpdate(List<Booking__c> newList, Map<Id, Booking__c> oldMap) { process(newList, oldMap); }
 public static void beforeDelete(List<Booking__c> oldList) {
 if (bypassRules) { return; }
 for (Booking__c b : oldList) {
 b.addError('Bookings cannot be deleted. Cancel a Reserved booking instead.');
 }
 }
 private static void process(List<Booking__c> newList, Map<Id, Booking__c> oldMap) {
 if (bypassRules) { return; }
 Boolean isInsert = (oldMap == null);
 Set<Id> carIds = new Set<Id>();
 Set<Id> custIds = new Set<Id>();
 Set<Id> selfIds = new Set<Id>();
 for (Booking__c b : newList) {
 if (b.Car__c != null) { carIds.add(b.Car__c); }
 if (b.Customer__c != null) { custIds.add(b.Customer__c); }
 if (b.Id != null) { selfIds.add(b.Id); }
 }
 // FOR UPDATE locks the cars so two people saving at the same moment cannot both pass the overlap check
 Map<Id, Car__c> cars = new Map<Id, Car__c>([
 SELECT Id, Name, Category__c, Status__c, Daily_Rate__c,
 Free_KM_Per_Day__c, Extra_KM_Rate__c, Current_Odometer__c
 FROM Car__c WHERE Id IN :carIds FOR UPDATE]);
 Map<Id, Contact> customers = new Map<Id, Contact>([
 SELECT Id, Date_of_Birth__c, Licence_Expiry_Date__c FROM Contact WHERE Id IN :custIds]);
 // One query for all existing active bookings on these cars
 Map<Id, List<Booking__c>> activeByCar = new Map<Id, List<Booking__c>>();
 for (Booking__c o : [SELECT Id, Name, Car__c, Pickup_Date_Time__c, Return_Date_Time__c
 FROM Booking__c
 WHERE Car__c IN :carIds AND Status__c IN ('Reserved', 'Picked Up')
 AND Id NOT IN :selfIds]) {
 addActive(activeByCar, o);
 }
 Boolean canCancel = FeatureManagement.checkPermission('Can_Cancel_Booking');
 for (Booking__c b : newList) {
 if (isInsert) {
 handleInsert(b, cars, customers, activeByCar);
 } else {
 handleUpdate(b, oldMap.get(b.Id), cars, customers, activeByCar, canCancel);
 }
 // Accepted rows also count against later rows in the same save (bulk import safety)
 if (!b.hasErrors() && b.Car__c != null && (b.Status__c == 'Reserved' || b.Status__c == 'Picked Up')) {
 addActive(activeByCar, b);
 }
 }
 }
 private static void addActive(Map<Id, List<Booking__c>> m, Booking__c b) {
 if (!m.containsKey(b.Car__c)) { m.put(b.Car__c, new List<Booking__c>()); }
 m.get(b.Car__c).add(b);
 }
 private static void handleInsert(Booking__c b, Map<Id, Car__c> cars, Map<Id, Contact> customers,
 Map<Id, List<Booking__c>> activeByCar) {
 if (String.isBlank(b.Status__c)) { b.Status__c = 'Reserved'; }
 if (b.Status__c != 'Reserved') {
 b.addError('A new booking must start with status Reserved.');
 return;
 }
 validateReservation(b, true, cars, customers, activeByCar);
 }
 // Checks every rule for a Reserved booking and fills the copied rates and estimate
 private static void validateReservation(Booking__c b, Boolean checkLeadTime, Map<Id, Car__c> cars,
 Map<Id, Contact> customers, Map<Id, List<Booking__c>> activeByCar) {
 if (b.Car__c == null || b.Customer__c == null) {
 b.addError('Car and customer are required.');
 return;
 }
 String msg = BookingRuleService.checkTimes(b.Pickup_Date_Time__c, b.Return_Date_Time__c, checkLeadTime);
 if (msg != null) { b.addError(msg); return; }
 Car__c car = cars.get(b.Car__c);
 msg = BookingRuleService.checkCar(car);
 if (msg != null) { b.addError(msg); return; }
 msg = BookingRuleService.checkDriver(customers.get(b.Customer__c), b.Pickup_Date_Time__c, b.Return_Date_Time__c);
 if (msg != null) { b.addError(msg); return; }
 Booking__c clash = BookingRuleService.findClash(b, activeByCar.get(b.Car__c));
 if (clash != null) { b.addError(BookingRuleService.clashMessage(clash, car)); return; }
 // Copy rates so a later rate change never alters this booking
 b.Daily_Rate__c = car.Daily_Rate__c;
 b.Free_Km_Per_Day__c = car.Free_KM_Per_Day__c;
 b.Extra_Km_Rate__c = car.Extra_KM_Rate__c;
 b.Car_Category__c = car.Category__c;
 b.Rental_Days__c = BillingService.rentalDays(b.Pickup_Date_Time__c, b.Return_Date_Time__c);
 b.Estimated_Rent__c = BillingService.money(car.Daily_Rate__c * b.Rental_Days__c);
 }
 private static void handleUpdate(Booking__c b, Booking__c old, Map<Id, Car__c> cars, Map<Id, Contact> customers,
 Map<Id, List<Booking__c>> activeByCar, Boolean canCancel) {
 String oldStatus = old.Status__c;
 String newStatus = b.Status__c;
 if (oldStatus == 'Returned' || oldStatus == 'Cancelled') {
 b.addError('A ' + oldStatus + ' booking cannot be changed.');
 return;
 }
 // BRD section 10: bill amounts and the rates copied at booking are set by the system only
 if (systemFieldsChanged(b, old)) {
 b.addError('Bill amounts and the copied car rates are calculated by the system and cannot be edited.');
 return;
 }
 Boolean keyChanged = b.Car__c != old.Car__c || b.Customer__c != old.Customer__c
 || b.Pickup_Date_Time__c != old.Pickup_Date_Time__c || b.Return_Date_Time__c != old.Return_Date_Time__c;
 // FR-03 status order
 if (oldStatus != newStatus) {
 if (keyChanged) {
 b.addError('Do not change the car, customer or dates while changing the status.');
 } else if (oldStatus == 'Reserved' && newStatus == 'Picked Up') {
 doPickup(b, cars);
 } else if (oldStatus == 'Reserved' && newStatus == 'Cancelled') {
 doCancel(b, canCancel);
 } else if (oldStatus == 'Picked Up' && newStatus == 'Returned') {
 doReturn(b);
 } else {
 b.addError('Status cannot change from ' + oldStatus + ' to ' + newStatus
 + '. The order is Reserved, Picked Up, Returned. Only a Reserved booking can be Cancelled.');
 }
 return;
 }
 // Status not changing
 if (oldStatus == 'Picked Up') {
 if (keyChanged || b.Pickup_Odometer__c != old.Pickup_Odometer__c) {
 b.addError('A Picked Up booking can only be changed by returning it.');
 }
 return;
 }
 if (keyChanged) { // Reserved booking edited: run every rule again (it excludes itself)
 Boolean timesChanged = b.Pickup_Date_Time__c != old.Pickup_Date_Time__c || b.Return_Date_Time__c != old.Return_Date_Time__c;
 validateReservation(b, timesChanged, cars, customers, activeByCar);
 }
 }
 // Fields only the trigger may write (copied rates at booking, bill at return)
 private static final List<Schema.SObjectField> SYSTEM_FIELDS = new List<Schema.SObjectField>{
 Booking__c.Daily_Rate__c, Booking__c.Free_Km_Per_Day__c, Booking__c.Extra_Km_Rate__c,
 Booking__c.Car_Category__c, Booking__c.Rental_Days__c, Booking__c.Estimated_Rent__c,
 Booking__c.Rent__c, Booking__c.Extra_Km_Charge__c, Booking__c.Late_Fee__c,
 Booking__c.GST__c, Booking__c.Total__c
 };
 private static Boolean systemFieldsChanged(Booking__c b, Booking__c old) {
 for (Schema.SObjectField f : SYSTEM_FIELDS) {
 if (b.get(f) != old.get(f)) { return true; }
 }
 return false;
 }
 // FR-10 pickup
 private static void doPickup(Booking__c b, Map<Id, Car__c> cars) {
 Car__c car = cars.get(b.Car__c);
 if (car == null) { b.addError('Car not found.'); return; }
 if (car.Status__c != 'Available') {
 b.addError('Car ' + car.Name + ' is ' + car.Status__c + ' and cannot be handed over now. '
 + 'Ask the Branch Manager to give the customer another car of the same category.');
 return;
 }
 if (b.Pickup_Odometer__c == null) { b.addError('Enter the pickup odometer reading.'); return; }
 if (b.Pickup_Odometer__c < car.Current_Odometer__c) {
 b.addError('The pickup odometer cannot be lower than the car odometer (' + car.Current_Odometer__c + ' km).');
 }
 }
 // FR-16, BR-10 cancel
 private static void doCancel(Booking__c b, Boolean canCancel) {
 if (!canCancel) { b.addError('Only the Branch Manager can cancel a booking.'); return; }
 if (String.isBlank(b.Cancellation_Reason__c)) { b.addError('Enter a cancellation reason.'); }
 }
 // FR-11, FR-12, BR-09 return and bill
 private static void doReturn(Booking__c b) {
 String msg = BookingRuleService.checkReturn(b);
 if (msg != null) { b.addError(msg); return; }
 BillingService.Bill bill = BillingService.calculate(b.Daily_Rate__c, b.Free_Km_Per_Day__c, b.Extra_Km_Rate__c,
 b.Pickup_Date_Time__c, b.Return_Date_Time__c, b.Actual_Return_Time__c,
 b.Pickup_Odometer__c, b.Return_Odometer__c);
 b.Rental_Days__c = bill.rentalDays;
 b.Rent__c = bill.rent;
 b.Extra_Km_Charge__c = bill.extraKmCharge;
 b.Late_Fee__c = bill.lateFee;
 b.GST__c = bill.gst;
 b.Total__c = bill.total;
 }
 public static void afterInsert(List<Booking__c> newBookings) {
        List<Id> bookingIds = new List<Id>();

        for (Booking__c booking : newBookings) {
            if (booking.Skip_Confirmation_Email__c != true) {
                bookingIds.add(booking.Id);
            }
        }

        if (!bookingIds.isEmpty()) {
            System.enqueueJob(new BookingNotificationQueueable(bookingIds));
        }
    }
}