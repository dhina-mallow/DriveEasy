@IsTest
private class DriveEasyTimeTest {
    @IsTest
    static void timeUtilitiesWorkInIst() {
        Datetime istMorning = DriveEasyTime.ist(Date.newInstance(2030, 1, 5), 10, 30);
        System.assertEquals(10 * 60 + 30, DriveEasyTime.minuteOfDay(istMorning));
        System.assertEquals(Date.newInstance(2030, 1, 5), DriveEasyTime.dateIST(istMorning));
        System.assert(DriveEasyTime.display(istMorning).contains('IST'));

        Datetime fixed = Datetime.newInstanceGmt(2030, 1, 1, 0, 0, 0);
        DriveEasyTime.nowOverride = fixed;
        System.assertEquals(fixed, DriveEasyTime.now());
    }
}