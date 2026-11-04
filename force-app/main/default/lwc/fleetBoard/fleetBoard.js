import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getFleet from '@salesforce/apex/FleetBoardController.getFleet';

const BADGE = {
    'Available': 'slds-badge slds-theme_success',
    'On Rent': 'slds-badge slds-theme_warning',
    'Under Maintenance': 'slds-badge slds-theme_error'
};
const CARD = {
    'Available': 'card card-available',
    'On Rent': 'card card-onrent',
    'Under Maintenance': 'card card-maintenance'
};

function message(e) {
    return (e && e.body && e.body.message) ? e.body.message : ((e && e.message) || 'Unexpected error');
}

export default class FleetBoard extends NavigationMixin(LightningElement) {
    cards = [];
    counts = { total: 0, available: 0, onRent: 0, maintenance: 0 };
    statusFilter = 'All';
    category = 'All';
    searchText = '';
    error;
    isLoading = true;
    lastUpdated;
    timer;

    categoryOptions = [
        { label: 'All categories', value: 'All' },
        { label: 'Hatchback', value: 'Hatchback' },
        { label: 'Sedan', value: 'Sedan' },
        { label: 'SUV', value: 'SUV' }
    ];

    connectedCallback() {
        this.load();
        this.timer = setInterval(() => this.load(), 60000);   // refresh every minute
    }

    disconnectedCallback() {
        clearInterval(this.timer);
    }

    async load() {
        try {
            const data = await getFleet();
            this.counts = {
                total: data.total,
                available: data.available,
                onRent: data.onRent,
                maintenance: data.maintenance
            };
            this.cards = data.cards.map((c) => this.decorate(c));
            this.lastUpdated = new Date().toISOString();
            this.error = undefined;
        } catch (e) {
            this.error = message(e);
        } finally {
            this.isLoading = false;
        }
    }

    decorate(c) {
        return {
            ...c,
            key: c.carId,
            subtitle: [c.make, c.model].filter(Boolean).join(' '),
            badgeClass: BADGE[c.status] || 'slds-badge',
            cardClass: CARD[c.status] || 'card',
            isAvailable: c.status === 'Available',
            isOnRent: c.status === 'On Rent',
            isMaintenance: c.status === 'Under Maintenance',
            hasCurrent: !!c.currentBooking,
            hasNext: !!c.nextBooking,
            noNext: !c.nextBooking,
            overdueText: c.overdue ? 'Overdue by ' + c.overdueHours + ' hour(s)' : '',
            warnUpcoming: c.status === 'Under Maintenance' && c.upcomingCount > 0,
            moreUpcoming: c.upcomingCount > 1,
            moreCount: c.upcomingCount - 1
        };
    }

    get filteredCards() {
        const q = (this.searchText || '').trim().toLowerCase();
        return this.cards.filter((c) => {
            if (this.statusFilter !== 'All' && c.status !== this.statusFilter) { return false; }
            if (this.category !== 'All' && c.category !== this.category) { return false; }
            if (!q) { return true; }
            return [c.registrationNumber, c.make, c.model, c.currentCustomer, c.nextCustomer, c.currentBooking, c.nextBooking]
                .filter(Boolean).join(' ').toLowerCase().includes(q);
        });
    }

    get filteredCount() { return this.filteredCards.length; }
    get noResults() { return !this.isLoading && !this.error && this.filteredCards.length === 0; }

    tileClass(status) {
        return this.statusFilter === status ? 'tile tile-active' : 'tile';
    }
    get tileAll() { return this.tileClass('All'); }
    get tileAvailable() { return this.tileClass('Available'); }
    get tileOnRent() { return this.tileClass('On Rent'); }
    get tileMaintenance() { return this.tileClass('Under Maintenance'); }

    handleStatusFilter(event) { this.statusFilter = event.currentTarget.dataset.status; }
    handleCategory(event) { this.category = event.detail.value; }
    handleSearch(event) { this.searchText = event.target.value; }
    handleRefresh() { this.isLoading = true; this.load(); }

    handleOpen(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: event.currentTarget.dataset.id, objectApiName: 'Car__c', actionName: 'view' }
        });
    }
}