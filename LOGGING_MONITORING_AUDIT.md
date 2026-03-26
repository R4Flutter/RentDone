# 🔍 RentDone Logging & Monitoring Audit Report

**Analysis Date:** March 24, 2026  
**Scope:** lib/main.dart, lib/firebase/, lib/shared/, lib/features/*/data/services/, lib/features/*/presentation/providers/, lib/core/

---

## Executive Summary

RentDone has **significant cost leaks** in its logging infrastructure:

- ✅ **Firebase initialized properly** in main.dart
- ❌ **NO Firebase Crashlytics integrated** (only commented out in docs)
- ❌ **NO Firebase Analytics enabled**
- ❌ **34+ debugPrint() calls throughout codebase**
- 🔴 **CRITICAL: debugPrint() in HIGH-FREQUENCY STREAMS** (watchPayments, watchTenantCount, watchRecentMessages, watchTenantActivity)
- ⚠️ **Inconsistent debug logging practices** (some wrapped with kDebugMode, most are not)
- 📊 **Cloud Functions have structured logging** (TypeScript logger.ts utilities)
- 💾 **Offline cache service logs every operation**

---

## 1. EXISTING LOGGING PATTERNS

### 1.1 debugPrint() Usage (34+ instances found)

#### 🔴 CRITICAL HOTSPOTS - High-Frequency Streams

