@IsTest
private class BillingServiceTest {
 // Helper: 12000 km at pickup, booked from a fixed time
 private static BillingService.Bill calc(Decimal daily, Decimal freeKm, Decimal extraRate,
 Integer bookedMinutes, Integer lateMinutes, Integer km) {
        DriveEasySettings.useDefaultsForTest();
        BillingService.gstPercentOverride = 18;
 Datetime p = Datetime.newInstanceGmt(2030, 1, 10, 4, 30, 0);
 Datetime r = p.addMinutes(bookedMinutes);
 return BillingService.calculate(daily, freeKm, extraRate, p, r, r.addMinutes(lateMinutes), 12000, 12000 + km);
 }
 @IsTest static void at09_lateReturnWithExtraKm() {
 BillingService.Bill b = calc(1800, 250, 10, 48 * 60, 180, 620);
 System.assertEquals(2, b.rentalDays);
 System.assertEquals(3600.00, b.rent);
 System.assertEquals(1200.00, b.extraKmCharge);
 System.assertEquals(360.00, b.lateFee);
 System.assertEquals(928.80, b.gst);
 System.assertEquals(6088.80, b.total);
 }
 @IsTest static void at10_onTimeReturnInsideGraceAndFreeKm() {
 BillingService.Bill b = calc(1800, 250, 10, 48 * 60, 30, 450);
 System.assertEquals(0.00, b.extraKmCharge);
 System.assertEquals(0.00, b.lateFee);
 System.assertEquals(648.00, b.gst);
 System.assertEquals(4248.00, b.total);
 }
 @IsTest static void rentalDaysRounding() {
 System.assertEquals(1, calc(1800, 250, 10, 300, 0, 0).rentalDays); // under a day: minimum 1
 System.assertEquals(1, calc(1800, 250, 10, 1440, 0, 0).rentalDays); // exactly 24h
 System.assertEquals(2, calc(1800, 250, 10, 1441, 0, 0).rentalDays); // 24h 1 min
 }
 @IsTest static void extraKmBoundaries() {
 System.assertEquals(0.00, calc(1800, 250, 10, 2880, 0, 500).extraKmCharge); // exactly free km
 System.assertEquals(10.00, calc(1800, 250, 10, 2880, 0, 501).extraKmCharge); // 1 km over
 System.assertEquals(0.00, calc(1800, 250, 10, 2880, 0, 0).extraKmCharge); // zero km
 }
 @IsTest static void lateFeeBoundariesAndCap() {
 System.assertEquals(0.00, calc(1800, 250, 10, 2880, 60, 0).lateFee); // exactly grace hour
 System.assertEquals(180.00, calc(1800, 250, 10, 2880, 61, 0).lateFee); // 1 started hour
 System.assertEquals(1800.00, calc(1800, 250, 10, 2880, 780, 0).lateFee); // 12h after grace: 2160 capped to 1800
 System.assertEquals(1800.00, calc(1800, 250, 10, 2880, 1500, 0).lateFee); // 24h after grace: cap 1 block
 System.assertEquals(3600.00, calc(1800, 250, 10, 2880, 1501, 0).lateFee); // 24h 1min after grace: cap 2 blocks
 }
 @IsTest static void earlyReturnPaysFullRentNoLateFee() {
 BillingService.Bill b = calc(1800, 250, 10, 2880, -120, 100);
 System.assertEquals(3600.00, b.rent);
 System.assertEquals(0.00, b.lateFee);
 }
 @IsTest static void suvThreeDays() {
 BillingService.Bill b = calc(3500, 300, 15, 72 * 60, 0, 1500);
 System.assertEquals(10500.00, b.rent);
 System.assertEquals(9000.00, b.extraKmCharge);
 System.assertEquals(3510.00, b.gst);
 System.assertEquals(23010.00, b.total);
 }
    @IsTest static void gstPercentIsConfigurable() {
        DriveEasySettings.useDefaultsForTest();
        BillingService.gstPercentOverride = 12;
        Datetime p = Datetime.newInstanceGmt(2030, 1, 10, 4, 30, 0);
        Datetime r = p.addHours(48);
        BillingService.Bill b = BillingService.calculate(1800, 250, 10, p, r, r.addHours(3), 12000, 12620);
        System.assertEquals(12, b.gstPercent);
        System.assertEquals(619.20, b.gst);
        System.assertEquals(5779.20, b.total);
    }
}