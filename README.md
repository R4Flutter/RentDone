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

### Required Firebase Runtime Config

Set these before deploying:

```bash
firebase functions:config:set whatsapp.token="<META_TOKEN>" whatsapp.phone_number_id="<PHONE_NUMBER_ID>" whatsapp.business_name="RentDone"
```

Optional production settings:

```bash
firebase functions:config:set whatsapp.enabled="true" whatsapp.api_version="v21.0" whatsapp.max_retries="3" whatsapp.template_name="<TEMPLATE_NAME>" whatsapp.template_language="en"
```

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

This project is preconfigured with Razorpay test Key ID fallback:

- `rzp_test_SWZErkO7aPAnNO`

For secure deployments, always set backend secrets and optional app override.

### 1) Configure Cloud Functions runtime config

```bash
firebase functions:config:set razorpay.key_id="rzp_test_SWZErkO7aPAnNO" razorpay.key_secret="<YOUR_RAZORPAY_KEY_SECRET>" razorpay.webhook_secret="<YOUR_RAZORPAY_WEBHOOK_SECRET>"
```

### 2) Deploy functions

```bash
firebase deploy --only functions
```

### 3) Run Flutter app with explicit key (recommended)

```bash
flutter run --dart-define=RAZORPAY_KEY=rzp_test_SWZErkO7aPAnNO
```

### 4) Razorpay Dashboard webhook

- URL: `https://<YOUR_REGION>-<YOUR_PROJECT>.cloudfunctions.net/razorpayWebhook`
- Secret: use the same value as `razorpay.webhook_secret`

### 5) Production switch checklist

- Replace test Key ID with live Key ID.
- Replace key secret and webhook secret with live values.
- Keep secrets only in Firebase config / environment, never hardcode secrets in app.

## Local Emulator Mode (No Blaze Required)

Real mode code remains unchanged by default. Emulator mode is opt-in via dart-defines.

### 1) Start Firebase emulators

```bash
firebase emulators:start --only functions,firestore,auth
```

### 2) Run Flutter app in Functions emulator mode

```bash
flutter run --dart-define=USE_FUNCTIONS_EMULATOR=true --dart-define=FUNCTIONS_EMULATOR_HOST=127.0.0.1 --dart-define=FUNCTIONS_EMULATOR_PORT=5001 --dart-define=RAZORPAY_KEY=rzp_test_SWZErkO7aPAnNO
```

For Android Emulator, use `FUNCTIONS_EMULATOR_HOST=10.0.2.2`.

### Recommended release checklist

- Enable Email/Password and Google provider in Firebase Auth.
- Ensure Android/iOS/Web OAuth client IDs are correctly configured.
- Verify all owner-created property docs contain `ownerId`.
- Verify tenant/payment/lease/transaction/message docs include ownership fields.
- Test deep links:
	- tenant account cannot open `/owner/*`
	- owner account cannot open `/tenant/*`
	- signed-out users are redirected to `/role`
