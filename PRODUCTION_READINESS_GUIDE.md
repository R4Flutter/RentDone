# RentDone Production-Readiness Hardening Guide

## Completed Improvements ✅

### 1. Custom Payment Exception Types
**File:** `lib/features/owner/owner_payment/domain/exceptions/payment_exceptions.dart`
- **8 exception classes** for granular error handling
- User-friendly error messages for all failure modes
- Proper exception hierarchy

**Exception Types:**
- `InvalidPaymentAmountException` - Amount validation failures
- `InvalidPaymentStatusException` - Status invalid or transition errors
- `PaymentStorageException` - Firestore operation failures
- `PaymentGatewayException` - Razorpay/payment gateway errors
- `InvalidPaymentContextException` - Auth/permissions/entity not found

### 2. Hardened Payment Service
**File:** `lib/features/owner/owner_payment/data/services/tenant_payment_history_firebase_service.dart`

**Improvements:**
- ✅ All Firestore writes wrapped in try-catch
- ✅ Input validation with max/min limits
- ✅ Amount limits: max Rs 50,00,000 (configurable)
- ✅ Date validation (prevents future dates, >2 years old)
- ✅ Network error detection and handling
- ✅ Permission-denied error handling
- ✅ Returns payment ID from `addPayment()` for tracking
- ✅ Full payload construction with all required fields

**Key Methods:**
```dart
// Now throws typed PaymentException
Future<String> addPayment({...}) async // Returns payment ID

// Validates status transitions
Future<void> updatePaymentStatus({...})

// Records Razorpay payments atomically
Future<String> recordRazorpayPayment({...})
```

### 3. Hardened Razorpay Service
**File:** `lib/features/owner/owner_payment/data/services/razorpay_service.dart`

**Improvements:**
- ✅ Timeout protection (5 minute max)
- ✅ Error classification (insufficient funds, invalid card, timeout)
- ✅ Prevents duplicate payment submissions
- ✅ Proper error stream publishing
- ✅ Payment cancellation support
- ✅ Typed exception throwing

**Key Features:**
- `paymentErrorStream` - Subscribe for error messages
- `_classifyPaymentError()` - Maps Razorpay codes to user-friendly messages
- Timeout handling prevents hung payment states

### 4. Dashboard Error Handling
**File:** `lib/features/owner/owner_dashboard/data/services/dashboard_firebase_service.dart`

**Improvements:**
- ✅ All Firestore calls wrapped in try-catch
- ✅ Stream error handlers with fallback values
- ✅ Network error resilience
- ✅ Permission-denied handling

**Features:**
- Returns empty data on errors (graceful degradation)
- Logs errors for debugging
- Streams continue with empty fallback

### 5. Production Validators
**File:** `lib/shared/validation/production_validators.dart`

**Validator Classes:**
- `PaymentValidator` - 7 validation methods + batch validator
- `TenantValidator` - 7 validation methods + batch validator
- `PropertyValidator` - 4 validation methods + batch validator

**Validation Coverage:**
```dart
PaymentValidator:
- validateAmount() - Zero, negative, max limit
- validateInstallmentAmount() - Remaining balance check
- validateStatus() - Valid status list
- validatePaymentDate() - Future/past date checks
- validatePaymentMethod() - Valid method list
- validateBaseAmount() - Rent amount sanity checks
- validatePaymentRecord() - Batch validation

TenantValidator:
- validateFullName() - Length, space requirement
- validatePhone() - Digit count validation
- validateEmail() - RFC regex validation
- validateRentAmount() - Zero/max checks
- validateSecurityDeposit() - Negative/max checks
- validateLeaseDate() - Future date prevention
- validateTenantRecord() - Batch validation

PropertyValidator:
- validatePropertyName() - Length validation
- validateRoomCount() - Min/max room count
- validateAddress() - Completeness check
- validatePropertyRecord() - Batch validation
```

### 6. Offline Caching Layer
**File:** `lib/shared/cache/offline_cache_service.dart`

**Features:**
- ✅ Local persistence using SharedPreferences
- ✅ 24-hour cache expiry (configurable)
- ✅ Separate caches for dashboard, payments, properties, tenants
- ✅ Graceful cache invalidation
- ✅ Automatic expiry checking

**Methods:**
```dart
// Cache data
cacheDashboardSummary(Map<String, dynamic> data)
cachePayments(List<Map<String, dynamic>> payments)
cacheProperties(List<Map<String, dynamic>> properties)
cacheTenants(List<Map<String, dynamic>> tenants)

// Retrieve cached data
getCachedDashboardSummary() // Returns null if expired
getCachedPayments()
getCachedProperties()
getCachedTenants()

// Clear caches
clearAllCaches()
```

