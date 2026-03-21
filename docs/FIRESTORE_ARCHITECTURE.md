# 🏗️ RentDone Firestore Architecture Guide

**Professional Data Modeling & Best Practices**

---

## Overview

This document outlines the professional Firestore structure for RentDone, following Google Cloud best practices for NoSQL database design and naming conventions.

---

## 1. Collection Structure & Hierarchy

### Root Collections (Top-Level)

```
Firestore Database
├── users/                          # User authentication & profiles
├── owners/                         # Owner account details
├── properties/                     # Property listings
├── tenants/                        # Tenant profiles
│   └── {tenantId}/
│       ├── payments/              # Tenant-specific payments
│       ├── room_details/          # Room assignment for tenant
│       ├── owner_details/         # Property owner contact info
│       ├── documents/             # ID proofs, agreements, etc.
│       ├── complaints/            # Tenant grievances
│       └── reminders/             # Payment reminders
├── payments/                       # Payment transactions (root)
├── transactions/                   # Transaction history
├── messages/                       # Communication logs
├── leases/                        # Lease agreements
├── ownerPaymentProfiles/          # Stripe/Payment gateway data
├── ownerTrustScoreLookupQuota/    # API rate limiting
├── ownerTrustScoreLookupEvents/   # Trust score changes
├── tenantTrust/                   # Tenant reputation scores
└── fcmTokens/                     # Push notification tokens
```

---

## 2. Naming Conventions

### Collections
- **Format:** `snake_case` (lowercase with underscores)
- **Examples:** `users`, `properties`, `tenant_profiles`, `payment_history`
- **Rule:** Use plural form for collections
- ✅ Correct: `payments`, `transactions`, `messages`
- ❌ Incorrect: `payment`, `transaction`, `Message`

### Documents
- **Format:** `camelCase` or `UUID` (for auto-generated IDs)
- **ID Strategy:** Use `ownerId` (Firebase Auth UID) for user documents
- **Examples:**
  - `users/{userId}` where userId = Firebase Auth UID
  - `owners/{ownerId}` where ownerId = Firebase Auth UID
  - `properties/{propertyId}` where propertyId = auto-generated or meaningful UUID

### Fields
- **Format:** `camelCase` (lowercase start, capitalize subsequent words)
- **Examples:** `ownerId`, `tenantId`, `propertyId`, `createdAt`, `updatedAt`
- **Timestamps:** Always use `createdAt`, `updatedAt` with `FieldValue.serverTimestamp()`
- **Status Fields:** Use lowercase values: `active`, `inactive`, `pending`, `paid`, `unpaid`
- **ID References:** Always suffix with `Id`: `ownerId`, `tenantId`, `propertyId`

---

## 3. Collection-Level Data Models

### `users` - Authentication & Profiles
```json
{
  "uid": "firebase-auth-uid",              // ✅ IMMUTABLE: Firebase Auth UID
  "role": "owner|tenant",                  // ✅ IMMUTABLE: Cannot change after creation
  "email": "user@example.com",
  "emailLowercase": "user@example.com",    // For case-insensitive queries
  "name": "John Doe",
  "phone": "+919876543210",
  "photoUrl": "https://...",
  "gravatarUrl": "https://...",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "lastLoginAt": "timestamp"
}
```

**Indexes:** None (UID is primary key)

---

