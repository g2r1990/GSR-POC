// App-wide constants — single source of truth.
// Bug history: cancel window drifted 3× (60s→30s→15s) and PIN length
// mismatched backend (4-digit UI vs 6-digit backend) before this file.
const int kCancelWindowSecs = 15;
const int kDeliveryPinLength = 6;
