const appFlavor = String.fromEnvironment('APP_FLAVOR', defaultValue: 'customer');
const isAdminApp = appFlavor == 'admin';
const isOwnerApp = appFlavor == 'owner';
const isCustomerApp = appFlavor == 'customer';
const isRiderApp = appFlavor == 'rider';
