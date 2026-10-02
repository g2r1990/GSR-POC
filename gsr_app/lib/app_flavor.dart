const appFlavor = String.fromEnvironment('APP_FLAVOR', defaultValue: 'customer');
const isOwnerApp = appFlavor == 'owner';
