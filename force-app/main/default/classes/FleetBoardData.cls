public with sharing class FleetBoardData {
    @AuraEnabled public Integer total = 0;
    @AuraEnabled public Integer available = 0;
    @AuraEnabled public Integer onRent = 0;
    @AuraEnabled public Integer maintenance = 0;
    @AuraEnabled public List<FleetCard> cards = new List<FleetCard>();
}