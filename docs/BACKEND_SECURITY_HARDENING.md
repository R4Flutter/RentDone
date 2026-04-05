# Backend Security Hardening (Production)

This project now includes backend hardening in Cloud Functions for:

- Callable auth + optional App Check enforcement
- Constant-time webhook signature checks
- Safer HTTP endpoint CORS behavior
- Payment ownership validation before verify/order/confirm actions
- Razorpay amount tamper prevention (server amount is source of truth)

## 1) Set required environment variables

Set these in the deployment environment (not in source control):

- `SECURITY_ENFORCE_APP_CHECK=true`
- `SECURITY_ALLOWED_ORIGIN=https://your-app-domain.com`

If you have multiple web origins, deploy with a reverse proxy for one canonical origin,
or set `security.allowed_origin="*"` temporarily while rolling out.

## 2) Keep payment/webhook secrets only on server

```bash
firebase functions:secrets:set RAZORPAY_KEY
firebase functions:secrets:set RAZORPAY_SECRET
firebase functions:secrets:set RAZORPAY_WEBHOOK_SECRET
```

Use Firebase Storage security rules and Firestore rules for upload access control.

Never place these secrets in Flutter app code, `.env` files committed to git, or client bundle.

## 3) Enable Firebase App Check in client apps

- Android: Play Integrity / SafetyNet (based on your setup)
- iOS: DeviceCheck / App Attest
- Web: reCAPTCHA Enterprise or v3

Rollout path:

1. Enable App Check in apps and verify tokens are being sent.
2. Keep `SECURITY_ENFORCE_APP_CHECK=false` for a short transition if needed.
3. Switch to `"true"` in production.

## 4) Deploy rules and functions

```bash
firebase deploy --only firestore:rules,firestore:indexes,functions
```

## 5) Post-deploy verification checklist

- `createPaymentIntent` works only for authenticated users with valid App Check token.
- `verifyPayment` rejects users who do not own the payment.
- `createRazorpayOrder` rejects client-side amount tampering.
- `confirmRazorpayPayment` rejects mismatched `razorpayOrderId`.
- Tenant document uploads are enforced through Firebase Storage rules and authenticated user paths.
- `razorpayWebhook` and `cashfreeWebhook` reject invalid signatures and non-POST methods.

## 6) Recommended next hardening tasks

- Move webhook handlers to Functions v2 with explicit ingress settings.
- Add structured audit logs to BigQuery for payment-sensitive operations.
- Add automated emulator tests for auth + App Check + ownership checks.
