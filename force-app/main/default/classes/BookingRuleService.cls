public with sharing class BookingRuleService {
 // BR-03: lead time, branch hours, return after pickup, 30 days max. Returns an error text or null.
    public static String checkTimes(Datetime pickup, Datetime returnDt, Boolean checkLeadTime) {
        if (pickup == null || returnDt == null) { return 'Pickup and return date-time are required.'; }
        if (returnDt <= pickup) { return 'Return must be after pickup.'; }
        Integer leadHours = DriveEasySettings.minimumLeadHours();
        if (checkLeadTime && pickup < DriveEasyTime.now().addHours(leadHours)) {
            return 'Pickup must be at least ' + leadHours + ' hours from now.';
        }
        Integer openMinute = DriveEasySettings.openHour() * 60;
        Integer closeMinute = DriveEasySettings.closeHour() * 60;
        String hoursText = DriveEasySettings.hourText(DriveEasySettings.openHour()) + ' and '
                         + DriveEasySettings.hourText(DriveEasySettings.closeHour());
        Integer p = DriveEasyTime.minuteOfDay(pickup);
        Integer r = DriveEasyTime.minuteOfDay(returnDt);
        if (p < openMinute || p > closeMinute) { return 'Pickup time must be between ' + hoursText + ' (IST).'; }
        if (r < openMinute || r > closeMinute) { return 'Return time must be between ' + hoursText + ' (IST).'; }
        Integer maxDays = DriveEasySettings.maxRentalDays();
        Long maxMinutes = maxDays * 24 * 60;
        if ((returnDt.getTime() - pickup.getTime()) / 60000 > maxMinutes) {
            return 'The longest rental is ' + maxDays + ' days.';
        }
        return null;
    }
 // BR-02
 public static String checkCar(Car__c car) {
 if (car == null) { return 'Car not found.'; }
 if (car.Status__c == 'Under_Maintenance') {
 return 'Car ' + car.Name + ' is Under Maintenance and cannot be booked.';
 }
 return null;
 }
 // BR-04: age 21+ on pickup date, licence valid until return date
 public static String checkDriver(Contact c, Datetime pickup, Datetime returnDt) {
 if (c == null) { return 'Customer not found.'; }
 Integer minAge = DriveEasySettings.minimumDriverAge();
 if (c.Date_of_Birth__c == null) { return 'The customer date of birth is missing.'; }
 if (c.Licence_Expiry_Date__c == null) { return 'The customer licence expiry date is missing.'; }
 if (c.Date_of_Birth__c.addYears(minAge) > DriveEasyTime.dateIST(pickup)) {
 return 'The driver must be at least ' + minAge + ' years old on the pickup date.';
 }
 if (c.Licence_Expiry_Date__c < DriveEasyTime.dateIST(returnDt)) {
 return 'The driving licence expires on ' + c.Licence_Expiry_Date__c.format()
 + ', before the return date. Ask the customer to renew it first.';
 }
 return null;
 }
 // BR-01: two active bookings clash when each starts before the other's return + 1 hour
 public static Booking__c findClash(Booking__c nb, List<Booking__c> others) {
 if (others == null) { return null; }
 Datetime nbBlockedUntil = nb.Return_Date_Time__c.addMinutes(DriveEasySettings.bufferMinutes());
 for (Booking__c o : others) {
 Datetime oBlockedUntil = o.Return_Date_Time__c.addMinutes(DriveEasySettings.bufferMinutes());
 if (nb.Pickup_Date_Time__c < oBlockedUntil && o.Pickup_Date_Time__c < nbBlockedUntil) {
 return o;
 }
 }
 return null;
 }
 public static String clashMessage(Booking__c clash, Car__c car) {
 String who = (clash.Name != null) ? clash.Name : 'another booking in this same save';
 return 'This booking overlaps ' + who + ' for car ' + car.Name + ' ('
 + DriveEasyTime.display(clash.Pickup_Date_Time__c) + ' to ' + DriveEasyTime.display(clash.Return_Date_Time__c)
 + '). Each booking also blocks the car for ' + DriveEasySettings.bufferMinutes() + ' minutes after its return time. Choose other times or another car.';
 }
 // BR-09 and FR-11 checks for a return
 public static String checkReturn(Booking__c b) {
 if (b.Actual_Return_Time__c == null || b.Return_Odometer__c == null) {
 return 'Enter the actual return time and the return odometer.';
 }
 if (b.Pickup_Odometer__c != null && b.Return_Odometer__c < b.Pickup_Odometer__c) {
 return 'The return odometer (' + b.Return_Odometer__c + ') cannot be lower than the pickup odometer ('
 + b.Pickup_Odometer__c + ').';
 }
 if (b.Actual_Return_Time__c < b.Pickup_Date_Time__c) {
 return 'The actual return time cannot be before the pickup time.';
 }
 return null;
 }
}