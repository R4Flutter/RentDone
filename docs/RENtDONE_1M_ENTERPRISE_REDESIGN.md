# RentDone Enterprise Redesign for 1M+ Users

## Executive Architecture

### Target outcomes
1. Sustain 1M+ registered users and high seasonal spikes.
2. Keep p95 app read latency below 250 ms for primary owner workflows.
3. Keep notification delivery success above 99.5 percent with automatic token hygiene.
4. Enforce strict tenant isolation and role boundaries.
5. Support subscription monetization and feature gating without client-side trust.

### Core principles
1. Firestore rules for access control only.
2. Business logic in backend services only.
3. Event-driven workflows for write amplification and async side effects.
4. Read-optimized aggregates for dashboard workloads.
5. Idempotency and replay safety for all asynchronous processors.
6. Cost guardrails as first-class engineering constraints.

### Reference stack
1. Firestore as operational datastore.
2. Cloud Functions v2 (TypeScript) as orchestration layer.
3. Cloud Tasks for durable retries and fan-out workloads.
4. Pub/Sub for event routing and decoupling.
5. BigQuery for analytical workloads and heavy reporting.
6. Cloud Monitoring and Error Reporting for observability.
7. Firebase App Check plus Auth plus strict claims for trust boundaries.

---

## 1) New Firestore Schema (Scalable)

### Multi-tenant model
Use organization boundary to represent paying workspace account.

1. organizations
- orgId
- planTier
- status
- ownerUserId
- billingCustomerId
- createdAt
- updatedAt

2. orgUsers
- orgUserId
- orgId
- userId
- role (owner_admin, owner_staff, tenant)
- status
- createdAt
- updatedAt

3. users
- userId
- primaryEmail
- phone
- profile fields
- createdAt
- updatedAt

4. properties
- propertyId
- orgId
- ownerUserId
- name
- address fields
- isActive
- createdAt
- updatedAt

5. tenants
- tenantId
- orgId
- propertyId
- userId nullable for invited-not-onboarded
- ownerUserId
- rentAmount
- rentDueDay
- status
- trust score snapshot fields
- createdAt
- updatedAt

6. leases
- leaseId
- orgId
- tenantId
- propertyId
- startDate
- endDate nullable
- rentAmount
- currency
- status
- createdAt
- updatedAt

7. payments
- paymentId
- orgId
- tenantId
- propertyId
- leaseId
- billingPeriod (YYYY-MM)
- dueDate
- amountDue
- amountPaid
- status (pending, partial, paid, failed, refunded)
- paymentMethod
- externalTransactionRef
- source (manual, gateway, webhook)
- createdAt
- updatedAt
- paidAt nullable

8. invoices
- invoiceId
- orgId
- tenantId
- paymentId
- invoiceNumber
- amount
- tax
- status
- createdAt

9. deviceTokens
- tokenId (sha256 token)
- orgId optional for quick cleanup
- userId
- token
- platform
- appVersion
- locale
- createdAt
- lastUsedAt
- status (active, invalid)

10. notificationPreferences
- preferenceId (userId)
- userId
- orgId
- rentDueReminderEnabled
- paymentReceivedEnabled
- quietHours
- updatedAt

11. notificationEvents
- eventId idempotency key
- orgId
- type
- userId
- payload summary
- status
- attempts
- createdAt
- nextAttemptAt

12. analyticsDailyOrg
- orgId_date
- orgId
- date
- expectedRevenue
- collectedRevenue
- pendingRevenue
- paymentsCount
- activeTenants
- updatedAt

13. usageCounters
- orgId_metric_window
- orgId
- metric (activeTenants, apiCalls, exports)
- windowStart
- value
- updatedAt

14. featureEntitlements
- orgId
- planTier
- maxActiveTenants
- reportsEnabled
- exportsEnabled
- advancedAnalyticsEnabled
- updatedAt

### Remove deep write-path dependence
Keep tenant documents and payments top-level. Never rely on deep tenant subcollections for primary reporting query paths.

