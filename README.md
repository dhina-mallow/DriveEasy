# DriveEasy Car Rental

DriveEasy is a Salesforce application for managing a single car-rental branch. It replaces a notebook-based workflow with Lightning pages for finding cars, creating reservations, recording pickups and returns, calculating charges, monitoring fleet availability, and reporting rental performance.

## 2-minute summary

- **Problem:** DriveEasy replaces booking records maintained in a notebook, where overlapping rentals, unverified drivers, and inconsistent bills are easy to miss.
- **What the app does:** Search available cars, estimate rental cost, enforce booking rules, record pickups, calculate and confirm returns, cancel bookings, and monitor the fleet.
- **Key design ideas:** One Apex trigger path enforces booking rules; one `BillingService` calculates every return bill; booking records copy rate settings so later price changes never alter historical bills.

## Problem

Rental staff need reliable answers to questions that are difficult to maintain in a shared notebook:

- Which cars are available for a selected date and time?
- Does a new booking overlap another booking or the required turnaround buffer?
- Is the driver old enough and does the licence remain valid?
- What does a completed rental cost after extra kilometres and late return charges?
- Which cars are on rent, available, overdue, or under maintenance?

## What the App Does

- **Car search:** Search by category and pickup/return time in the Car Search page.
- **Booking lifecycle:** Move reservations through `Reserved`, `Picked Up`, `Returned`, and `Cancelled`.
- **Pickup and return:** Record pickup and return odometers, calculate the final bill, and persist completed charges.
- **Fleet visibility:** Review current and upcoming bookings in Fleet Board and the DriveEasy dashboard.
- **Business rules:** Reject overlaps, invalid customer age or licence dates, maintenance cars, invalid branch hours, and rentals longer than 30 days.
- **Reporting:** View cars by status, monthly revenue by category, monthly extra charges, and bookings by status.
- **Notifications:** Generate a booking confirmation email when Salesforce email delivery is available.
- **Security:** Separate desk-agent and manager permissions for daily operations and fleet management.

## 10-minute walkthrough

1. Log in as the Rental Desk Agent and open **Car Search**. Search for Hatchback cars for a demonstration weekend and review the estimated rent.
2. Try an overlapping booking at the same return time or inside the one-hour turnaround buffer. Review the rejection and the clashing-booking message.
3. Try customers with an underage date of birth or expired licence. The booking should be rejected with a clear validation reason.
4. Record Pickup at an odometer of `12,000 km`. Confirm that the car status changes to `On Rent`.
5. Open **Return Car**, enter a return odometer of `12,620 km` and return the car three hours late. Calculate the bill and confirm an expected total of approximately ₹6,088.80 before confirming the return.
6. Try a return odometer below the pickup odometer. It should be rejected. The desk agent should not have access to the manager-only cancellation or rate-maintenance actions.
7. Log in as the Branch Manager, cancel a booking with a reason, change a demonstration car rate if required, and open the Fleet Dashboard.

## Booking and Billing Rules

- A booking window must be at least two hours ahead and within branch hours.
- Pickup and return must be valid, ordered datetimes, with a maximum duration of 30 days.
- A car cannot overlap another active booking. A one-hour turnaround buffer follows each booking.
- The driver must be at least 21 at pickup, and the licence must remain valid through return.
- Rental days are `CEILING(booked hours / 24)`, with a minimum of one day.
- A late fee starts after a one-hour grace period. It is 10% of the daily rate for each started late hour, capped at one daily rate per each 24-hour late period.
- Extra kilometres are calculated against the allowance for the booked rental days.
- GST is 18% of rent, the extra-kilometre charge, and the late fee.
- Historical return charges are stored on the booking so later rate changes do not alter completed totals.
- Time-zone values are handled in Indian Standard Time (`Asia/Kolkata`).

Default values are stored in the `DriveEasy_Setting.Default` custom metadata record.

## Repository Structure

```text
force-app/main/default/
  applications/            DriveEasy Lightning application
  classes/                 Apex services, controllers, triggers, and tests
  customMetadata/          Default branch and billing settings
  flexipages/              Lightning application pages
  flows/                   Confirmation, pickup, cancellation, and status flows
  lwc/                     Car search, fleet board, and return components
  objects/                 Car, Booking, Contact extensions, and validation rules
  permissionsets/          Desk Agent and Manager Addon access
  reports/                 DriveEasy operational reports
  tabs/                    Application navigation tabs
data/driveeasy-source/      Org-exported reference CSVs
scripts/apex/              Anonymous Apex helpers
```

## Prerequisites

- Salesforce CLI
- VS Code with the Salesforce Extension Pack
- A Developer Edition, sandbox, or scratch org
- A Salesforce user with permission to deploy metadata
- A System Administrator account to run the sample-data loader

Authenticate the target org:

```bash
sf org login web --alias driveeasy-dev --set-default
sf org display --target-org driveeasy-dev
```

## Setup

1. Clone the repository and install the JavaScript development dependencies.

   ```bash
   git clone https://github.com/dhina-mallow/DriveEasy.git
   cd DriveEasy
   npm install
   ```

2. Deploy the complete metadata source.

   ```bash
   sf project deploy start --target-org driveeasy-dev
   ```

