public with sharing class BookingController {
 @AuraEnabled
 public static String createBooking(Id carId, Id customerId, Datetime pickup, Datetime returnDt) {
 Booking__c b = new Booking__c(
 Car__c = carId, Customer__c = customerId,
 Pickup_Date_Time__c = pickup, Return_Date_Time__c = returnDt, Status__c = 'Reserved');
 try {
 // User mode: a user without Booking create access is refused
 insert as user b;
 } catch (DmlException e) {
 throw err(e.getDmlMessage(0));
 } catch (SecurityException e) {
 throw err('You do not have permission to create bookings.');
 }
 return [SELECT Name FROM Booking__c WHERE Id = :b.Id WITH USER_MODE].Name;
 }
 private static AuraHandledException err(String msg) {
 AuraHandledException ex = new AuraHandledException(msg);
 ex.setMessage(msg);
 return ex;
 }
}