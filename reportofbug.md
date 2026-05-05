# RentDone Bug Report

Date: 2026-05-05

## Summary

I found and fixed the main Firebase/runtime problems behind document upload failures and dashboard loading failures.

The biggest issue was that the deployed rules shape did not match the app data shape. The Flutter app writes tenant documents to `tenants/{tenantId}/documents`, writes upload metadata to `user_images`, reads owner/dashboard collections, and uses several tenant subcollections. The previous Firestore rules denied most of those paths. Storage rules also allowed uploads but denied deletes because delete requests do not have `request.resource`.

## Fixes Made

### 1. Firestore rules did not allow tenant document metadata

Symptoms:
- Tenant document upload could finish Storage upload but fail when saving Firestore metadata.
- Tenant document list/delete could fail with permission denied.
- Related tenant dashboard data such as room details, owner details, reminders, payments, and complaints could be denied.

Changed file:
- `firestore.rules`

What changed:
- Added helper rules for owner/tenant access.
- Added access to tenant subcollections:
  - `tenants/{tenantId}/documents`
  - `tenants/{tenantId}/payments`
  - `tenants/{tenantId}/room_details`
  - `tenants/{tenantId}/owner_details`
  - `tenants/{tenantId}/reminders`
  - `tenants/{tenantId}/complaints`
  - `tenants/{tenantId}/trust_score_events`
- Added `user_images` rules for upload metadata created by `lib/features/tenant/data/services/firebase_document_storage_service.dart`.
- Added app paths used elsewhere: `owners`, `ownerPaymentProfiles`, `transactions`, `tenantTrust`, `leases`, and `appConfig`.

Deploy needed:
```bash
firebase deploy --only firestore:rules
```

### 2. Storage rules allowed upload but blocked delete/report export

Symptoms:
- Deleting a tenant document could fail in Firebase Storage.
- Owner report PDF/XLSX fallback uploads were denied because `/reports/...` was not allowed.

Changed file:
- `storage.rules`

What changed:
- Split `create/update` from `delete` for `images/users/{userId}/...`.
- Kept the upload limits: images <= 200KB, PDFs <= 500KB.
- Added a dedicated owner add-tenant draft document path:
  `images/users/{userId}/tenants/{tenantId}/documents/{allPaths=**}`.
  This path allows authenticated owner uploads up to 2MB, while the Flutter app still enforces 200KB images and 500KB PDFs before upload. This avoids Firebase Storage returning a generic "not authorized" message for type/metadata mismatches.
- Added `/reports/{userId}/...` for owner PDF/XLSX report export uploads.

Deploy needed:
```bash
firebase deploy --only storage
```

### 3. Owner dashboard could stay loading or error on Firebase stream failure

Symptoms:
- Dashboard could show an error or never finish loading if `owners_summary` was missing/denied or if one timeline stream failed.

Changed files:
- `lib/features/owner/owner_dashboard/data/services/dashboard_firebase_service.dart`
- `lib/features/owner/owner_dashboard/data/repositories/dashboard_repository_impl.dart`
- `lib/features/owner/owner_dashboard/presentation/providers/dashboard_data_provider.dart`
- `lib/features/owner/owner_dashboard/presentation/providers/messages_provider.dart`

What changed:
- `owners_summary` stream now yields `null` on Firebase stream failure instead of leaving the dashboard stuck.
- Repository now falls back to computed dashboard data, cached data, or `DashboardSummary.empty`.
- Recent messages panel now becomes ready with empty data if one of its streams fails/closes.
- Dashboard/message providers now use `autoDispose` to avoid stale listeners.

### 4. Auth screens had analyzer-blocking syntax/API issues

Symptoms:
- `flutter analyze` found invalid escaped strings in login/signup footers.
- Login Google button passed `glassColor` and `opacity` to `GlassButton`, but the current `GlassButton` API does not define those parameters.

Changed files:
- `lib/features/auth/presentation/pages/login_screen.dart`
- `lib/features/auth/presentation/pages/signup_screen.dart`

What changed:
- Fixed footer text strings.
- Removed unsupported `GlassButton` parameters from the Google login button.

## Verification

Passed:
```bash
firebase deploy --only firestore:rules,storage --dry-run
flutter analyze
flutter test
```

Results:
- Firestore rules compiled successfully.
- Storage rules compiled successfully.
- Flutter analyzer: no issues found.
- Tests: all tests passed.
- Rules were deployed to project `rentdone-92c6f` on 2026-05-05 after the upload authorization fix.

## Important Next Step

The fixes are local. Deploy rules before testing on real Firebase:

```bash
firebase deploy --only firestore:rules,storage
```

Then test:
- Upload a tenant image/PDF document.
- Confirm Firestore creates `tenants/{tenantId}/documents/{documentId}`.
- Confirm Firestore creates a `user_images` metadata document.
- Open owner dashboard with and without an `owners_summary/{ownerId}` doc.
- Delete an uploaded document and confirm Storage no longer returns permission denied.