**Usage:**
```dart
// Initialize once on app startup
await offlineCacheService.init();

// Use in services/repositories
if (connected) {
  final freshData = await firestore.fetch();
  await offlineCacheService.cachePayments(freshData);
} else {
  final cached = offlineCacheService.getCachedPayments();
  if (cached.isNotEmpty) return cached; // Use stale data
}
```

---

## Remaining Tasks (Priority Order)

### HIGH PRIORITY (Do This First)

#### 1. Update Payment History Screen with Error Handling
**File:** `lib/features/owner/owner_payment/presentation/pages/tenant_payment_history_screen.dart`

**Required Changes:**
```dart
// Catch PaymentException and show user-friendly messages
try {
  final service = ref.read(tenantPaymentHistoryServiceProvider);
  await service.addPayment(...);
} on InvalidPaymentAmountException catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.message), backgroundColor: Colors.red),
  );
} on PaymentStorageException catch (e) {
  // Show retry dialog with exponential backoff
  showErrorDialog(context, e.message);
}
```

**Checklist:**
- [ ] Import `PaymentValidator` and use for pre-submission validation
- [ ] Catch `PaymentException` types and map to UX
- [ ] Add retry logic for network errors (exponential backoff)
- [ ] Show loading state during add/update
- [ ] Add empty state when no payments exist
- [ ] Show actual payment ID after successful save
- [ ] Add SnackBar confirmations for status updates

#### 2. Update Add Payment Form with Validation
**File:** `lib/features/owner/owner_payment/presentation/widgets/add_payment_form.dart`

**Required Changes:**
```dart
// Use PaymentValidator before enabling submit
final amountError = PaymentValidator.validateAmount(_amountController.text);
if (amountError != null) {
  _showErrorSnackbar(amountError);
  return; // Prevent submission
}

// Disable submit button if validation fails
final isValid = _amountController.text.isNotEmpty &&
    PaymentValidator.validateAmount(int.tryParse(_amountController.text)) == null &&
    _dateController.text.isNotEmpty;

submitButton.enabled = isValid;
```

**Checklist:**
- [ ] Add `TextFormField` validators (or custom)
- [ ] Max amount limit to 50 lakhs
- [ ] Disable future dates in DatePicker
- [ ] Validate method selection
- [ ] Show validation errors inline (red text below field)
- [ ] Disable submit button until all valid
- [ ] Add "Amount exceeds remaining" check for installments
- [ ] Currency formatting with commas (e.g., Rs 50,000)

#### 3. Add Empty States to All Screens
**Files to Update:**
- `payment_screen.dart` - "No payments found"
- `tenant_payment_history_screen.dart` - "No payment history"
- `property_detail_screen.dart` - "No tenants yet"
- `payment_overview.dart` - "No payments" when zero
- `messages_panel.dart` - "You're all caught up"
- `recent_activity.dart` - "No recent activity"
- `tenant_list_screen.dart` - "No tenants assigned"

**Pattern for Empty States:**
```dart
// In build():
if (_items.isEmpty && !isLoading) {
  return EmptyState(
    icon: Icons.receipt_long,
    title: 'No Payments Yet',
    message: 'Track and manage rent payments here.',
    action: 'Add Payment',
    onAction: () => showAddPaymentSheet(context),
  );
}
```

**Checklist:**
- [ ] Create reusable `EmptyStateWidget`
- [ ] Add illustration/icon for each state
- [ ] Include CTA button (Add Payment, Add Tenant, etc.)
- [ ] Add loading skeleton states (.loading case)
- [ ] Add error state UI (.error case)

#### 4. Update Razorpay Checkout Screen with Retry Logic
**File:** `lib/features/owner/owner_payment/presentation/pages/razorpay_checkout_screen.dart`

**Required Changes:**
```dart
// Save transaction ID BEFORE Firebase write
final txnId = 'pay_${DateTime.now().millisecondsSinceEpoch}';

// Implement exponential backoff retry
Future<bool> _savePaymentWithRetry({
  int maxRetries = 3,
  Duration delay = const Duration(seconds: 2),
}) async {
  for (int i = 0; i < maxRetries; i++) {
    try {
      return await service.recordRazorpayPayment(...);
    } catch (e) {
      if (i == maxRetries - 1) rethrow;
      await Future.delayed(delay * (i + 1)); // Exponential backoff
    }
  }
  return false;
}

// Listen for payment errors
paymentService.paymentErrorStream.listen((error) {
  showErrorDialog(context, error.message);
});
```

**Checklist:**
- [ ] Subscribe to `paymentErrorStream` from service
- [ ] Implement 3-retry exponential backoff (2s, 4s, 8s)
- [ ] Save transaction ID immediately after Razorpay success
- [ ] Log transaction ID to console for manual recovery
- [ ] Show retry dialog on Firebase failure
- [ ] Store pending transaction in local cache
- [ ] Sync pending transactions on app restart

