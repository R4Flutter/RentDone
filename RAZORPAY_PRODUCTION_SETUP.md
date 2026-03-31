# Razorpay Production Setup

This project already contains the end-to-end Razorpay payment flow:
- tenant payment quote + payment intent
- server-side Razorpay order creation
- client checkout launch via `razorpay_flutter`
- server-side signature verification
- payment + transaction document updates in Firestore
- owner-side Razorpay payment intent + verification callables

## 1. Flutter app

Run:

```bash
flutter pub get
```

Use a backend-provided key in production. You can still pass a test key for local runs:

```bash
flutter run --dart-define=RAZORPAY_KEY=rzp_test_xxxxxxxxxxxxx
```

## 2. Firebase Functions secrets / config

Set Razorpay credentials before deploying functions. Example with Functions config:

```bash
firebase functions:config:set \
  razorpay.mode="test" \
  razorpay.key_id="rzp_test_xxxxxxxxxxxxx" \
  razorpay.key_secret="your_test_secret" \
  razorpay.webhook_secret="your_webhook_secret"
```

For live mode, switch `razorpay.mode` to `live` and use live keys.

## 3. Deploy functions

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

## 4. Deploy Firestore rules

```bash
firebase deploy --only firestore:rules
```

## 5. Test flow

1. Sign in as tenant.
2. Open tenant payments / transactions.
3. Start Razorpay checkout.
4. Complete payment with Razorpay test mode.
5. Verify `payments/{paymentId}` becomes paid and `transactions/{idempotencyKey}` becomes success.

## Important

- Do not hardcode live secret keys in the app.
- The server creates the order and verifies the signature.
- The app only receives the order id / key id needed for checkout.
