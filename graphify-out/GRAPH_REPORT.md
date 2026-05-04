# Graph Report - functions  (2026-05-04)

## Corpus Check
- Corpus is ~23,747 words - fits in a single context window. You may not need a graph.

## Summary
- 182 nodes · 254 edges · 33 communities detected
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 3 edges (avg confidence: 0.9)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Core Utilities & Helper Functions|Core Utilities & Helper Functions]]
- [[_COMMUNITY_Notification & Rate Limiting Services|Notification & Rate Limiting Services]]
- [[_COMMUNITY_Payment Integrity & Validation|Payment Integrity & Validation]]
- [[_COMMUNITY_Payment Notification Dispatch|Payment Notification Dispatch]]
- [[_COMMUNITY_Payment Callable Triggers|Payment Callable Triggers]]
- [[_COMMUNITY_Functions Index & Domain Models|Functions Index & Domain Models]]
- [[_COMMUNITY_Firebase & Trigger Utilities|Firebase & Trigger Utilities]]
- [[_COMMUNITY_Notification & Payment Triggers Rationale|Notification & Payment Triggers Rationale]]
- [[_COMMUNITY_Fee Calculation & Config|Fee Calculation & Config]]
- [[_COMMUNITY_Email Cleanup & Security|Email Cleanup & Security]]
- [[_COMMUNITY_Auth & Security Headers|Auth & Security Headers]]
- [[_COMMUNITY_Cleanup & Storage Tasks|Cleanup & Storage Tasks]]
- [[_COMMUNITY_Validation Service|Validation Service]]
- [[_COMMUNITY_WhatsApp Messaging|WhatsApp Messaging]]
- [[_COMMUNITY_Payment Trigger Helpers|Payment Trigger Helpers]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]

## God Nodes (most connected - your core abstractions)
1. `logInfo()` - 7 edges
2. `logWarn()` - 7 edges
3. `logError()` - 7 edges
4. `dispatchPaymentReceivedNotification()` - 6 edges
5. `sendMulticastWithRetry()` - 6 edges
6. `Payment Firestore Trigger` - 6 edges
7. `getSecurityConfig()` - 5 edges
8. `checkAndIncrementRateLimit()` - 5 edges
9. `validatePaymentForNotification()` - 5 edges
10. `Firebase Utility` - 5 edges

## Surprising Connections (you probably didn't know these)
- `Notification Service` --conceptually_related_to--> `Firebase Functions Index (V1)`  [INFERRED]
  functions/lib/services/notificationService.js → functions/index.js
- `Rate Limit Service` --references--> `Firebase Utility`  [EXTRACTED]
  functions/lib/src/services/rateLimitService.js → functions/lib/src/utils/firebase.js
- `Payment Firestore Trigger` --calls--> `Rate Limit Service`  [EXTRACTED]
  functions/lib/src/triggers/paymentTrigger.js → functions/lib/src/services/rateLimitService.js
- `Validation Service` --references--> `Firebase Utility`  [EXTRACTED]
  functions/lib/src/services/validationService.js → functions/lib/src/utils/firebase.js
- `Payment Firestore Trigger` --calls--> `Validation Service`  [EXTRACTED]
  functions/lib/src/triggers/paymentTrigger.js → functions/lib/src/services/validationService.js

## Hyperedges (group relationships)
- **Notification Dispatch Pipeline** — notificationservice_reservenotificationevent, ratelimitservice_checkandincrementratelimit, notificationservice_sendmulticastwithretry [INFERRED 0.95]

## Communities (42 total, 18 thin omitted)

### Community 1 - "Notification & Rate Limiting Services"
Cohesion: 0.15
Nodes (17): buildRentDueBody(), dueDateKey(), getTenantUserId(), loadDueTenants(), statusString(), toIstNow(), isInvalidTokenError(), isTransientError() (+9 more)

### Community 2 - "Payment Integrity & Validation"
Cohesion: 0.18
Nodes (11): blockDuplicatePaymentOrThrow(), buildPaymentLogPayload(), getLeaseOrTenantPaymentContext(), logPaymentEvent(), logPaymentIntegrityEvent(), normalizeIntegerAmount(), normalizeLogNumber(), normalizeLogString() (+3 more)

