// Security (BRD section 10): queries run in user mode, so object, field and sharing access are enforced
public with sharing class CarSearchController {
 public class CarResult {
 @AuraEnabled public Id carId;
 @AuraEnabled public String carName;
 @AuraEnabled public String registrationNumber;
 @AuraEnabled public String makeModel;
 @AuraEnabled public String category;
 @AuraEnabled public Decimal dailyRate;
 @AuraEnabled public Integer rentalDays;
 @AuraEnabled public Decimal estimatedRent;
 }
 @AuraEnabled
 public static List<CarResult> searchCars(String category, Datetime pickup, Datetime returnDt) {
 String msg = BookingRuleService.checkTimes(pickup, returnDt, true);
 if (msg != null) { throw err(msg); }
 // Cars that clash with the wanted time, including the 1-hour buffer after every booking
 Datetime windowStart = pickup.addMinutes(-DriveEasySettings.bufferMinutes());
 Datetime windowEnd = returnDt.addMinutes(DriveEasySettings.bufferMinutes());
 Set<Id> busy = new Set<Id>();
 for (Booking__c b : [SELECT Car__c FROM Booking__c
 WHERE Status__c IN ('Reserved', 'Picked Up')
 AND Pickup_Date_Time__c < :windowEnd AND Return_Date_Time__c > :windowStart
 WITH USER_MODE]) {
 busy.add(b.Car__c);
 }
 List<Car__c> cars;
 if (String.isBlank(category) || category == 'All') {
 cars = [SELECT Id, Name, Make__c, Model__c, Category__c, Daily_Rate__c
 FROM Car__c WHERE Status__c != 'Under_Maintenance' AND Id NOT IN :busy
 WITH USER_MODE ORDER BY Category__c, Name LIMIT 100];
 } else {
 cars = [SELECT Id, Name, Make__c, Model__c, Category__c, Daily_Rate__c
 FROM Car__c WHERE Status__c != 'Under_Maintenance' AND Id NOT IN :busy
 AND Category__c = :category WITH USER_MODE ORDER BY Name LIMIT 100];
 }
 Integer days = BillingService.rentalDays(pickup, returnDt);
 List<CarResult> results = new List<CarResult>();
 for (Car__c c : cars) {
 CarResult r = new CarResult();
 r.carId = c.Id;
 r.carName = c.Name;
 r.registrationNumber = c.Name;
 r.makeModel = c.Make__c + ' ' + c.Model__c;
 r.category = c.Category__c;
 r.dailyRate = c.Daily_Rate__c;
 r.rentalDays = days;
 r.estimatedRent = BillingService.money(c.Daily_Rate__c * days);
 results.add(r);
 }
 return results;
 }
 private static AuraHandledException err(String msg) {
 AuraHandledException e = new AuraHandledException(msg);
 e.setMessage(msg);
 return e;
 }
}