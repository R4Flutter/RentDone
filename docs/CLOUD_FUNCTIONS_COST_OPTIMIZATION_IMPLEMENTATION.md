# Cloud Functions Cost Optimization - Production Implementation

## 1) Lightweight Function Design (Implemented)

What changed:
- Added explicit lightweight runtime settings on high-volume jobs/triggers.
- Added aggressive guard clauses and early exits for non-impacting writes.
- Added bounded cleanup processing per run to avoid long expensive executions.

Examples from implementation:
- `syncOwnerSummaryOnPaymentWrite` now exits immediately unless relevant payment fields changed.
- `syncOwnerSummaryOnTenantWrite` now exits unless owner ownership changed or create/delete happened.
- `syncOwnerSummaryOnPropertyWrite` now exits unless `ownerId`/`rooms` changed or create/delete happened.
- `cleanupExpiredWebhookEvents` now deletes in capped chunks (`maxDocs`) instead of unbounded loops.

Memory and timeout strategy:
- Lightweight trigger handlers: `128MB`, short timeout.
- Moderate scheduled jobs: `256MB` with bounded timeout.
- Monthly batch generation: `256MB` with longer timeout only where required.

## 2) Trigger Condition Sample Code

```js
function shouldRecomputeOwnerSummaryForPaymentWrite(change) {
  const beforeExists = change.before.exists;
  const afterExists = change.after.exists;
  if (beforeExists !== afterExists) return true; // create/delete
  if (!beforeExists && !afterExists) return false;

  const beforeData = change.before.data() || {};
  const afterData = change.after.data() || {};

  const ownerChanged = String(beforeData.ownerId || '').trim() !==
    String(afterData.ownerId || '').trim();
  if (ownerChanged) return true;

  return hasAnyFieldChanged(beforeData, afterData, [
    'status', 'amount', 'baseAmount', 'paidAmount', 'paidAt',
    'dueDate', 'date', 'method', 'paymentMethod', 'tenantId',
  ]);
}
```

Pattern:
- Compare `before` vs `after`.
- Return early on irrelevant updates.
- Recompute only for actual summary-impacting changes.

## 3) Client vs Server Responsibility Breakdown

Client (Flutter):
- Input validation and form-level checks.
- Formatting and display calculations.
- Report/export rendering and file generation.
- UI-only summaries and local aggregation.

Server (Cloud Functions only):
- Security-sensitive payment intent + verification.
- Webhook signature verification and idempotency.
- Scheduled cleanup and retention tasks.
- Cross-document consistency updates (owner summary sync).

Rule of thumb:
- If logic can run safely in client without integrity risk, keep it client-side.
- Keep functions focused on trust boundaries and consistency.

## 4) Scheduled Cleanup Function Example (Optimized)

```js
exports.cleanupExpiredWebhookEvents = functions
  .runWith({ memory: '128MB', timeoutSeconds: 120 })
  .pubsub
  .schedule('every day 03:40')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    const now = Timestamp.now();
    const deletedWebhookEvents = await deleteQueryInChunksCapped(
      db.collection('_webhookEvents').where('expiresAt', '<=', now),
      { chunkSize: 300, maxDocs: 1200 },
    );

    if (deletedWebhookEvents > 0) {
      functions.logger.info('Expired webhook docs deleted', { deletedWebhookEvents });
    }
    return null;
  });
```

Why this is cheaper:
- Daily schedule vs frequent schedule.
- Bounded work per run (predictable billing).
- No noisy logs when no work exists.

## 5) Before vs After Cost Comparison (Estimated)

### Invocation profile
Before:
- Owner summary recompute on almost every write in `payments`, `tenants`, `properties`.
- Disabled reminder schedulers still invoked frequently.
- Cleanup job every 6 hours.

After:
- Owner summary recompute only on relevant field changes.
- Disabled reminder schedulers reduced to once daily.
- Cleanup job reduced to daily and bounded per run.

Estimated impact:
- Unnecessary trigger executions with heavy work: down 50%-80%.
- Scheduled job invocations (disabled reminders + webhook cleanup): down ~40%-80%.
- Average execution time per write trigger: down ~40%+ due to early exits.

## 6) Additional Reliability and Integrity Notes

- Security checks and ownership validation remain unchanged.
- Idempotency behavior for payments/webhooks remains intact.
- Bounded cleanup prevents runaway execution and timeout cascades.

## 7) Deployment Notes

Important:
- Functions package entry point is now aligned to `functions/index.js` in `functions/package.json`.
- Deploy command:

```bash
firebase deploy --only functions
```

## 8) Success Metrics Alignment

Target vs implementation alignment:
- Invocation reduction `>=50%`: addressed via trigger guards + scheduler frequency reduction.
- Execution time reduction `>=40%`: addressed via early exits + capped loops.
- Compute cost reduction `>=50%`: addressed via reduced expensive paths and smaller runtimes.
- Heavy processing removed: maintained (no file transforms/PDF generation in backend flows).
