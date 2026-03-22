# RentDone Production FCM Notification System

## Scope
Only these high-value notifications are enabled:
- PAYMENT_RECEIVED to owner
- RENT_DUE_REMINDER to tenant

No trigger exists for tenant-added, profile-updated, or other low-value events.

## Project Structure

```text
functions/
  src/
    index.ts
    types/
      domain.ts
    utils/
      firebase.ts
      logger.ts
    services/
      notificationService.ts
      tokenService.ts
      rateLimitService.ts
      validationService.ts
    triggers/
      paymentTrigger.ts
      tokenCallable.ts
    schedulers/
      rentReminderScheduler.ts
  tsconfig.json
  package.json

lib/
  core/
    notifications/
      push_notification_service.dart
```

## Firestore Data Structure

### Device tokens

```text
users/{userId}/deviceTokens/{tokenId}
```

Token document contract:
- token: string
- platform: android | ios | web | unknown
- createdAt: timestamp
- lastUsedAt: timestamp

`tokenId` is SHA-256 of token value for dedupe and stable writes.

### Internal collections (server-only)

```text
_notificationEvents/{eventId}
notificationAnalytics/{eventId}
notificationRateLimits/{userId_type_day}
messages/{messageId}
```

## Event Architecture

### Trigger 1: payment create
Path: `payments/{paymentId}` (onCreate)

Flow:
1. Validate status is paid/success.
2. Validate owner/tenant and ownership linkage.
3. Reserve idempotency event in `_notificationEvents`.
4. Enforce per-user/day rate limit.
5. Load owner device tokens from `users/{ownerId}/deviceTokens`.
6. Send multicast (notification + data payload).
7. Delete invalid tokens from Firestore.
8. Persist in-app message + analytics.

### Trigger 2: rent reminder schedule
Cron: `0 9 * * *` in `Asia/Kolkata`

Flow:
1. Load active tenants due today by `rentDueDay` and `dueDate` windows.
2. Resolve tenant user id (`authUid` fallback to tenant doc id).
3. Reserve idempotency event (`rent_due_{tenantId}_{yyyy-mm-dd}`).
4. Enforce per-user/day rate limit.
5. Send multicast reminder.
6. Delete invalid tokens and write analytics/message docs.

## Message Payload (strict)

```json
{
  "notification": {
    "title": "Payment Received",
    "body": "Rs 6000 received from PM Padhee"
  },
  "data": {
    "type": "PAYMENT_RECEIVED",
    "tenantId": "...",
    "paymentId": "...",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  }
}
```

Rent due data payload uses:
- `type: RENT_DUE_REMINDER`
- `tenantId`
- `ownerId`
- `click_action: FLUTTER_NOTIFICATION_CLICK`

## Flutter Integration

File: `lib/core/notifications/push_notification_service.dart`

Implemented:
- On login/auth change: get token and store in `users/{uid}/deviceTokens/{sha256(token)}`.
- On token refresh: update token doc and delete previous token doc.
- Stores required fields: token, platform, createdAt, lastUsedAt.
- Foreground handling + app tap navigation.
- Backward compatibility for both `RENT_DUE` and `RENT_DUE_REMINDER` payload types.

## Cloud Function Exports

File: `functions/src/index.ts`
- `onPaymentCreated`
- `sendRentDueReminders`
- `registerDeviceToken`
- `unregisterDeviceToken`

## Deployment Commands

From `functions/`:

```bash
npm install
npm run build
```

From repo root:

```bash
firebase deploy --only firestore:rules
firebase deploy --only functions
firebase functions:list
```

Notes:
- `firebase.json` predeploy hook compiles TypeScript automatically.
- Deploy region used: `asia-south1`.

## Testing Steps

### 1) Token registration
1. Login on Android/iOS device.
2. Verify `users/{uid}/deviceTokens/{sha256}` exists with required fields.
3. Refresh token (reinstall app or clear app data) and verify old token doc removed.

### 2) Payment received notification
1. Create `payments/{paymentId}` with `status: paid` and valid owner/tenant linkage.
2. Verify owner receives push instantly.
3. Confirm message in `messages/payment_received_{paymentId}`.
4. Confirm analytics in `notificationAnalytics/payment_received_{paymentId}`.

### 3) Rent due reminder
1. Set tenant `isActive = true` and `rentDueDay` to today (or `dueDate` today).
2. Run scheduler manually from emulator or wait cron window.
3. Verify tenant receives push and idempotency doc created.

### 4) Invalid token cleanup
1. Insert fake token doc.
2. Trigger notification.
3. Verify invalid token doc is deleted.

### 5) Retry behavior
1. Simulate transient FCM errors (emulator/mock).
2. Validate retry attempts occur and function does not crash.

## Common Failure Fixes

1. No push delivered:
- Verify APNs key (iOS) / Android notification permission.
- Ensure token exists under `users/{uid}/deviceTokens`.
- Confirm function logs for send result and invalid token cleanup.

2. Permission denied on token write:
- Deploy latest Firestore rules.
- Ensure user writes only under own `users/{uid}` path.

3. Duplicate notifications:
- Check `_notificationEvents/{eventId}` idempotency keys.
- Ensure no legacy duplicate trigger is deployed.

4. Scheduler not running:
- Confirm Cloud Scheduler job exists in Firebase Console.
- Verify timezone and cron expression.

5. Build/deploy failure:
- Run `npm run build` in `functions/` and fix TypeScript errors.
- Ensure Blaze plan and required APIs are enabled.

## Security Controls

- Firestore data validation before send (owner, tenant, linkage, amount).
- App Check enforced for callable token endpoints.
- Firestore rules enforce token schema and self-only access.
- Internal collections denied in Firestore rules.
- Least privilege: no client write access to internal notification/event analytics collections.

## Performance and Scale Design (100k users)

- Multicast batching up to 500 tokens/request.
- Token dedupe before send.
- Invalid token pruning reduces repeated failures.
- Event idempotency prevents duplicate fanout.
- Daily per-user rate limits to avoid spam and cost spikes.
- Scheduled query uses due-day filtering and deduped result set.

## Topic-Based Future Scaling

Future enhancement pattern:
- Subscribe tenants to `tenant_{tenantId}` or `property_{propertyId}` topics.
- Subscribe owners to `owner_{ownerId}` topic.
- Keep direct-device send for critical transactional events.
- Use topic send for broadcast advisories if needed.

## Cost Optimization

- Keep scope to only high-value notifications.
- Remove invalid tokens quickly.
- Avoid broad scans in scheduler (query by due day/date).
- Use idempotency to avoid duplicate sends.
- Use structured analytics to tune failed-send rates.

## Analytics Strategy

Current server analytics:
- `notificationAnalytics`: sent count, invalid token count, type, user.

Recommended next step:
- Add client open tracking endpoint to log notification open events:
  - eventId
  - openedAt
  - appVersion
  - platform

This enables delivery vs open-rate computation by notification type.