### `owners` - Property Owner Accounts
```json
{
  "ownerId": "firebase-uid",                     // ✅ IMMUTABLE
  "email": "owner@example.com",
  "name": "Owner Name",
  "phone": "+919876543210",
  "subscriptionPlan": "free|starter|pro",
  "currentTenantCount": 5,                       // Tenant quota tracking
  "tenantLimit": 10,                             // Plan-based limit
  "paymentStatus": "active|pending|cancelled",
  "subscriptionStartDate": "timestamp",
  "properties": [                                // Denormalized for quick access
    {
      "id": "propertyId",
      "name": "Property Name",
      "location": "City, Country"
    }
  ],
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

**Indexes:**
- `ownerId` + `createdAt DESC`
- `paymentStatus` + `createdAt DESC`

---

### `properties` - Real Estate Listings
```json
{
  "ownerId": "firebase-uid",               // ✅ IMMUTABLE
  "name": "Property Name",
  "location": "Full Address",
  "address": "Street Address",
  "city": "City Name",
  "state": "State/Province",
  "zipCode": "12345",
  "description": "Property description...",
  "totalRooms": 4,
  "status": "active|inactive|archived",
  "rooms": [
    {
      "id": "room-uuid",
      "name": "Master Bedroom",
      "roomNumber": "101",
      "monthlyRent": 15000,
      "status": "occupied|vacant"
    }
  ],
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

**Indexes:**
- `ownerId` + `status` + `createdAt DESC`
- `ownerId` + `createdAt DESC`

---

### `tenants` - Tenant Profiles
```json
{
  "ownerId": "firebase-uid",               // ✅ IMMUTABLE
  "propertyId": "property-uuid",           // ✅ IMMUTABLE
  "authUid": "tenant-firebase-uid",        // Tenant's Firebase Auth UID
  "email": "tenant@example.com",
  "emailLowercase": "tenant@example.com",
  "name": "Tenant Full Name",
  "fullName": "Tenant Full Name",
  "phone": "+919876543210",
  "phoneHash": "sha256-hash",              // For duplicate detection
  "roomId": "room-uuid",
  "roomNumber": "101",
  "rentAmount": 15000,
  "status": "active|inactive|terminated",
  "isActive": true,
  "onboardingStatus": "pending_assignment|assigned|completed",
  "idProofType": "aadhaar|pan|license",    // ✅ IMMUTABLE
  "idProofUrl": "https://...",             // ✅ IMMUTABLE
  "agreementUrl": "https://...",           // ✅ IMMUTABLE
  "additionalDocumentUrls": [],            // ✅ IMMUTABLE
  "trustScore": 750,
  "trustBadge": "platinum|gold|silver|bronze|none",
  "onTimePayments": 24,
  "latePayments": 2,
  "missedPayments": 0,
  "consecutiveOnTimeMonths": 12,
  "dueAmount": 0,
  "totalPaid": 0,
  "moveInDate": "2023-01-15",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

**Indexes:**
- `ownerId` + `status` + `createdAt DESC`
- `propertyId` + `status` + `createdAt DESC`
- `ownerId` + `isActive` + `createdAt DESC`

---

### `tenants/{tenantId}/payments` - Tenant Payment History
```json
{
  "paymentMonth": "2023-12",                // Format: YYYY-MM
  "amount": 15000,                          // In rupees (paise)
  "paymentMethod": "UPI|Cash|BankTransfer|Razorpay|CreditCard",
  "status": "paid|partial|unpaid|missed",
  "paymentDate": "2023-12-05",
  "dueDate": "2023-12-05",
  "baseAmount": 15000,
  "paidAmount": 15000,
  "remainingAmount": 0,
  "notes": "Payment notes...",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

---

### `payments` - Root Payment Collection
```json
{
  "ownerId": "firebase-uid",               // ✅ IMMUTABLE
  "tenantId": "tenant-uuid",               // ✅ IMMUTABLE
  "propertyId": "property-uuid",           // ✅ IMMUTABLE
  "amount": 15000,
  "baseAmount": 15000,
  "paidAmount": 15000,
  "remainingAmount": 0,
  "method": "UPI|Cash|BankTransfer|Razorpay|CreditCard",
  "status": "paid|partial|unpaid",
  "month": "2023-12",
  "date": "2023-12-05",
  "transactionId": "razorpay-transaction-id",
  "referenceId": "bank-reference",
  "notes": "Payment notes...",
  "installments": [
    {
      "amount": 15000,
      "date": "2023-12-05",
      "method": "UPI",
      "notes": null
    }
  ],
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

**Indexes:**
- `ownerId` + `createdAt DESC`
- `tenantId` + `createdAt DESC`
- `ownerId` + `status` + `createdAt DESC`
- `propertyId` + `createdAt DESC`

---

### `transactions` - Payment Transactions (Audit Trail)
```json
{
  "ownerId": "firebase-uid",
  "tenantId": "tenant-uuid",
  "propertyId": "property-uuid",
  "paymentId": "payment-uuid",
  "amount": 15000,
  "method": "UPI|Cash|BankTransfer|Razorpay",
  "status": "pending|processing|completed|failed|refunded",
  "transactionRef": "gateway-transaction-id",
  "gatewayResponse": { /* payment gateway response */ },
  "createdAt": "timestamp",
  "completedAt": "timestamp"
}
```

**Indexes:**
- `tenantId` + `createdAt DESC`
- `ownerId` + `createdAt DESC`
- `ownerId` + `status` + `createdAt DESC`
- `propertyId` + `createdAt DESC`

---

### `messages` - Communication Log
```json
{
  "ownerId": "firebase-uid",
  "tenantId": "tenant-uuid",
  "senderId": "sender-uid",
  "senderRole": "owner|tenant",
  "subject": "Message subject",
  "body": "Message content...",
  "type": "text|reminder|alert|notification",
  "isRead": false,
  "readAt": "timestamp",
  "attachments": [
    {
      "url": "https://...",
      "type": "image|pdf|document"
    }
  ],
  "createdAt": "timestamp"
}
```

**Indexes:**
- `ownerId` + `createdAt DESC`
- `tenantId` + `createdAt DESC`
- `ownerId` + `isRead` + `createdAt DESC`

---

### `tenantTrust` - Reputation/Trust Scores
```json
{
  // Document ID = tenant phone number (e.g., "+919876543210")
  "phone": "+919876543210",
  "trustScore": 750,
  "trustBadge": "platinum",
  "onTimePayments": 24,
  "latePayments": 2,
  "missedPayments": 0,
  "reportedAt": "timestamp",
  "updatedAt": "timestamp"
}
```

---

## 4. Field Type Reference

| Type | Example | Notes |
|------|---------|-------|
| **String** | `"John Doe"` | Names, emails, descriptions |
| **Number** | `15000` | Amounts in paise (smallest unit) |
| **Boolean** | `true` | Status flags like `isActive` |
| **Timestamp** | `FieldValue.serverTimestamp()` | Always use server timestamp |
| **Array** | `["doc1", "doc2"]` | For lists of IDs or simple values |
| **Map/Object** | `{ "key": "value" }` | For nested structures |
| **Reference** | `db.collection(...).doc(...)` | For collection references |

---

## 5. Query Patterns & Performance

### Pattern: Filter by Owner
```dart
_firestore
  .collection('payments')
  .where('ownerId', isEqualTo: currentUserId)
  .orderBy('createdAt', descending: true)
  .limit(10)
  .get();
```
**Index Required:** `ownerId` + `createdAt DESC`

### Pattern: Filter by Owner & Status
```dart
_firestore
  .collection('payments')
  .where('ownerId', isEqualTo: currentUserId)
  .where('status', isEqualTo: 'paid')
  .orderBy('createdAt', descending: true)
  .get();
```
**Index Required:** `ownerId` + `status` + `createdAt DESC`

### Pattern: Filter by Property
```dart
_firestore
  .collection('tenants')
  .where('propertyId', isEqualTo: propertyId)
  .where('status', isEqualTo: 'active')
  .orderBy('createdAt', descending: true)
  .get();
```
**Index Required:** `propertyId` + `status` + `createdAt DESC`

---

## 6. Immutable Fields Strategy

Fields marked **✅ IMMUTABLE** cannot be changed after creation:

| Collection | Immutable Fields |
|------------|------------------|
| **users** | `uid`, `role` |
| **owners** | `ownerId` |
| **tenants** | `ownerId`, `propertyId`, `authUid`, `idProofType`, `idProofUrl`, `agreementUrl` |
| **payments** | `ownerId`, `tenantId`, `propertyId` |
| **transactions** | All fields (audit trail) |

---

## 7. Denormalization Strategy

RentDone uses **selective denormalization** for performance:

| Data | Location | Reason |
|------|----------|--------|
| Owner properties list | `owners.properties[]` | Quick dashboard load |
| Tenant count | `owners.currentTenantCount` | Quota tracking without query |
| Room details | `tenants.room*` | Offline-available data |

---

## 8. Best Practices

### ✅ Do's
- ✅ Use Firebase Auth UID as document ID for user collections
- ✅ Always set `createdAt` and `updatedAt` with `FieldValue.serverTimestamp()`
- ✅ Use `camelCase` for field names
- ✅ Create composite indexes for all frequent queries
- ✅ Limit subcollection depth to 2 levels
- ✅ Use field validation in Firestore rules
- ✅ Denormalize only for read-heavy operations
- ✅ Archive/soft-delete instead of hard delete for audit trail

### ❌ Don'ts
- ❌ Don't use human-readable IDs (UUIDs only)
- ❌ Don't create fields with timestamps like `2023-12-05T10:30:00Z` - use objects
- ❌ Don't store sensitive data (OTP, passwords, SSN) in Firestore
- ❌ Don't create deeply nested collections (max 2 levels)
- ❌ Don't use `/` or `.` in field names
- ❌ Don't store large files (use Cloud Storage instead)
- ❌ Don't query across multiple collections without indexes

---

## 9. Data Retention & Compliance

| Collection | Retention | Notes |
|-----------|-----------|-------|
| **users** | Forever | Customer account data |
| **payments** | 7 years | Legal/tax compliance (India) |
| **transactions** | 7 years | Audit trail |
| **messages** | 2 years | Reduce storage costs |
| **tenantTrust** | Forever | Reputation history |
| **fcmTokens** | 90 days | Auto-cleanup |

---

## 10. Security & Access Control

All access controlled via **Firestore Security Rules**:

```firestore
// Example: Only owner can read their payments
match /payments/{paymentId} {
  allow read: if request.auth.uid == resource.data.ownerId
               || request.auth.uid == resource.data.tenantId;
}
```

See `firestore.rules` for complete implementation.

---

## 11. Performance Metrics

| Operation | Expected Latency | Notes |
|-----------|------------------|-------|
| Read document | 30-50ms | Single document fetch |
| Write document | 50-100ms | Single write |
| Query (indexed) | 50-200ms | With 100-1000 documents |
| Query (unindexed) | 500ms+ | Creates automatic index |
| Batch write | 100-500ms | Up to 500 writes |

---

## 12. Monitoring & Alerts

Monitor these metrics in Firebase Console:

- **Reads/Writes:** Spike detection
- **Errors:** Permission denied rates
- **Latency:** P95/P99 response times
- **Storage:** Growth rate monitoring

---

## Deployment Checklist

- [x] Naming conventions documented
- [x] Collections structured with clear hierarchy
- [x] Composite indexes created in `firestore.indexes.json`
- [x] Immutability enforced in `firestore.rules`
- [x] Field validation in rules
- [x] Timestamps automated with `serverTimestamp()`
- [ ] Production deployment (deploy via CLI)
- [ ] Monitoring configured
- [ ] Team training completed

---

## Related Documents

- [Security Hardening](./SECURITY_HARDENING_COMPLETE.md)
- [Firestore Rules](../firestore.rules)
- [Index Configuration](../firestore.indexes.json)