#### 5. Integrate OfflineCacheService into Repository
**File:** `lib/features/owner/owner_dashboard/data/repositories/dashboard_repository_impl.dart`

**Required Changes:**
```dart
// On success: Cache the data
final summary = ...; // Built from payments/properties
await offlineCacheService.cacheDashboardSummary(summary.toMap());

// On failure: Return cached data
} catch (e) {
  final cached = offlineCacheService.getCachedDashboardSummary();
  if (cached != null) {
    return DashboardSummary.fromMap(cached); // Return stale data
  }
  rethrow; // No cache available
}

// In UI, show cached indicator
if (usedCache) {
  showSnackBar('Showing offline data. Tap to refresh.');
}
```

**Checklist:**
- [ ] Initialize `offlineCacheService` on app startup
- [ ] Cache data on successful fetch
- [ ] Return cached data on network errors
- [ ] Show "Offline" badge when using stale data
- [ ] Add refresh button to sync with server
- [ ] Clear cache on logout

### MEDIUM PRIORITY

#### 6. Add Comprehensive Logging
- [ ] Implement Firebase Crashlytics integration
- [ ] Log all PaymentException instances
- [ ] Log transaction IDs with timestamps
- [ ] Add analytics for payment success/failure rates
- [ ] Track retry attempts and outcomes

#### 7. Add Loading Skeleton States
- [ ] Create reusable `SkeletonLoader` widget
- [ ] Add skeleton to payment cards
- [ ] Add skeleton to tenant lists
- [ ] Add skeleton to dashboard widgets
- [ ] Smooth 300ms fade transition

#### 8. Network Resilience
- [ ] Add connectivity_plus package
- [ ] Show offline banner when disconnected
- [ ] Queue failed operations for sync on reconnect
- [ ] Implement exponential backoff for all retries
- [ ] Add timeout to all Firestore operations

#### 9. Input Sanitization
- [ ] Trim all string inputs
- [ ] Validate against SQL injection patterns
- [ ] Sanitize notes field (remove special chars)
- [ ] Validate phone numbers per country
- [ ] Validate email before sending to Firestore

#### 10. Testing & Documentation
- [ ] Unit tests for PaymentValidator
- [ ] Integration tests for payment flow
- [ ] Error scenario testing
- [ ] Offline mode testing
- [ ] API documentation for custom exceptions

---

## Implementation Checklist Template

### Task: [Task Name]
- [ ] Read all affected files
- [ ] Identify validation/error points
- [ ] Add validator calls
- [ ] Add try-catch blocks
- [ ] Add user-facing error messages
- [ ] Test happy path
- [ ] Test error cases
- [ ] Test with poor network
- [ ] Update unit tests
- [ ] Code review

---

## Testing Production Readiness

### Manual Testing Scenarios:

**Scenario 1: Add Payment - Happy Path**
1. Open add payment form
2. Enter valid amount (Rs 5,000)
3. Select valid method (Cash)
4. Confirm submit
✓ Expect: Success snackbar + payment in history

**Scenario 2: Add Payment - Invalid Amount**
1. Enter Rs 0
✓ Expect: "Amount must be greater than zero" error
✓ Button should be disabled

**Scenario 3: Network Disconnected During Save**
1. Open airplane mode after clicking submit
✓ Expect: "Network error. Please try again" message
✓ Retry button appears
✓ Clicking retry attempts save again

**Scenario 4: Offline Dashboard Load**
1. Close app
2. Enable airplane mode
3. Reopen app
✓ Expect: Shows cached dashboard data
✓ "Offline" badge visible
✓ Refresh button available

**Scenario 5: Payment Status Update**
1. Click payment record
2. Change status from "unpaid" to "partial"
3. Enter valid installment amount
✓ Expect: Status updates, history refreshes

---

## Key Metrics for Production Readiness

Track these metrics to ensure quality:

- **Error Rate**: < 1% of operations
- **Retry Success Rate**: > 95% (should retry failed ops)
- **Offline Availability**: Works without internet
- **Load Time**: < 2 seconds (with cache)
- **Validation Coverage**: 100% (all inputs validated)
- **Exception Handling**: 100% (no unhandled exceptions)
- **Cache Hit Rate**: > 80% on repeat visits

---

##next Steps

1. **TODAY**: Implement tasks 1-5 (high priority)
2. **THIS WEEK**: Implement tasks 6-8 (medium priority)
3. **NEXT WEEK**: Complete tasks 9-10 + testing

**Estimated effort:** 20-30 hours for complete production readiness

---

## Questions?

- Payment exceptions: Check `payment_exceptions.dart`
- Validation rules: Check `production_validators.dart`
- Offline support: Check `offline_cache_service.dart`
- Integration: See Payment Service updates

All files have detailed comments for reference implementation.
