// 1. Get today's local date
Date todayDate = Date.today();

// 2. Build a Datetime for 8:30 AM IST using your class method
Datetime amTime = DriveEasyTime.ist(todayDate, 8, 30);

// 3. Build a Datetime for 9:15 PM IST (21:15) using your class method
Datetime pmTime = DriveEasyTime.ist(todayDate, 21, 15);

// 4. Test the minuteOfDay method (8:30 AM should return 510 minutes)
Integer amMinutes = DriveEasyTime.minuteOfDay(amTime);
Integer pmMinutes = DriveEasyTime.minuteOfDay(pmTime);

// 5. Test the display format method
String displayAM = DriveEasyTime.display(amTime);
String displayPM = DriveEasyTime.display(pmTime);

// 6. Print all execution results to the Debug Log console
System.debug('==============================================');
System.debug('⏰ TEST 1 (AM Display): ' + displayAM);
System.debug('📊 TEST 1 Minutes from Midnight: ' + amMinutes + ' mins (Expected: 510)');
System.debug('----------------------------------------------');
System.debug('⏰ TEST 2 (PM Display): ' + displayPM);
System.debug('📊 TEST 2 Minutes from Midnight: ' + pmMinutes + ' mins (Expected: 1275)');
System.debug('==============================================');