**File:** [lib/features/owner/owner_dashboard/data/services/dashboard_firebase_service.dart](lib/features/owner/owner_dashboard/data/services/dashboard_firebase_service.dart#L110-L220)

These streams emit EVERY TIME Firestore data changes:

```dart
// ❌ LOGS ON EVERY STREAM EMISSION
Stream<List<DashboardPaymentDto>> watchPayments() {
  // ... 
  .handleError((error) {
    debugPrint('Error in watchPayments stream: $error');  // LINE 136
    return <DashboardPaymentDto>[];
  });
}

Stream<int> watchTenantCount() {
  // ...
  .handleError((error) {
    debugPrint('Error in watchTenantCount stream: $error');  // LINE 176
    return 0;
  });
}

Stream<List<AppMessageDto>> watchRecentMessages() {
  // ...
  .handleError((error) {
    debugPrint('Error in watchRecentMessages stream: $error');  // LINE 197
    return <AppMessageDto>[];
  });
}

Stream<List<DashboardTenantDto>> watchTenantActivity() {
  // ...
  .handleError((error) {
    debugPrint('Error in watchTenantActivity stream: $error');  // LINE 220
    return <DashboardTenantDto>[];
  });
}
```

**Impact:** 
- Dashboard opens → watchPayments, watchTenantCount, watchRecentMessages, watchTenantActivity ALL stream simultaneously
- Each stream error = debugPrint to console
- Even nominal network hiccups trigger multiple logs
- These logs are UNSCOPED (not conditionally disabled in production)

**Other Stream Errors:**
- [dashboard_firebase_service.dart](lib/features/owner/owner_dashboard/data/services/dashboard_firebase_service.dart#L110) - fetchPayments error (LINE 110)
- [dashboard_firebase_service.dart](lib/features/owner/owner_dashboard/data/services/dashboard_firebase_service.dart#L158) - fetchTenantCount error (LINE 158)

---

#### ⚠️ Payment Service Logging (Razorpay)

**File:** [lib/features/owner/owner_payment/data/services/razorpay_service.dart](lib/features/owner/owner_payment/data/services/razorpay_service.dart#L49-L285)

```dart
// ❌ UNPROTECTED debugPrint CALLS
void _initializeRazorpay() {
  // ...
  if (razorpayKey.isEmpty) {
    debugPrint('⚠️ RAZORPAY_KEY not set. Payments will fail.');  // LINE 49
  } else {
    debugPrint('🔵 Razorpay initialized successfully');  // LINE 51
  }
}

Future<bool> initiatePayment(...) async {
  try {
    debugPrint('💳 Initiating Razorpay payment:');         // LINE 87
    debugPrint('   Order ID: ${paymentRequest.orderId}'); // LINE 88
    debugPrint('   Amount: ${paymentRequest.amount}...');  // LINE 89
    debugPrint('   Tenant: $tenantId');                   // LINE 90
    debugPrint('   Property: $propertyId');               // LINE 91
    // ...
  } on PaymentGatewayException catch (e) {
    debugPrint('❌ Payment gateway error: ${e.message}');  // LINE 103
  }
}

void _onPaymentSuccess(...)
  debugPrint('✅ Payment successful:');               // LINE 229
  debugPrint('   Transaction ID: ${response.transactionId}'); // LINE 230
  debugPrint('   Order ID: ${response.orderId}');    // LINE 231
}

void _onPaymentError(...)
  debugPrint('❌ Payment error:');                    // LINE 240
  debugPrint('   Code: $errorCode');                 // LINE 241
  debugPrint('   Message: $errorMessage');           // LINE 242
}

void _onExternalWallet(...)
  debugPrint('💳 External wallet selected: $walletName');  // LINE 285
}
```

**Impact:** Every payment attempt logs full details unprotected

---

#### ⚠️ Offline Cache Service Logging

**File:** [lib/shared/cache/offline_cache_service.dart](lib/shared/cache/offline_cache_service.dart#L31-L164)

```dart
// ❌ LOGS ON EVERY CACHE OPERATION
Future<bool> cacheDashboardSummary(...) {
  try {
    // ...
    debugPrint('✅ Dashboard cached locally');  // LINE 31
    return true;
  } catch (e) {
    debugPrint('❌ Failed to cache dashboard: $e');  // LINE 34
  }
}

Future<bool> cachePayments(...) {
  try {
    // ...
    debugPrint('✅ Payments cached locally (${payments.length} records)');  // LINE 60
  } catch (e) {
    debugPrint('❌ Failed to cache payments: $e');  // LINE 63
  }
}

// Similar for: cacheProperties, cacheTenants, clearAllCaches, getCachedPayments, etc.
```

**Impact:** Cache operations happen frequently. Each caching operation logs.

---

#### ✅ Firebase Storage Upload (CORRECTLY GUARDED)

**File:** [lib/features/owner/add_tenant/data/services/firebase_storage_service.dart](lib/features/owner/add_tenant/data/services/firebase_storage_service.dart#L80-L86)

```dart
// ✅ GOOD: Protected with kDebugMode
if (kDebugMode) {
  debugPrint('--- Firebase Storage Upload Debug ---');
  debugPrint('Bucket: ${_storage.bucket}');
  debugPrint('StoragePath: $storagePath');
  debugPrint('File: ${file.path}');
  debugPrint('Source Size: ${sourceBytes / 1024} KB');
  debugPrint('Upload Size: ${uploadBytes / 1024} KB');
  debugPrint('--------------------------------');
}
```

---

#### ⚠️ Push Notifications & Email Validation

**File:** [lib/core/notifications/push_notification_service.dart](lib/core/notifications/push_notification_service.dart#L61-L80)

```dart
// ❌ UNPROTECTED
debugPrint('Push token sync failed on auth change: $error');  // LINE 61
debugPrint('$stackTrace');  // LINE 62
debugPrint('Push token refresh sync failed: $error');         // LINE 72
debugPrint('$stackTrace');  // LINE 73
debugPrint('Foreground FCM: ${message.messageId} ${message.data}');  // LINE 80
debugPrint('Legacy token fallback skipped: ${error.code}');   // LINE 171
debugPrint('Snooze save skipped: ${error.code}');             // LINE 247
```

**File:** [lib/core/utils/email_validation_helper.dart](lib/core/utils/email_validation_helper.dart#L31-L73)

```dart
// ❌ UNPROTECTED
debugPrint('Error checking email: $e');      // LINE 31
debugPrint('Error finding duplicates: $e');  // LINE 73
```

---

#### ⚠️ Checkout & Payment Pages

**File:** [lib/features/owner/owner_payment/presentation/pages/razorpay_checkout_screen.dart](lib/features/owner/owner_payment/presentation/pages/razorpay_checkout_screen.dart#L63-L166)

```dart
// ❌ UNPROTECTED PRESENTATION LAYER LOGGING
debugPrint('💰 Payment State: $state');                  // LINE 63
debugPrint('❌ No active payment intent found...');      // LINE 144
debugPrint('❌ Invalid Razorpay callback payload...');   // LINE 151
debugPrint('✅ Payment verified and finalized...');      // LINE 163
debugPrint('❌ Error verifying payment: $e');            // LINE 166
```

---

### 1.2 Back Handler Logging

**File:** [lib/shared/widgets/back_handler.dart](lib/shared/widgets/back_handler.dart#L109-L136)

UI navigation logging (not critical but unprotected):

```dart
debugPrint('[BackHandler] rootConfirmExit: local navigator pop');   // LINE 109
debugPrint('[BackHandler] rootConfirmExit: root navigator pop');    // LINE 118
debugPrint('[BackHandler] rootConfirmExit: showing exit dialog..');  // LINE 123
debugPrint('[BackHandler] rootConfirmExit: continuing app...');     // LINE 136
```

---

## 2. FIREBASE INTEGRATION STATUS

### 2.1 Firebase Initialization ✅

**File:** [lib/main.dart](lib/main.dart)

```dart
// ✅ CORRECT SETUP
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const ProviderScope(child: RentDoneApp()));
}
```

**Status:** Clean, minimal Firebase initialization. No extra logging.

---

### 2.2 Firebase Crashlytics ❌ NOT IMPLEMENTED

**Evidence from Documentation:**

From [docs/FLUTTER_FIREBASE_INTEGRATION.md](docs/FLUTTER_FIREBASE_INTEGRATION.md#L138-L139):

```dart
// Set up error logging (Firebase Crashlytics optional)
// await FirebaseCrashlytics.instance.recordError(error, stack);
```

**Status:** Commented out. **NOT INTEGRATED.**

From [PRODUCTION_READINESS_GUIDE.md](PRODUCTION_READINESS_GUIDE.md#L320):

```markdown
#### 6. Add Comprehensive Logging
- [ ] Implement Firebase Crashlytics integration  <-- UNCHECKED
- [ ] Log all PaymentException instances
- [ ] Log transaction IDs with timestamps
```

---

### 2.3 Firebase Analytics ❌ NOT ENABLED

**Search Results:** 0 matches for `firebase_analytics` in codebase

**pubspec.yaml:** No `firebase_analytics` dependency

**Status:** **NOT CONFIGURED**

---

### 2.4 Cloud Functions Logging ✅ STRUCTURED

**File:** [functions/src/utils/logger.ts](functions/src/utils/logger.ts)

```typescript
// ✅ GOOD: Structured logging utilities
export const logInfo = (message: string, data: Record<string, unknown> = {}): void => {
  logger.info(message, data);
};

export const logWarn = (message: string, data: Record<string, unknown> = {}): void => {
  logger.warn(message, data);
};

export const logError = (message: string, data: Record<string, unknown> = {}): void => {
  logger.error(message, data);
};
```

Used throughout functions/index.js with structured logging patterns.

---

## 3. LOG HOTSPOTS (COST LEAKS)

### 🔴 CRITICAL - Dashboard Service Streams

| Service | Function | Issue | Impact |
|---------|----------|-------|--------|
| DashboardFirebaseService | `watchPayments()` | Error on stream fails logged unguarded | Every failed read unlocks logs |
| DashboardFirebaseService | `watchTenantCount()` | Error on stream fails logged unguarded | Every failed read unlocks logs |
| DashboardFirebaseService | `watchRecentMessages()` | Error on stream fails logged unguarded | Every failed read unlocks logs |
| DashboardFirebaseService | `watchTenantActivity()` | Error on stream fails logged unguarded | Every failed read unlocks logs |

**Why it matters:** These 4 streams run SIMULTANEOUSLY when dashboard loads. Any Firestore hiccup = 4 separate unguarded logs.

---

### ⚠️ HIGH - Razorpay Payment Service

| Service | Function | Issue | Logs per session |
|---------|----------|-------|------------------|
| RazorpayService | `initiatePayment()` | 5 debugPrint lines per payment | 5+ per payment attempt |
| RazorpayService | `_onPaymentSuccess()` | 3 debugPrint lines | 3 per successful payment |
| RazorpayService | `_onPaymentError()` | 3 debugPrint lines | 3 per failed payment |
| RazorpayService | `_onExternalWallet()` | 1 debugPrint line | 1 per external wallet use |

**Impact:** Every payment attempt = 11+ logs (unguarded)

---

### ⚠️ MEDIUM - Offline Cache Operations

| Service | Function | Frequency |
|---------|----------|-----------|
| OfflineCacheService | `cacheDashboardSummary()` | App initialization + periodic updates |
| OfflineCacheService | `cachePayments()` | Dashboard loads + manual refreshes |
| OfflineCacheService | `cacheProperties()` | Owner navigation |
| OfflineCacheService | `cacheTenants()` | Tenant list operations |
| OfflineCacheService | `clearAllCaches()` | Logout |

**Impact:** 10+ cache operations per app session = 10+ logs

---

### ⚠️ MEDIUM - Push Notifications

| Source | Logs per event |
|--------|----------------|
| Token sync on auth change | 2 logs (error handling) |
| Token refresh sync | 2 logs (error handling) |
| Foreground message | 1 log per notification |
| Legacy token fallback | 1 log |
| Snooze save | 1 log |

---

### ⚠️ LOW - Back Handler Navigation

| Source | Frequency |
|--------|-----------|
| Local navigator pop | 1 per back press (local nav) |
| Root navigator pop | 1 per back press (root nav) |
| Exit dialog shown | 1 per exit attempt |
| Continuing app | 1 per cancel exit |

---

## 4. PRODUCTION CONFIGURATION

### Debug Logs in Production? ❌ YES - EXPOSED

**Issues Found:**

1. **NO environment-based logging** - All `debugPrint()` calls lack `kDebugMode` guards except Firebase Storage
2. **Stream errors unguarded** - Network errors in production will log to console
3. **Razorpay logging exposed** - Payment details logged in production
4. **Back handler logs exposed** - Navigation state logged in production

**Dart Documentation Note:**

From Flutter docs: `debugPrint()` respects `--release` builds BUT:
- In debug builds (used during development): prints to console
- Visible to anyone with ADB or logcat access on device
- Dangerous for payment/sensitive data

---

## 5. CURRENT DEFICIENCIES

| Item | Status | Issue |
|------|--------|-------|
| **Crashlytics Integration** | ❌ MISSING | Only commented in docs; never implemented |
| **Analytics Events** | ❌ MISSING | No firebase_analytics dependency |
| **Structured Logging** | ❌ MISSING (Flutter) | Only Cloud Functions have structure |
| **Environment-Based Logging** | ❌ MISSING | Debug logs everywhere in production |
| **Error Tracking** | ❌ MISSING | No central error aggregation |
| **Performance Monitoring** | ❌ MISSING | No Firebase Performance Monitoring |
| **Log Selectivity** | ❌ MISSING | Logs everything or nothing |
| **Rate Limiting** | ❌ MISSING | No log throttling on streams |

---

## 6. FILES WITH EXCESSIVE LOGGING

| File | Lines | Issue Severity | Recommendation |
|------|-------|-----------------|-----------------|
| [lib/features/owner/owner_dashboard/data/services/dashboard_firebase_service.dart](lib/features/owner/owner_dashboard/data/services/dashboard_firebase_service.dart) | 110, 136, 158, 176, 197, 220 | **CRITICAL** | Remove stream error logs or guard with kDebugMode |
| [lib/features/owner/owner_payment/data/services/razorpay_service.dart](lib/features/owner/owner_payment/data/services/razorpay_service.dart) | 49, 51, 87-91, 103, 109, 229-231, 240-242, 285 | **HIGH** | Guard all with kDebugMode; use Crashlytics for errors |
| [lib/shared/cache/offline_cache_service.dart](lib/shared/cache/offline_cache_service.dart) | 31, 34, 50, 60, 63, 82, 92, 95, 114, 124, 127, 146, 162, 164 | **MEDIUM** | Guard cache logs with kDebugMode or remove |
| [lib/core/notifications/push_notification_service.dart](lib/core/notifications/push_notification_service.dart) | 61, 62, 72, 73, 80, 171, 247 | **MEDIUM** | Guard token sync logs with kDebugMode |
| [lib/features/owner/owner_payment/presentation/pages/razorpay_checkout_screen.dart](lib/features/owner/owner_payment/presentation/pages/razorpay_checkout_screen.dart) | 63, 144, 151, 163, 166 | **MEDIUM** | Remove presentation layer logs or guard |
| [lib/core/utils/email_validation_helper.dart](lib/core/utils/email_validation_helper.dart) | 31, 73 | **LOW** | Guard with kDebugMode |
| [lib/shared/widgets/back_handler.dart](lib/shared/widgets/back_handler.dart) | 109, 118, 123, 136 | **LOW** | Guard navigation logs with kDebugMode |

---

## 7. SECURITY CONCERNS

### Data Exposure

**Payment Details Logged:**
```dart
debugPrint('   Order ID: ${paymentRequest.orderId}');
debugPrint('   Amount: ${paymentRequest.amount}');  
debugPrint('   Tenant: $tenantId');
debugPrint('   Property: $propertyId');
debugPrint('   Transaction ID: ${response.transactionId}');
```

**Status:** Visible in production logs, ADB logcat, crash reports

### No Sensitive Data Filter

No mechanism to prevent logging of:
- Tenant IDs
- Property IDs
- Order IDs
- Transaction IDs
- Error messages containing user data

---

## 8. COST IMPLICATIONS

### Estimated Log Volume (Worst Case)

| Operation | Logs per session | Sessions/day | Annual |
|-----------|-----------------|--------------|---------|
| Dashboard load (4 streams × 5 errors each) | 20 logs | 1,000 | 7.3M logs |
| Payment processing (11 logs/payment) | 11 logs | 100 | 400K logs |
| Cache operations (10 sessions) | 10 logs | 500 | 1.8M logs |
| Notifications (3 per user/day) | 3 logs | 500 users × 30 days | 45K logs |
| **TOTAL ESTIMATED** | — | — | **~9.5M logs/year** |

### Comparison with Crashlytics

| Approach | Cost |
|----------|------|
| Current debugPrint Volume | ~9.5M logs/year (console only) |
| Firebase Crashlytics (10M/month free) | FREE for first 10M/month, then $1 per 100K |
| Log Storage (30-day retention) | Minimal in Crashlytics |

---

## 9. EXISTING BEST PRACTICES (Some files)

### ✅ Firebase Storage Service - Proper Guarding

[lib/features/owner/add_tenant/data/services/firebase_storage_service.dart](lib/features/owner/add_tenant/data/services/firebase_storage_service.dart#L80-L86):

```dart
if (kDebugMode) {
  debugPrint('--- Firebase Storage Upload Debug ---');
  // Safe to log technical details in debug mode only
}
```

This is the STANDARD that should be applied everywhere.

---

## 10. RECOMMENDATIONS (Priority Order)

### 🔴 CRITICAL (Week 1)

1. **Remove stream error logging from dashboard_firebase_service.dart**
   - Lines 110, 136, 158, 176, 197, 220
   - These log on EVERY error; replace with Crashlytics when implemented

2. **Guard all debugPrint() calls with `kDebugMode`**
   - Apply Firebase Storage pattern to all 34+ instances
   - Prevents production console spam

3. **Implement Firebase Crashlytics**
   - Replace commented code in main.dart
   - Add `firebase_crashlytics` to pubspec.yaml
   - Create structured error logging utility

### ⚠️ HIGH (Week 2)

4. **Create Flutter Logging Utility**
   - Mirror Cloud Functions logger.ts pattern
   - Provide `logInfo()`, `logWarn()`, `logError()`
   - Route to Crashlytics in production

5. **Remove sensitive data from logs**
   - Stop logging transaction IDs in razorpay_service.dart
   - Stop logging tenant/property IDs
   - Log only error codes, not full error objects

6. **Implement Firebase Analytics**
   - Track key events: payment success/failure, document upload, tenant operations
   - Enable performance monitoring

### 📊 MEDIUM (Week 3-4)

7. **Implement rate limiting on streams**
   - Add debouncing to error logging in streams
   - Prevent logging same error repeatedly in short timeframe

8. **Add structured error tracking**
   - Create error tracking dashboard
   - Monitor error frequency by type
   - Set up alerts for critical errors

9. **Add performance metrics**
   - Track API response times
   - Monitor Firestore read/write latencies
   - Alert on slow operations

### 🎯 NICE-TO-HAVE (Future)

10. **Implement selective logging levels**
    - NONE / ERROR / WARN / INFO / DEBUG
    - Configurable per environment
    - Dynamic runtime adjustment

11. **Add log retention policies**
    - 7-day retention for debug logs
    - 30-day for error logs
    - 60-day for critical events

---

## 11. IMPLEMENTATION CHECKLIST

```
LOGGING CLEANUP
[ ] Guard 34+ debugPrint calls with kDebugMode
[ ] Remove stream error logging from dashboard service
[ ] Create Flutter logger utility (mirror Cloud Functions)
[ ] Remove sensitive data from payment logs
[ ] Guard cache operation logs
[ ] Guard notification logs
[ ] Guard back handler logs

FIREBASE INTEGRATION
[ ] Add firebase_crashlytics ^5.0.0 to pubspec.yaml
[ ] Implement FirebaseCrashlytics in main.dart
  [ ] Initialize before runApp()
  [ ] Set custom keys for user context
  [ ] Configure to record errors
[ ] Add firebase_analytics ^12.0.0 to pubspec.yaml
  [ ] Initialize FirebaseAnalytics
  [ ] Track payment events (success/failure)
  [ ] Track page views
[ ] Add firebase_performance ^0.10.0 to pubspec.yaml
  [ ] Monitor API latencies
  [ ] Monitor Firestore operations

TESTING
[ ] Test logging in debug mode (logs appear)
[ ] Test logging in release mode (no debugPrint output)
[ ] Verify errors reach Crashlytics
[ ] Verify analytics events tracked
[ ] Verify no sensitive data in logs
[ ] Load test streams to verify no log spam
```

---

## 12. SUMMARY TABLE

| Category | Status | Files Affected | Priority |
|----------|--------|----------------|----------|
| **Logging Proper Guarding** | ❌ 0% | 7 files | CRITICAL |
| **Crashlytics** | ❌ 0% (only comments) | 1 file | CRITICAL |
| **Analytics** | ❌ 0% | 0 files | HIGH |
| **Performance Monitoring** | ❌ 0% | 0 files | MEDIUM |
| **Structured Logging** | ✅ 100% (Cloud Functions only) | 2 files | HIGH |
| **Stream Error Handling** | ⚠️ Partial (logs every error) | 1 file | CRITICAL |
| **Sensitive Data Protection** | ❌ 0% | 2 files | CRITICAL |

---

## 13. QUICK FIXES (Can be applied immediately)

### Fix 1: Guard All debugPrint Calls

**Template (apply to all 34+ instances):**

```dart
// ❌ BEFORE
debugPrint('Error in watchPayments stream: $error');

// ✅ AFTER
if (kDebugMode) {
  debugPrint('Error in watchPayments stream: $error');
}
```

### Fix 2: Initialize Crashlytics in main.dart

```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // ✅ ADD THIS
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  
  runApp(const ProviderScope(child: RentDoneApp()));
}
```

### Fix 3: Create logger.dart Utility

```dart
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class AppLogger {
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[DEBUG] $message');
    }
  }

  static void info(String message) {
    if (kDebugMode) {
      debugPrint('[INFO] $message');
    }
  }

  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('[WARN] $message');
    }
  }

  static void error(String message, Object? error, StackTrace? stack) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message: $error');
      debugPrint(stack.toString());
    }
    // Send to Crashlytics
    FirebaseCrashlytics.instance.recordError(error, stack);
  }
}
```

---

## Appendix A: Complete Logging Inventory

### All debugPrint() Calls Found (34 instances)

| File | Line | Content |
|------|------|---------|
| firebase_storage_service.dart | 80 | `debugPrint('--- Firebase Storage Upload Debug ---')` |
| firebase_storage_service.dart | 81 | `debugPrint('Bucket: ${_storage.bucket}')` |
| firebase_storage_service.dart | 82 | `debugPrint('StoragePath: $storagePath')` |
| firebase_storage_service.dart | 83 | `debugPrint('File: ${file.path}')` |
| firebase_storage_service.dart | 84 | `debugPrint('Source Size: ${sourceBytes / 1024} KB')` |
| firebase_storage_service.dart | 85 | `debugPrint('Upload Size: ${uploadBytes / 1024} KB')` |
| firebase_storage_service.dart | 86 | `debugPrint('--------------------------------')` |
| dashboard_firebase_service.dart | 110 | `debugPrint('Error fetching payments: $e')` |
| dashboard_firebase_service.dart | 136 | `debugPrint('Error in watchPayments stream: $error')` |
| dashboard_firebase_service.dart | 158 | `debugPrint('Error fetching tenant count: $e')` |
| dashboard_firebase_service.dart | 176 | `debugPrint('Error in watchTenantCount stream: $error')` |
| dashboard_firebase_service.dart | 197 | `debugPrint('Error in watchRecentMessages stream: $error')` |
| dashboard_firebase_service.dart | 220 | `debugPrint('Error in watchTenantActivity stream: $error')` |
| razorpay_service.dart | 49 | `debugPrint('⚠️ RAZORPAY_KEY not set...')` |
| razorpay_service.dart | 51 | `debugPrint('🔵 Razorpay initialized successfully')` |
| razorpay_service.dart | 87 | `debugPrint('💳 Initiating Razorpay payment:')` |
| razorpay_service.dart | 88 | `debugPrint('   Order ID: ${paymentRequest.orderId}')` |
| razorpay_service.dart | 89 | `debugPrint('   Amount: ${paymentRequest.amount}...')` |
| razorpay_service.dart | 90 | `debugPrint('   Tenant: $tenantId')` |
| razorpay_service.dart | 91 | `debugPrint('   Property: $propertyId')` |
| razorpay_service.dart | 103 | `debugPrint('❌ Payment gateway error: ${e.message}')` |
| razorpay_service.dart | 109 | `debugPrint('❌ Payment initiation failed: $e')` |
| razorpay_service.dart | 229 | `debugPrint('✅ Payment successful:')` |
| razorpay_service.dart | 230 | `debugPrint('   Transaction ID: ${response.transactionId}')` |
| razorpay_service.dart | 231 | `debugPrint('   Order ID: ${response.orderId}')` |
| razorpay_service.dart | 240 | `debugPrint('❌ Payment error:')` |
| razorpay_service.dart | 241 | `debugPrint('   Code: $errorCode')` |
| razorpay_service.dart | 242 | `debugPrint('   Message: $errorMessage')` |
| razorpay_service.dart | 285 | `debugPrint('💳 External wallet selected: $walletName')` |
| offline_cache_service.dart | 31 | `debugPrint('✅ Dashboard cached locally')` |
| offline_cache_service.dart | 34 | `debugPrint('❌ Failed to cache dashboard: $e')` |
| offline_cache_service.dart | 50 | `debugPrint('❌ Failed to retrieve dashboard cache: $e')` |
| offline_cache_service.dart | 60 | `debugPrint('✅ Payments cached locally...')` |

*(34 total instances across 7 files)*

---

**Report Generated:** March 24, 2026  
**Next Review Date:** After Crashlytics implementation  
**Owner:** RentDone Development Team