### Indexing strategy
Primary composite indexes:
1. payments: orgId asc, billingPeriod asc, status asc, updatedAt desc
2. payments: orgId asc, tenantId asc, createdAt desc
3. payments: orgId asc, dueDate asc, status asc
4. tenants: orgId asc, status asc, updatedAt desc
5. tenants: orgId asc, propertyId asc, status asc
6. properties: orgId asc, isActive asc, updatedAt desc
7. notificationEvents: status asc, nextAttemptAt asc
8. analyticsDailyOrg: orgId asc, date desc

### Hotspot and sharding strategy
1. Avoid sequential IDs for high-write collections.
2. Use auto IDs for payments and events.
3. For usage counters and heavy increment workloads, use distributed counters with 20 to 100 shards per logical counter.
4. For notification fanout staging, shard queue docs by hash bucket from 00 to 3F.

---

## 2) Backend Architecture (Cloud Functions)

### Service modules
1. paymentService
- validate payment intents
- create payment records
- handle payment state transitions
- idempotency checks
- publish payment domain events

2. notificationService
- resolve recipients and preferences
- batch multicast sends
- token invalidation
- retries with exponential backoff

3. tenantService
- tenant lifecycle
- active tenant count enforcement
- plan quota checks

4. analyticsService
- consume domain events
- update daily aggregates
- export snapshots and trigger reporting jobs

### Function topology
1. HTTP callable and HTTPS endpoints
- strict input validation
- App Check required where applicable
- RBAC from claims and org membership

2. Firestore triggers (thin)
- only publish normalized domain events to Pub/Sub
- no heavy fanout in trigger runtime

3. Pub/Sub consumers
- payment events processor
- analytics updater
- notification scheduler

4. Cloud Tasks workers
- durable notification retry worker
- export generation worker

### Payment processing pipeline
1. Client requests payment creation endpoint.
2. paymentService validates org, lease, entitlement, amount, status transitions.
3. Payment write occurs in transaction.
4. payment.created or payment.updated event emitted.
5. notificationService queues owner payment-received event when state moves to paid.
6. analyticsService updates org daily aggregates asynchronously.
7. All side effects idempotent by eventId.

### Tenant limit enforcement
1. On tenant create or activation, tenantService checks featureEntitlements.maxActiveTenants.
2. Uses transactional read of usageCounters plus tenant status count fallback.
3. Rejects activation if quota exceeded.
4. Emits quota alert event.

### Validation layer
Use schema validation in every public endpoint and worker boundary:
1. zod or io-ts schemas
2. enum constraints
3. canonical status transition map
4. safe numeric ranges for amounts
5. strict unknown field rejection

---

## 3) Notification System (Enterprise)

### Architecture
1. Notification intent generation from payment and rent schedule events.
2. Recipient resolution from orgUsers and notificationPreferences.
3. Token fetch from deviceTokens by userId with active status.
4. Multicast sends in chunks of 500 tokens.
5. Invalid tokens immediately tombstoned and asynchronously deleted.

### Retry and backoff
1. Retry only transient error codes.
2. Backoff schedule: 15 sec, 60 sec, 5 min, 30 min, 2 hr.
3. Max attempts configurable by notification type.
4. Dead-letter queue after max attempts with operator alert.

### Preference and suppression
1. Respect notificationPreferences flags.
2. Respect quiet hours except critical billing notices.
3. Suppress duplicates using idempotency key:
- payment_received_orgId_paymentId_userId
- rent_due_orgId_tenantId_period_userId

### Topic strategy for future scale
1. Owner broadcast topic per org for non-critical announcements.
2. Property-level topic optional for maintenance updates.
3. Continue direct token addressing for transactional critical notifications.

---

## 4) Analytics Pipeline

### Operational analytics in Firestore
1. analyticsDailyOrg for dashboard cards.
2. analyticsDailyProperty optional for property-level cards.
3. incremental updates from event stream.

### BigQuery analytical lake
1. Export Firestore change streams or Pub/Sub domain events into BigQuery.
2. Partition by event date.
3. Cluster by orgId and eventType.
4. Build monthly revenue and delinquency models.

### Dashboard metrics
1. Collected vs expected rent by day and month.
2. Tenant payment punctuality score.
3. Delinquency cohorts by org and property.
4. Notification delivery and open funnel.

