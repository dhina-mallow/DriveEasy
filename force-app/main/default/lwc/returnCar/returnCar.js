import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import previewBill from '@salesforce/apex/ReturnController.previewBill';
import confirmReturn from '@salesforce/apex/ReturnController.confirmReturn';
import STATUS from '@salesforce/schema/Booking__c.Status__c';
import PICKUP_ODO from '@salesforce/schema/Booking__c.Pickup_Odometer__c';
function message(e) {
 return (e && e.body && e.body.message) ? e.body.message : ((e && e.message) || 'Unexpected error');
}
export default class ReturnCar extends LightningElement {
 @api recordId;
 actualReturn;
 odometer;
 bill;
 error;
 isSaving = false;
 @wire(getRecord, { recordId: '$recordId', fields: [STATUS, PICKUP_ODO] })
 booking;
 get isPickedUp() { return getFieldValue(this.booking.data, STATUS) === 'Picked Up'; }
 get pickupOdometer() { return getFieldValue(this.booking.data, PICKUP_ODO); }
 // Changing any input clears the old bill so it must be recalculated
 handleReturnTime(e) { this.actualReturn = e.detail.value; this.bill = undefined; this.error = undefined; }
 handleOdometer(e) { this.odometer = e.detail.value; this.bill = undefined; this.error = undefined; }
 async handleCalculate() {
 this.error = undefined;
 this.bill = undefined;
 if (!this.actualReturn || this.odometer === undefined || this.odometer === '') {
 this.error = 'Enter the actual return time and the return odometer.';
 return;
 }
 try {
 this.bill = await previewBill({
 bookingId: this.recordId,
 actualReturn: this.actualReturn,
 returnOdometer: Number(this.odometer)
 });
 } catch (e) {
 this.error = message(e);
 }
 }
 async handleConfirm() {
 if (this.isSaving) { return; }
 this.isSaving = true;
 this.error = undefined;
 try {
    await confirmReturn({
 bookingId: this.recordId,
 actualReturn: this.actualReturn,
 returnOdometer: Number(this.odometer)
 });
 this.dispatchEvent(new ShowToastEvent({
 title: 'Return completed',
 message: 'The car is Available again and the bill is saved.',
 variant: 'success'
 }));
 this.bill = undefined;
 await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
 } catch (e) {
 this.error = message(e);
 } finally {
 this.isSaving = false;
 }
 }
}