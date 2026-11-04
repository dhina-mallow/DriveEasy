import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchCars from '@salesforce/apex/CarSearchController.searchCars';
import createBooking from '@salesforce/apex/BookingController.createBooking';
function message(e) {
 return (e && e.body && e.body.message) ? e.body.message : ((e && e.message) || 'Unexpected error');
}
export default class CarSearch extends LightningElement {
 category = 'All';
 pickup;
 returnDt;
 customerId;
 cars = [];
 error;
 searched = false;
 isSearching = false;
 categoryOptions = [
 { label: 'All categories', value: 'All' },
 { label: 'Hatchback', value: 'Hatchback' },
 { label: 'Sedan', value: 'Sedan' },
 { label: 'SUV', value: 'SUV' }
 ];
 columns = [
 { label: 'Car', fieldName: 'carName' },
 { label: 'Registration', fieldName: 'registrationNumber' },
 { label: 'Make / Model', fieldName: 'makeModel' },
 { label: 'Category', fieldName: 'category' },
 { label: 'Daily rate', fieldName: 'dailyRate', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
 { label: 'Days', fieldName: 'rentalDays', type: 'number' },
 { label: 'Estimated rent', fieldName: 'estimatedRent', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
 { type: 'button', typeAttributes: { label: 'Book', name: 'book', variant: 'brand' } }
 ];
 get hasCars() { return this.cars.length > 0; }
 get noCars() { return this.searched && this.cars.length === 0 && !this.error; }
 get searchButtonLabel() { return this.isSearching ? 'Searching...' : 'Search cars'; }
 handleCategory(e) { this.category = e.detail.value; }
 handlePickup(e) { this.pickup = e.detail.value; }
 handleReturn(e) { this.returnDt = e.detail.value; }
 handleCustomer(e) { this.customerId = e.detail.recordId; }
 async handleSearch() {
 this.error = undefined;
 this.searched = false;
 this.cars = [];
 if (!this.pickup || !this.returnDt) {
 this.error = 'Choose a pickup and a return date and time.';
 return;
 }
 try {
  this.isSearching = true;
 this.cars = await searchCars({ category: this.category, pickup: this.pickup, returnDt: this.returnDt });
 this.searched = true;
 } catch (e) {
 this.error = message(e);
 } finally {
  this.isSearching = false;
 }
 }
 async handleRowAction(event) {
 this.error = undefined;
 if (!this.customerId) {
 this.error = 'Choose a customer before booking.';
 return;
 }
 try {
 const name = await createBooking({
 carId: event.detail.row.carId,
 customerId: this.customerId,
 pickup: this.pickup,
 returnDt: this.returnDt
 });
 this.dispatchEvent(new ShowToastEvent({
 title: 'Booking ' + name + ' created',
 message: 'The confirmation email is on its way to the customer.',
 variant: 'success'
 }));
 await this.handleSearch();
 } catch (e) {
 this.error = message(e);
 }
 }
}