### Export system
1. Export requests written to exportJobs.
2. Cloud Tasks worker generates PDF and Excel asynchronously.
3. Output files in Cloud Storage with signed URL TTL.
4. Progress state machine: queued, running, complete, failed.

---

## 5) Monetization System

### Plan model
1. Free
- max tenants low
- basic reminders
- no advanced exports

2. Growth
- higher tenant limit
- payment reminders plus analytics
- PDF and Excel exports

3. Pro
- high tenant limit
- advanced analytics and integrations
- priority notifications and support

### Feature gating
1. featureEntitlements document generated from billing system webhooks.
2. Backend checks entitlement for every premium endpoint.
3. Client only reads capability flags for UI state; never trusted for enforcement.

### Billing hooks
1. billing.subscription.updated webhook updates organizations and featureEntitlements.
2. plan downgrade grace period with queued enforcement.
3. hard lock only on non-payment threshold and policy window.

---

## 6) Security Architecture

### Firestore rules scope
Rules should only answer:
1. Is caller authenticated.
2. Is caller member of org.
3. Is role allowed for this document operation.
4. Is document orgId immutable and equal to caller org context.

### Business logic moved out of rules
Move all of the following to backend:
1. payment status transitions
2. tenant limits
3. trust score updates
4. due-date reminder scheduling
5. feature gating

### Privilege escalation prevention
1. Custom claims include principal type and trusted identifiers only.
2. Server verifies org membership from orgUsers, not from user-submitted orgId.
3. Immutable fields enforced in backend and rules:
- orgId
- ownerUserId where applicable
- createdAt

### Data integrity controls
1. transactional writes for multi-document state changes.
2. idempotency keys for all externally retried calls.
3. write audit trail collection for sensitive mutations.

---

## 7) Performance Optimization

### Read reduction
1. Dashboard uses pre-aggregated daily summaries.
2. Avoid full collection scans by org-scoped indexes.
3. Replace chained lookups with denormalized display fields where stable.

### Write optimization
1. Batch writes for fanout updates.
2. Async side effects through Pub/Sub and Cloud Tasks.
3. Avoid trigger cascades by single event source of truth.

### N+1 avoidance
1. Use in query joins at application layer with bounded IDs.
2. Maintain owner and tenant display snapshots on payment docs.

### Caching strategy
1. Short-lived in-memory cache in function instances for static entitlements.
2. Optional Redis (Memorystore) for high-frequency entitlement checks and idempotency markers.

---

## 8) Cost Optimization and Estimates

### Cost controls
1. Keep operational queries org-scoped and indexed.
2. Use aggregate docs for dashboards instead of raw scans.
3. Push heavy analytics to BigQuery scheduled jobs.
4. Aggressively delete invalid tokens.
5. Use Cloud Tasks retries instead of repeated trigger failures.

### Estimated monthly order-of-magnitude cost
Assumptions:
1. 2 DAU sessions per user per day average.
2. 30 to 80 document reads per session depending on plan features.
3. 3 to 8 writes per active user per day.
4. 2 transactional notifications per billing cycle tenant.

100 active users:
1. Firestore and Functions: low double-digit USD.
2. Storage and egress: very low.
3. Total: approximately 20 to 80 USD monthly depending on analytics/export volume.

1,000 active users:
1. Firestore reads and writes dominate.
2. Functions, Pub/Sub, Tasks moderate.
3. Total: approximately 150 to 700 USD monthly depending on dashboard refresh and export intensity.

10,000 active users:
1. Firestore and analytics pipeline dominate.
2. BigQuery storage and query costs become material.
3. Total: approximately 1,500 to 7,000 USD monthly, strongly affected by query design and export volume.

At 1M registered users with healthy MAU controls, costs remain manageable only with strict aggregate-driven reads and asynchronous processing discipline.

---

## 9) Flutter Client Integration

### API interaction pattern
1. Client writes only user-owned profile and lightweight preference docs.
2. All business-critical mutations go through callable HTTPS APIs.
3. Client consumes read models and aggregate documents only.