### Community 3 - "Payment Notification Dispatch"
Cohesion: 0.25
Nodes (8): amountInr(), dispatchPaymentReceivedNotification(), isPaidLikeStatus(), isUnpaidStatus(), normalizePaymentStatus(), reserveNotificationEvent(), sendPushMulticast(), shouldSendUserNotification()

### Community 4 - "Payment Callable Triggers"
Cohesion: 0.5
Nodes (6): asInt(), assertAccessAndOwnership(), assertAmountOrThrow(), asString(), logPaymentEvent(), normalizeMethod()

### Community 5 - "Functions Index & Domain Models"
Cohesion: 0.25
Nodes (8): Firestore: payments, Firestore: properties, Firestore: tenants, Firebase Functions Index (V1), Firebase Functions Lib Index, Rent Reminder Scheduler, Notification Service, Rate Limit Service

### Community 6 - "Firebase & Trigger Utilities"
Cohesion: 0.43
Nodes (8): Firebase Utility, Logger Utility, Notification Service, Payment Callable Triggers, Payment Firestore Trigger, Rate Limit Service, Token Service, Validation Service

### Community 7 - "Notification & Payment Triggers Rationale"
Cohesion: 0.29
Nodes (7): reserveNotificationEvent, sendMulticastWithRetry, onPaymentCreated Trigger, checkAndIncrementRateLimit, Notification Idempotency Pattern, sendRentDueReminders Scheduler, validatePaymentForNotification

### Community 8 - "Fee Calculation & Config"
Cohesion: 0.4
Nodes (6): calculateFeeBreakdownInPaise(), ceilDivide(), defaultPaymentFeeConfig(), loadPaymentFeeConfig(), parsePercent(), percentToBps()

### Community 9 - "Email Cleanup & Security"
Cohesion: 0.6
Nodes (3): assertAdminCallableAuth(), getSecurityConfig(), parseBool()

### Community 10 - "Auth & Security Headers"
Cohesion: 0.4
Nodes (5): assertCallableAuth(), getSecurityConfig(), parseBool(), setCorsHeaders(), verifyHttpAppCheckOrThrow()

### Community 11 - "Cleanup & Storage Tasks"
Cohesion: 0.4
Nodes (5): cleanupOldReportExports(), cleanupOrphanTenantDocumentFiles(), deleteStoragePathIfExists(), dueDateLabel(), toDate()

### Community 13 - "WhatsApp Messaging"
Cohesion: 0.5
Nodes (4): getWhatsAppConfig(), postWhatsAppMessage(), sendWhatsAppMessage(), sleep()

### Community 16 - "Community 16"
Cohesion: 1.0
Nodes (3): minuteBucketKey(), rateLimitOrThrow(), recordSecuritySignal()

### Community 17 - "Community 17"
Cohesion: 0.67
Nodes (3): hasAnyFieldChanged(), shouldRecomputeOwnerSummaryForPaymentWrite(), shouldRecomputeOwnerSummaryForPropertyWrite()

### Community 18 - "Community 18"
Cohesion: 0.67
Nodes (3): Firestore: users, Email Duplicate Cleanup Functions, Gravatar Migration Functions

## Knowledge Gaps
- **22 isolated node(s):** `Email Duplicate Cleanup Functions`, `Gravatar Migration Functions`, `Firebase Functions Lib Index`, `Rate Limit Service`, `Validation Service` (+17 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **18 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `validatePaymentForNotification()` connect `Validation Service` to `Notification & Rate Limiting Services`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **Why does `logInfo()` connect `Notification & Rate Limiting Services` to `Payment Callable Triggers`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **Why does `logWarn()` connect `Notification & Rate Limiting Services` to `Payment Callable Triggers`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **What connects `Email Duplicate Cleanup Functions`, `Gravatar Migration Functions`, `Firebase Functions Lib Index` to the rest of the system?**
  _22 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Core Utilities & Helper Functions` be split into smaller, more focused modules?**
  _Cohesion score 0.07 - nodes in this community are weakly interconnected._