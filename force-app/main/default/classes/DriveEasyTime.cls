public with sharing class DriveEasyTime {
 // Tests can set this to pretend "now" is a different time
 @TestVisible private static Datetime nowOverride;
 public static Datetime now() {
 return (nowOverride != null) ? nowOverride : Datetime.now();
 }
 // Minutes since midnight, in IST
 public static Integer minuteOfDay(Datetime dt) {
 Integer h = Integer.valueOf(dt.format('HH', 'Asia/Kolkata'));
 Integer m = Integer.valueOf(dt.format('mm', 'Asia/Kolkata'));
 return h * 60 + m;
 }
 // The calendar date in IST
 public static Date dateIST(Datetime dt) {
 return Date.valueOf(dt.format('yyyy-MM-dd', 'Asia/Kolkata'));
 }
 public static String display(Datetime dt) {
 return dt.format('dd MMM yyyy, hh:mm a', 'Asia/Kolkata') + ' IST';
 }
 // Build a Datetime from a date and an IST clock time
 public static Datetime ist(Date d, Integer hour, Integer minute) {
 return Datetime.newInstanceGmt(d.year(), d.month(), d.day(), hour, minute, 0).addMinutes(-330);
 }
}