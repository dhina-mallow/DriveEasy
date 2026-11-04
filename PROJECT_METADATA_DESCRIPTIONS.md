# DriveEasy Project Components

## Objects

### Contact
Stores DriveEasy customers and their age, phone, licence number, and licence expiry details.

### Car__c
Stores the fleet's registration, make, model, category, availability, rates, and current odometer.

### Booking__c
Tracks reservations and their customer, car, dates, status, pickup and return details, copied rates, estimates, and final billing.

### DriveEasy_Setting__mdt
Stores configurable DriveEasy operational and billing business rules.

## Apex Sources

- `BillingService`: Calculates rental days, base rent, extra-kilometre charges, late fees, GST, and final totals.
- `BookingController`: Creates reservations from the user interface and returns booking data.
- `BookingRuleService`: Applies booking time, car, driver, licence, overlap, and return rules.
- `BookingTriggerHandler`: Implements booking insert and update guards and calculates or populates protected booking fields.
- `BookingNotificationQueueable`: Sends asynchronous booking notification work.
- `BookingTrigger`: Routes Booking__c lifecycle events to the booking trigger handler.
- `CarSearchController`: Searches cars and excludes vehicles that are unavailable or already booked for the requested period.
- `DriveEasySettings`: Reads DriveEasy custom metadata settings.
- `DriveEasyTime`: Provides consistent time-zone and date calculations for the application.
- `FleetBoardController`: Supplies fleet and booking data for the fleet board LWC.
- `FleetBoardData` and `FleetCard`: Build data structures used to display fleet board records.
- `ReturnController`: Records vehicle returns and invokes return billing logic.
- `SampleDataLoader`: Creates or resets demonstration data in the Salesforce org.

## Flows

- `Booking_Car_Status_Sync`: Synchronizes the selected car's status with booking pickup or return changes.
- `Booking_Confirmation_Email`: Sends a confirmation email when an eligible booking is created.
- `Cancel_Booking`: Provides the user process for cancelling a reserved booking.
- `Record_Pickup`: Guides pickup processing and records pickup details.

## Lightning Web Components

- `carSearch`: Searches available cars and creates a booking request.
- `fleetBoard`: Displays fleet operational status and current bookings.
- `returnCar`: Records return odometer, actual return time, and billing details.
