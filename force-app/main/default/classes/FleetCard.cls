public with sharing class FleetCard {
    @AuraEnabled public Id carId;
    @AuraEnabled public String registrationNumber;
    @AuraEnabled public String make;
    @AuraEnabled public String model;
    @AuraEnabled public String category;
    @AuraEnabled public String status;
    @AuraEnabled public Decimal odometer;
    @AuraEnabled public Decimal dailyRate;

    // Car currently out (a Picked Up booking)
    @AuraEnabled public String currentBooking;
    @AuraEnabled public String currentCustomer;
    @AuraEnabled public Datetime currentPickup;
    @AuraEnabled public Datetime currentReturn;
    @AuraEnabled public Datetime availableFrom;   // booked return + 1 hour turnaround buffer
    @AuraEnabled public Boolean overdue = false;
    @AuraEnabled public Integer overdueHours = 0;

    // Next Reserved booking
    @AuraEnabled public String nextBooking;
    @AuraEnabled public String nextCustomer;
    @AuraEnabled public Datetime nextPickup;
    @AuraEnabled public Datetime nextReturn;
    @AuraEnabled public Integer upcomingCount = 0;
}