3. Open the target org.

   ```bash
   sf org open --target-org driveeasy-dev
   ```

4. Assign **DriveEasy Desk Agent** to rental desk users. Branch managers also need **DriveEasy Manager Addon**.
5. Open **DriveEasy** from App Launcher.

### Fresh-org configuration

Apply these manual Salesforce settings because they are not part of the metadata deployment:

1. Open **Company Information** and set the locale to English (India), the currency to INR, and the time zone to IST (`Asia/Kolkata`) or `(GMT+05:30) Chennai, Kolkata, Mumbai, New Delhi`.
2. Open **Email Administration > Deliverability** and enable email for the target org. Use an appropriate restricted value outside a demo environment.
3. Create one role for **Rental Desk Agent** and one parent role for **Branch Manager**.
4. Set sharing defaults:
   - Car: Public Read Only
   - Booking: Public Read/Write
   - Contact: Public Read/Write
   - External access: Private for Car, Booking, and Contact
5. Share the DriveEasy report and dashboard folders with the Branch Manager role.
6. Activate the booking, pickup, cancellation, and confirmation Flows after reviewing their entry conditions.
7. Assign the DriveEasy Desk Agent permission set and, for managers, the Manager Addon permission set.

### Load demo data

Run the repository's Apex sample-data loader for a fresh, repeatable demonstration. It must be run by a System Administrator.

Using Salesforce CLI:

```bash
sf apex run --file scripts/apex/load-sample-data.apex --target-org driveeasy-dev
```

> **Important:** `SampleDataLoader.run()` deletes all `Booking__c` records, all `Car__c` records, and contacts that have a licence number before creating demo records. Do not run it in an org containing production data.

The loader creates 10 cars, 15 customers, and bookings covering returned, picked-up, reserved, and cancelled statuses. It bypasses only the booking-rule check needed to create historical returned records.

### Optional CSV import

Files under `data/driveeasy-source/` are references exported from a source org. Their Salesforce record IDs are org-specific and should not be imported directly into another org.

For a new import:

1. Create customer Contacts first.
2. Import Cars second.
3. Import Bookings last.
4. Map Booking customer lookups using `Licence_Number__c` as the Contact external ID.
5. Map Booking car lookups using the car registration stored in `Car__c.Name`.
6. Correct validation-rule failures in the CSV before importing; Salesforce validation rules, triggers, and Flows also run during Data Import Wizard imports.

## Testing

Run LWC unit tests:

```bash
npm test
```

Run Apex tests in the target org:

```bash
sf apex run test --test-level RunLocalTests --code-coverage --wait 30 --target-org driveeasy-dev
```

Validate the deployment source:

```bash
sf project deploy validate --source-dir force-app --target-org driveeasy-dev
```

## Email Setup

Booking confirmation is optional and depends on Salesforce email delivery:

- Enable Deliverability under **Setup > Email Administration > Deliverability**.
- Verify that the sender address can receive email in the test org.
- Confirm that the booking confirmation flow is active.
- Set `Skip_Confirmation_Email__c` only when a demo import should suppress confirmation email.

## Screenshots

The portfolio submission should include:

- Car Search results with the estimated rental amount visible
- Return Car bill lines and the total before confirmation
- Fleet Dashboard showing fleet status, monthly revenue, extra charges, and booking status
- Apex test execution showing all tests passing and the measured code coverage

## Test logins

Create test-only credentials rather than publishing a real account password:

| Role | URL | Username | Password |
| --- | --- | --- | --- |
| Rental Desk Agent (Ravi) | https://orgfarm-d92a4ed1f5-dev-ed.develop.my.salesforce.com | raviagentdhinakaranvnr2020@gmail.com | Salesforce@6374 |
| Branch Manager (Sunita) | https://orgfarm-d92a4ed1f5-dev-ed.develop.my.salesforce.com | sunithadhinakaranvnr2020@gmail.com | Salesforce@6374 |

If Salesforce sends reviewer verification codes to an email address controlled for the demo, provide those codes separately to the portfolio reviewer. Do not commit passwords or verification codes to Git.

## Key Design Decisions

- **Source-driven Salesforce DX metadata** keeps declarative configuration and code in version control.
- **Standard Contacts and custom Cars and Bookings** keep customer data standard while isolating rental-specific records.
- **Apex services centralize billing, overlap, and time calculations**, while triggers and flows coordinate lifecycle events.
- **Custom metadata settings** store branch hours, turnaround buffer, grace periods, GST, age limits, and rental limits without code deployment.
- **Fleet Board and reporting views** support operational monitoring instead of requiring staff to inspect individual records.
- **Historical bill fields** preserve completed charges when rates or settings change later.
- **IST handling** keeps the branch workflow consistent with `Asia/Kolkata`.
- **Desk Agent and Manager Addon permission sets** separate routine operations from management actions and car maintenance.

## Known Demo Limits

- Payments, fuel charges, damage charges, deposits, no-show fees, and maintenance scheduling are outside the implemented scope.
- The application is designed for one branch and three categories: Hatchback, Sedan, and SUV.
- Cross-branch rentals and returns are not supported.
- Confirmation email delivery depends on org deliverability settings and sender configuration.
