# Firestore Cost Optimization - Production Implementation

## 1) Optimized Schema Design

### Denormalized owner summary
Collection: owners_summary
Document ID: {ownerId}

Fields:
- ownerId
- totalProperties
- vacantProperties
- totalTenants
- collectedAmount
- collectedPayments
- pendingAmount
- pendingPayments
- pendingTenants
- cashAmount
- onlineAmount
- totalRent
- pendingRent
- paidRent
- tenantCount
- lastPaymentDate
- lastUpdated

Why this helps:
- Dashboard reads a single document instead of full properties + payments + tenants collections.
- Read amplification drops significantly for high-frequency dashboard opens.

### Lightweight list + detail split
- Keep list-friendly fields in primary collections used by list screens.
- Store heavy payloads and rarely used nested data in detail/subcollections.
- Fetch detail only on detail view.

## 2) Flutter Pagination Example (limit + cursor)

```dart
Future<List<T>> fetchPage({
  required Query<Map<String, dynamic>> baseQuery,
  required int pageSize,
  DocumentSnapshot<Map<String, dynamic>>? lastDoc,
}) async {
  Query<Map<String, dynamic>> query = baseQuery.limit(pageSize);
  if (lastDoc != null) {
    query = query.startAfterDocument(lastDoc);
  }

  final snap = await query.get();
  // Save for next page
  final nextCursor = snap.docs.isNotEmpty ? snap.docs.last : null;
  // Convert docs to model and return
  return snap.docs.map((d) => mapper(d)).toList();
}
```

Client guidelines:
- Use page size 10 to 25.
- Keep one in-flight request guard to prevent duplicate fetch calls.
- Trigger next page only when scroll threshold is reached.

## 3) Summary Update Logic (Implemented)

Implemented in Cloud Functions:
- syncOwnerSummaryOnPaymentWrite
- syncOwnerSummaryOnTenantWrite
- syncOwnerSummaryOnPropertyWrite

Each trigger recomputes the owner summary and upserts owners_summary/{ownerId}.

Computation includes:
- Monthly collected and pending rent
- Tenant/property counts
- Cash vs online split
- lastPaymentDate

## 4) Listener vs Fetch Decision Matrix

| Screen/Use case | Pattern | Rationale |
|---|---|---|
| Owner dashboard summary | Listener on owners_summary/{ownerId} | Small single-doc stream, low read cost |
| Messages/notifications feed | Listener (limited + ordered) | Time-sensitive UX |
| Tenant/payment list screens | One-time paginated get | Avoid expensive live collection streams |
| Detail screens | One-time get (with optional manual refresh) | Low update frequency |
| Background/inactive screen | No listener | Prevent unnecessary reads |

Rules:
- Real-time listeners only for truly real-time UX.
- Dispose listeners immediately on screen exit.
- Prefer one-time get + pull-to-refresh for static/slow-changing views.

## 5) Batch Write Implementation Example

```dart
final batch = FirebaseFirestore.instance.batch();

final paymentRef = FirebaseFirestore.instance.collection('payments').doc();
final summaryRef = FirebaseFirestore.instance.collection('owners_summary').doc(ownerId);

batch.set(paymentRef, {
  'ownerId': ownerId,
  'tenantId': tenantId,
  'amount': amount,
  'status': 'paid',
  'createdAt': FieldValue.serverTimestamp(),
});

batch.set(summaryRef, {
  'paidRent': FieldValue.increment(amount),
  'totalRent': FieldValue.increment(amount),
  'lastUpdated': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));

await batch.commit();
```

Use transaction instead of batch when reads are required before write decisions.

## 6) Before vs After Cost Comparison (Estimated)

Assumptions per dashboard open:
- Before:
  - properties query + payments query + tenants query
  - Average reads around 120 to 1,200 docs depending on account size
- After:
  - one owners_summary document read

Estimated impact:
- Dashboard read reduction: 90%+
- Overall read reduction (app-wide): 50% to 70% with pagination + listener trimming
- Write overhead: +small increase from summary maintenance triggers
- Net cost trend: strongly positive for read-heavy workloads

## 7) What was implemented in this repo

- Owner dashboard now reads/watches owners_summary first with fallback compute.
- Summary fallback writes back to owners_summary for warm cache behavior.
- Owner dashboard message stream no longer combines multiple heavy collection listeners.
- Cloud Functions now keep owners_summary updated from payments/tenants/properties writes.

## 8) Next Production Steps

1. Deploy functions and rules:
   - firebase deploy --only functions,firestore:rules,firestore:indexes
2. Backfill existing owners_summary for all owners once (script or admin task).
3. Migrate remaining offset-based list APIs to cursor pagination.
4. Add analytics counters:
   - dashboard_summary_hits
   - dashboard_fallback_recompute
   - paginated_reads_per_screen
