public with sharing class BookingNotificationQueueable implements Queueable {

    private List<Id> bookingIds;

    // Tests read these to check what was sent (FR-15, AT-18)
    @TestVisible private static List<Messaging.SingleEmailMessage> sentEmails = new List<Messaging.SingleEmailMessage>();
    @TestVisible private static String lastError;

    // Constructor
    public BookingNotificationQueueable(List<Id> bookingIds) {
        this.bookingIds = bookingIds;
    }

    public void execute(QueueableContext context) {

        // Process only first 100 records
        List<Id> currentBatchIds = new List<Id>();
        List<Id> remainingIds = new List<Id>();

        for (Integer i = 0; i < bookingIds.size(); i++) {
            if (i < 100) {
                currentBatchIds.add(bookingIds[i]);
            } else {
                remainingIds.add(bookingIds[i]);
            }
        }

        if (currentBatchIds.isEmpty()) {
            return;
        }

        // Query Booking, Customer and Car details
        List<Booking__c> bookings = [
            SELECT Id,
                   Name,
                   Pickup_Date_Time__c,
                   Return_Date_Time__c,
                   Rental_Days__c,
                   Estimated_Rent__c,
                   Customer__c,
                   Customer__r.Name,
                   Customer__r.Email,
                   Car__c,
                   Car__r.Name,
                   Car__r.Make__c,
                   Car__r.Model__c
            FROM Booking__c
            WHERE Id IN :currentBatchIds
            AND Customer__r.Email != NULL
        ];

        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();

        for (Booking__c b : bookings) {

            String carDetails = '';

            if (b.Car__c != null) {
                carDetails =
                    (b.Car__r.Make__c != null ? b.Car__r.Make__c : '') +
                    ' ' +
                    (b.Car__r.Model__c != null ? b.Car__r.Model__c : '') +
                    ' (' + b.Car__r.Name + ')';
            }

            // NFR-03: dates in the email are always shown in IST
            String pickupStr = b.Pickup_Date_Time__c != null ? DriveEasyTime.display(b.Pickup_Date_Time__c) : '';
            String returnStr = b.Return_Date_Time__c != null ? DriveEasyTime.display(b.Return_Date_Time__c) : '';

            String htmlBody =
                '<p>Hello ' + b.Customer__r.Name +
                ', your DriveEasy booking ' + b.Name +
                ' is confirmed.</p>' +

                '<ul>' +
                '<li><b>Car:</b> ' + carDetails + '</li>' +
                '<li><b>Pickup:</b> ' + pickupStr + ' <b>Return:</b> ' + returnStr + '</li>' +
                '<li><b>Rental Days:</b> ' + (b.Rental_Days__c != null ? String.valueOf(b.Rental_Days__c) : '0') +
                ' <b>Estimated Rent:</b> ₹' + (b.Estimated_Rent__c != null ? String.valueOf(b.Estimated_Rent__c) : '0.00') +
                ' (before extra km, late fee and GST)</li>' +
                '</ul>' +

                '<p>Thank you for choosing DriveEasy Rentals.</p>';

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ b.Customer__r.Email });
            mail.setSubject('DriveEasy booking confirmed: ' + b.Name);
            mail.setHtmlBody(htmlBody);
            mail.setUseSignature(false);

            emailList.add(mail);
        }

        // Send all emails
        if (!emailList.isEmpty()) {
            try {
                Messaging.sendEmail(emailList);
                sentEmails.addAll(emailList);
            }
            catch (Exception e) {
                // A failed email must not undo the booking; record the reason so it is visible
                lastError = e.getMessage();
                System.debug(LoggingLevel.ERROR, 'Booking confirmation email failed: ' + e.getMessage());
            }
        }

        // Chain another Queueable if records remain
        if (!remainingIds.isEmpty() && !Test.isRunningTest()) {
            System.enqueueJob(new BookingNotificationQueueable(remainingIds));
        }
    }
}