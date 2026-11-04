public with sharing class BillingService {
    // Tests set this to control the GST percent
    @TestVisible private static Decimal gstPercentOverride;

    // GST percent comes from Custom Metadata: DriveEasy Setting, record "Default", field GST Percent
    public static Decimal gstPercent() {
        if (gstPercentOverride != null) { return gstPercentOverride; }
        return DriveEasySettings.gstPercent();
    }
 public class Bill {
 @AuraEnabled public Integer rentalDays;
 @AuraEnabled public Decimal rent;
 @AuraEnabled public Integer kmDriven;
 @AuraEnabled public Integer freeKm;
 @AuraEnabled public Integer extraKm;
 @AuraEnabled public Decimal extraKmCharge;
 @AuraEnabled public Integer lateHours;
 @AuraEnabled public Decimal lateFee;
 @AuraEnabled public Decimal subtotal;
 @AuraEnabled public Decimal gst;
 @AuraEnabled public Decimal gstPercent;
 @AuraEnabled public Decimal total;
 }
 public static Decimal money(Decimal v) {
 return v.setScale(2, System.RoundingMode.HALF_UP);
 }
 private static Long minutesBetween(Datetime a, Datetime b) {
 return (b.getTime() - a.getTime()) / 60000;
 }
 // Rounds up value / unit. Zero or negative gives 0.
 private static Integer ceilDiv(Long value, Long unit) {
 if (value <= 0) { return 0; }
 return ((value + unit - 1) / unit).intValue();
 }
 // BR-05: rental days = booked hours / 24 rounded up, minimum 1 (done in minutes)
 public static Integer rentalDays(Datetime pickup, Datetime bookedReturn) {
 Integer d = ceilDiv(minutesBetween(pickup, bookedReturn), 1440);
 return (d < 1) ? 1 : d;
 }
 public static Bill calculate(Decimal dailyRate, Decimal freeKmPerDay, Decimal extraKmRate,
 Datetime pickup, Datetime bookedReturn, Datetime actualReturn,
 Decimal pickupOdo, Decimal returnOdo) {
 Datetime actual = (actualReturn == null) ? bookedReturn : actualReturn;
 Bill b = new Bill();
 b.rentalDays = rentalDays(pickup, bookedReturn);
 b.rent = money(dailyRate * b.rentalDays);
 // BR-06 extra km
 b.kmDriven = (returnOdo - pickupOdo).intValue();
 b.freeKm = (freeKmPerDay * b.rentalDays).intValue();
 b.extraKm = Math.max(0, b.kmDriven - b.freeKm);
 b.extraKmCharge = money(extraKmRate * b.extraKm);
 // BR-07 late fee: 1 hour grace, 10% of daily rate per started hour,
 // capped at one day's rent for each started 24 hours (counted after the grace hour)
 Long lateMinutes = minutesBetween(bookedReturn, actual) - DriveEasySettings.graceMinutes();
 b.lateHours = ceilDiv(lateMinutes, 60);
 Integer lateBlocks = ceilDiv(lateMinutes, 1440);
 Decimal uncapped = dailyRate * DriveEasySettings.lateFeePercentPerHour() / 100 * b.lateHours;
 Decimal cap = dailyRate * lateBlocks;
 b.lateFee = money(uncapped < cap ? uncapped : cap);
 // BR-08 GST
 b.subtotal = money(b.rent + b.extraKmCharge + b.lateFee);
        b.gstPercent = gstPercent();
        b.gst = money(b.subtotal * b.gstPercent / 100);
 b.total = money(b.subtotal + b.gst);
 return b;
 }
}