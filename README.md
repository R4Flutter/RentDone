# rentdone

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Production WhatsApp Rent Reminders

Monthly rent reminders to tenants are sent from Cloud Functions based on each
payment due date.

- Function: `sendRentDueWhatsAppReminders`
- Schedule: `09:00, 12:00, 15:00, 18:00, 21:00` (Asia/Kolkata)
- Idempotent: only one successful reminder is stored per payment due day
- Retry: automatic retry for temporary WhatsApp API failures (429/5xx)

### Required Function Environment Variables

Set these in your deployment environment (for Firebase, use Function Secrets for secrets and environment variables for non-secret flags).

Secret values:

```bash
firebase functions:secrets:set WHATSAPP_TOKEN
```

Non-secret runtime settings (set via your deployment environment):

- `WHATSAPP_PHONE_NUMBER_ID`
- `WHATSAPP_BUSINESS_NAME`
- `WHATSAPP_API_VERSION`
- `WHATSAPP_MAX_RETRIES`
- `WHATSAPP_TEMPLATE_NAME`
- `WHATSAPP_TEMPLATE_LANGUAGE`
- `WHATSAPP_ENABLED`

If `whatsapp.template_name` is set, reminders use WhatsApp Template messages
(recommended for production). Otherwise, plain text messages are sent.

## Production Auth + Role Setup (Owner/Tenant)

This app is configured for:

- Role-first login (`owner` / `tenant`)
- Google + Email authentication via Firebase Auth
- Firestore-backed role profile in `users/{uid}`
- Role-gated routing and owner/tenant data isolation

### Firestore collections contract

Required fields used by app rules and queries:

- `users/{uid}`
	- `uid` (string, immutable)
	- `role` (`owner` or `tenant`, immutable after first write)
	- `email`, `name`, `phone`, `createdAt`, `updatedAt`, `lastLoginAt`
- `properties/{propertyId}`
	- `ownerId` (must be auth uid of owner)
- `tenants/{tenantId}`
	- `ownerId`, `propertyId`
- `payments/{paymentId}`
	- `ownerId`, `tenantId`
- `leases/{leaseId}`
	- `ownerId`, `tenantId`
- `transactions/{transactionId}`
	- `ownerId`, `tenantId`
- `messages/{messageId}`
	- `ownerId` (and optional `tenantId`)
- `ownerPaymentProfiles/{ownerUid}`
	- document id must equal owner uid

### Deploy production security rules and indexes

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

### Deploy backend functions

```bash
firebase deploy --only functions
```

## Razorpay Setup (App + Backend)

For secure deployments, use Firebase Function Secrets as the single source of truth.

### 1) Configure Cloud Functions secrets

```bash
firebase functions:secrets:set RAZORPAY_KEY
firebase functions:secrets:set RAZORPAY_SECRET
firebase functions:secrets:set RAZORPAY_WEBHOOK_SECRET
```

### 2) Deploy functions

```bash
firebase deploy --only functions
```

### 3) Run Flutter app with explicit key (recommended)

```bash
flutter run --dart-define=RAZORPAY_KEY=<YOUR_RAZORPAY_KEY>
```

### 4) Razorpay Dashboard webhook

- URL: `https://<YOUR_REGION>-<YOUR_PROJECT>.cloudfunctions.net/razorpayWebhook`
- Secret: use the same value as `RAZORPAY_WEBHOOK_SECRET`

### 5) Production switch checklist

- Keep secrets only in Firebase Secrets and deployment environment variables.
- Never commit `.env` files or secret values to this repository.
- Verify staging before promoting to production.

## Local Emulator Mode (No Blaze Required)

Real mode code remains unchanged by default. Emulator mode is opt-in via dart-defines.

### 1) Start Firebase emulators

```bash
firebase emulators:start --only functions,firestore,auth
```

### 2) Run Flutter app in Functions emulator mode

```bash
flutter run --dart-define=USE_FUNCTIONS_EMULATOR=true --dart-define=FUNCTIONS_EMULATOR_HOST=127.0.0.1 --dart-define=FUNCTIONS_EMULATOR_PORT=5001 --dart-define=RAZORPAY_KEY=<YOUR_RAZORPAY_KEY>
```

For Android Emulator, use `FUNCTIONS_EMULATOR_HOST=10.0.2.2`.

### 3) Run Auth Integration Smoke Test (Emulator)

This project includes an emulator-only auth integration smoke test at
`integration_test/auth_emulator_smoke_test.dart`.

Run it with `flutter drive`:

```bash
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/auth_emulator_smoke_test.dart --dart-define=USE_AUTH_EMULATOR=true --dart-define=USE_FIRESTORE_EMULATOR=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1 --dart-define=AUTH_EMULATOR_PORT=9099 --dart-define=FIRESTORE_EMULATOR_PORT=8080
```

Optional local quick run (`flutter test`) command:

```bash
flutter test integration_test/auth_emulator_smoke_test.dart --dart-define=USE_AUTH_EMULATOR=true --dart-define=USE_FIRESTORE_EMULATOR=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1 --dart-define=AUTH_EMULATOR_PORT=9099 --dart-define=FIRESTORE_EMULATOR_PORT=8080
```

For Android Emulator host networking, set `FIREBASE_EMULATOR_HOST=10.0.2.2`.

### Recommended release checklist

- Enable Email/Password and Google provider in Firebase Auth.
- Ensure Android/iOS/Web OAuth client IDs are correctly configured.
- Verify all owner-created property docs contain `ownerId`.
- Verify tenant/payment/lease/transaction/message docs include ownership fields.
- Test deep links:
	- tenant account cannot open `/owner/*`
	- owner account cannot open `/tenant/*`
	- signed-out users are redirected to `/role`