### Notification handling
1. On login and token refresh, upsert deviceTokens by token hash.
2. Foreground and background handlers map notification type to route.
3. Preference toggles write to notificationPreferences.
4. Token status updates handled server-side on send failures.

### Offline and sync
1. Use Firestore local cache for read models.
2. Queue writes only for non-critical preference or draft state.
3. Payment and billing actions always online and server-validated.

---

## 10) Testing Strategy

### Unit tests
1. paymentService transition matrix tests.
2. tenantService quota tests with race conditions.
3. notificationService retry and token invalidation tests.
4. analyticsService aggregate correctness tests.

### Integration tests
1. Emulator-based role access tests per collection.
2. end-to-end payment to notification flow.
3. subscription downgrade and feature gating flow.
4. export job lifecycle tests.

### Load testing
1. Synthetic workload generator for:
- payment writes bursts
- dashboard reads
- notification fanout spikes
2. Validate p95 and p99 latencies.
3. Validate retry queue depth and dead-letter rates.

### Chaos and resilience
1. Inject transient FCM failures.
2. Inject Pub/Sub redelivery.
3. Ensure idempotent event processing and no duplicate user-visible state.

---

## 11) Deployment Pipeline

### Environment separation
1. Separate Firebase projects: dev, stage, prod.
2. Separate billing accounts and budgets.
3. Separate BigQuery datasets per environment.

### CI/CD flow
1. Pull request gates:
- lint
- unit tests
- emulator integration tests
- rules tests
2. Build and deploy to stage automatically.
3. Smoke tests in stage.
4. Controlled production rollout by function group.

### Safe rollout strategy
1. Deploy new functions with versioned event types.
2. Dual-write aggregates during migration window.
3. Compare old and new dashboards for parity.
4. Flip read path via feature flag.
5. Decommission legacy schema after validation window.

### Firebase command baseline
1. firebase use stage or firebase use prod
2. firebase deploy --only firestore:rules
3. firebase deploy --only firestore:indexes
4. firebase deploy --only functions
5. firebase functions:list
6. firebase firestore:indexes

---

## Migration Plan from Current State

### Phase 1: Stabilize access and data model
1. Add orgId to top-level entities.
2. Introduce top-level payments and keep legacy mirror writes temporarily.
3. Introduce orgUsers membership model.

### Phase 2: Move business logic server-side
1. Disable rule-level business constraints except access invariants.
2. Route payment and tenant mutations through callable endpoints.
3. Introduce event bus with Pub/Sub.

### Phase 3: Build read models and analytics
1. Launch analyticsDailyOrg and dashboard reads from aggregates.
2. Enable BigQuery export pipeline.
3. Migrate reporting endpoints to async export jobs.

### Phase 4: Monetization and quotas
1. Launch featureEntitlements and usageCounters.
2. Enforce tenant limits in tenantService transactions.
3. Enable billing webhook integration.

### Phase 5: Scale hardening
1. Load tests and SLO tuning.
2. Alerting and on-call runbooks.
3. Remove legacy nested subcollection dependence.

---

## Operational Observability Blueprint

### Logs
1. Structured JSON logs with orgId, userId, eventId, requestId.
2. Error logs include domain, function name, retryAttempt, idempotencyKey.

### Metrics
1. Notification success, failure, retries, token invalidations.
2. Payment transition throughput.
3. Queue backlog depth and age.
4. Dashboard query latency p95 and p99.

### Alerts
1. Notification failure ratio above threshold.
2. Queue age above threshold.
3. Function error spike by domain.
4. Cost anomaly alerts via billing budgets.

---

## Final Production Readiness Checklist

1. All critical mutations backend-only.
2. orgId enforced and immutable.
3. All high-volume queries indexed and benchmarked.
4. Notification retries and dead-letter processing enabled.
5. Analytics aggregates powering dashboards.
6. Entitlement and quota checks in backend transaction paths.
7. SLO dashboards and alerts live.
8. Stage-to-prod rollout with canary and rollback playbooks documented.

This redesign provides a practical, enterprise-grade path from the current RentDone architecture to a secure, scalable, monetization-ready SaaS platform supporting 1M+ users while controlling latency and cost.