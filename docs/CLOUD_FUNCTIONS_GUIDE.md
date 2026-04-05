# ☁️ Cloud Functions - Production Deployment Guide

**Professional Setup for Fintech Backend Services**

---

## Overview

Cloud Functions handle server-side logic:
- Email notifications
- Gravatar integration
- Data migration and cleanup
- Scheduled maintenance tasks

Current implementation in `functions/`:
- `index.js` - Main function exports
- `email_duplicate_cleanup.js` - Email deduplication
- `gravatar_migration.js` - Profile picture migration

---

## Current Implementation

### Function Structure

```
functions/
├── package.json
├── index.js
├── email_duplicate_cleanup.js
├── gravatar_migration.js
└── node_modules/
```

### Deployed Functions

#### 1. **Email Duplicate Cleanup**
- **Purpose:** Remove duplicate email documents
- **Trigger:** Manual or scheduled
- **Framework:** Node.js + Firestore Admin SDK

#### 2. **Gravatar Migration**
- **Purpose:** Migrate user profile pictures to Gravatar
- **Trigger:** Manual onboarding
- **Framework:** Node.js + Gravatar API

---

## Production Setup Best Practices

### 1. Environment Configuration

Create `.env` for sensitive data:

```bash
# functions/.env
FIREBASE_PROJECT_ID=rentdone-92c6f
GRAVATAR_API_KEY=your_api_key_here
ADMIN_EMAIL=admin@rentdone.com
```

**Deploy as secret:**

```bash
# Store in Firebase Secret Manager
firebase functions:secrets:set GRAVATAR_API_KEY

# Use in functions
const apiKey = process.env.GRAVATAR_API_KEY;
if (!apiKey) {
  throw new Error('Missing GRAVATAR_API_KEY');
}
```

### 2. Function Configuration

Optimize performance in `firebase.json`:

```json
{
  "functions": {
    "source": "functions",
    "codebase": "default",
    "runtime": "nodejs20"
  }
}
```

### 3. Package Dependencies

Keep `package.json` lean:

```json
{
  "name": "rentdone-functions",
  "version": "1.0.0",
  "description": "Cloud Functions for RentDone",
  "engines": {
    "node": "20"
  },
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^4.5.0",
    "node-fetch": "^2.7.0"
  },
  "devDependencies": {
    "eslint": "^8.0.0"
  }
}
```

---

## Function Best Practices

### 1. Error Handling

```javascript
// ✅ GOOD: Comprehensive error handling
exports.emailDuplicateCleanup = functions.https.onCall(async (data, context) => {
  try {
    // Check authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    // Validate input
    if (!data.email || typeof data.email !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Email must be a valid string'
      );
    }

    // Main logic with error handling
    const result = await cleanupDuplicates(data.email);
    
    return { success: true, result };
  } catch (error) {
    // Log error
    console.error('Cleanup failed:', error);
    
    // Return appropriate error code
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Function execution failed'
    );
  }
});

// ❌ BAD: No error handling
exports.badFunction = functions.https.onCall(async (data) => {
  return await someAsyncOperation(data);
});
```

### 2. Authentication & Authorization

```javascript
// ✅ GOOD: Check user is authenticated
async function authorizeUser(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required'
    );
  }
  
  return context.auth.uid;
}

// ✅ GOOD: Verify admin status
async function authorizeAdmin(context) {
  const uid = await authorizeUser(context);
  
  const userDoc = await admin
    .firestore()
    .collection('users')
    .doc(uid)
    .get();
  
  if (userDoc.data()?.role !== 'admin') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Admin privileges required'
    );
  }
  
  return uid;
}
```

### 3. Cold Start Optimization

```javascript
// Initialize clients at module level (reused across invocations)
const db = admin.firestore();
const auth = admin.auth();

// ✅ GOOD: Fast cold starts
exports.quickFunction = functions.https.onCall(async (data) => {
  return await db.collection('users').get();
});

// ❌ BAD: Slow cold starts
exports.slowFunction = functions.https.onCall(async (data) => {
  const db = admin.firestore();  // Re-initialized every call
  return await db.collection('users').get();
});
```

### 4. Timeout Management

```javascript
// Callable functions (default 60s timeout)
exports.quickTask = functions.https.onCall(async (data, context) => {
  // Maximum 60 seconds
  return processData(data);
});

// Background functions (default 540s timeout)
exports.backgroundTask = functions
  .runWith({ timeoutSeconds: 540 })
  .firestore
  .document('tasks/{taskId}')
  .onWrite(async (change, context) => {
    // Maximum 9 minutes
    return processBackgroundWork();
  });

// Long-running task (30 minutes)
exports.heavyProcessing = functions
  .runWith({ 
    timeoutSeconds: 1800,
    memory: '4GB'
  })
  .pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    return processBigData();
  });
```

---

## Deployment Strategy

### Local Testing

```bash
cd functions

# Test locally
npm run test

# Start emulator
firebase emulators:start --only functions
```

### Staging Deployment

```bash
# Deploy to staging project
firebase deploy --project staging --only functions

# Monitor logs
firebase functions:log --project staging
```

### Production Deployment

```bash
# Full deployment with monitoring
firebase deploy --project default --only functions

# Watch logs
firebase functions:log --project default --follow

# Get function details
firebase functions:describe cleanupDuplicateEmails --project default
```

---

## Scheduled Functions

### Email Cleanup Task

```javascript
// Run daily at 2 AM UTC
exports.dailyEmailCleanup = functions
  .pubsub
  .schedule('0 2 * * *')  // Cron format
  .timeZone('UTC')
  .onRun(async (context) => {
    try {
      const result = await cleanupOldDuplicates();
      console.log('Daily cleanup completed:', result);
      return result;
    } catch (error) {
      console.error('Daily cleanup failed:', error);
      // Still return success so Cloud Scheduler doesn't retry
      return { success: false, error: error.message };
    }
  });
```

### Gravatar Sync

```javascript
// Weekly sync on Sunday at midnight
exports.weeklyGravatarSync = functions
  .pubsub
  .schedule('0 0 ? * SUN')  // Every Sunday at midnight
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    const batch = db.batch();
    
    try {
      const users = await db.collection('users').get();
      
      users.forEach((doc) => {
        const gravatar = getGravatarUrl(doc.data().email);
        batch.update(doc.ref, { 
          profilePicture: gravatar,
          gravatarSyncedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      });
      
      await batch.commit();
      console.log(`Synced ${users.docs.length} users to Gravatar`);
      
      return { synced: users.docs.length };
    } catch (error) {
      console.error('Gravatar sync failed:', error);
      return { success: false, error: error.message };
    }
  });
```

---

## Firestore Triggers

### Data Validation on Create

```javascript
// Validate payment data on creation
exports.validatePaymentOnCreate = functions
  .firestore
  .document('payments/{paymentId}')
  .onCreate(async (snap, context) => {
    const payment = snap.data();
    const errors = [];
    
    // Validation
    if (!payment.amount || payment.amount <= 0) {
      errors.push('Invalid amount');
    }
    if (!payment.tenantId || !payment.ownerId) {
      errors.push('Missing owner/tenant');
    }
    if (!['pending', 'completed', 'failed'].includes(payment.status)) {
      errors.push('Invalid status');
    }
    
    if (errors.length > 0) {
      // Log validation error
      console.error('Payment validation failed:', { 
        paymentId: context.params.paymentId, 
        errors 
      });
      
      // Update document to mark as invalid
      await snap.ref.update({ 
        validationErrors: errors,
        isValid: false 
      });
    }
    
    return { validated: errors.length === 0 };
  });
```

### Audit Logging

```javascript
// Log all writes for audit trail
exports.auditLogPaymentUpdate = functions
  .firestore
  .document('payments/{paymentId}')
  .onWrite(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    const auditLog = {
      paymentId: context.params.paymentId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      type: change.before.exists ? 'update' : 'create',
      before,
      after,
      changes: getFieldChanges(before, after)
    };
    
    // Store audit log
    await db
      .collection('audit_logs')
      .add(auditLog);
    
    // Also log to Cloud Logging
    console.log('Payment update:', JSON.stringify(auditLog));
    
    return auditLog;
  });

function getFieldChanges(before, after) {
  const changes = {};
  const allKeys = new Set([...Object.keys(before || {}), ...Object.keys(after || {})]);
  
  allKeys.forEach(key => {
    if (JSON.stringify(before?.[key]) !== JSON.stringify(after?.[key])) {
      changes[key] = { before: before?.[key], after: after?.[key] };
    }
  });
  
  return changes;
}
```

---

## Monitoring & Debugging

### Cloud Logging

```bash
# View function logs
firebase functions:log --project default

# Filter by function
firebase functions:log --project default | grep 'emailCleanup'

# Tail logs in real-time
firebase functions:log --project default --follow
```

### Error Tracking

```javascript
// Log errors with context
exports.trackedFunction = functions.https.onCall(async (data, context) => {
  const startTime = Date.now();
  
  try {
    const result = await processData(data);
    
    // Log success
    console.log({
      status: 'success',
      duration: Date.now() - startTime,
      result
    });
    
    return result;
  } catch (error) {
    // Log error with full context
    console.error({
      status: 'error',
      duration: Date.now() - startTime,
      error: error.message,
      stack: error.stack,
      input: data
    });
    
    throw new functions.https.HttpsError(
      'internal',
      'Operation failed'
    );
  }
});
```

### Performance Monitoring

```javascript
// Track execution time
exports.performantFunction = functions.https.onCall(async (data) => {
  const startTime = Date.now();
  
  const result = await heavyComputation(data);
  
  const duration = Date.now() - startTime;
  
  console.log({
    function: 'performantFunction',
    duration,
    threshold: 5000,
    exceedsThreshold: duration > 5000
  });
  
  return { result, duration };
});
```

---

## Cost Optimization

### 1. Reduce Invocations
```javascript
// Batch operations instead of individual calls
exports.batchCleanup = functions.https.onCall(async (data) => {
  const batch = db.batch();
  
  data.ids.forEach(id => {
    batch.delete(db.collection('duplicates').doc(id));
  });
  
  await batch.commit();  // Single write, not N writes
});
```

### 2. Minimize Memory Usage
```javascript
// Process in chunks to avoid high memory usage
async function processLargeDataset() {
  const pageSize = 100;
  let startAt = null;
  
  while (true) {
    let query = db.collection('items').limit(pageSize + 1);
    
    if (startAt) {
      query = query.startAfter(startAt);
    }
    
    const docs = await query.get();
    if (docs.empty) break;
    
    // Process this batch
    await processBatch(docs.docs.slice(0, pageSize));
    
    if (docs.docs.length <= pageSize) break;
    startAt = docs.docs[pageSize - 1];
  }
}
```

### 3. Use Firestore Batch Operations
```javascript
// Bad: N individual writes + costs
for (const id of ids) {
  await db.collection('items').doc(id).delete();
}

// Good: Single batch operation + lower cost
const batch = db.batch();
ids.forEach(id => {
  batch.delete(db.collection('items').doc(id));
});
await batch.commit();
```

---

## Security Best Practices

### 1. Validate All Inputs

```javascript
function validateEmailCleanupRequest(data) {
  if (!data.email) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Email is required'
    );
  }
  
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.email)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid email format'
    );
  }
  
  if (data.email.length > 254) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Email too long'
    );
  }
}
```

### 2. Rate Limiting

```javascript
const rateLimit = require('firebase-functions-rate-limit').default;

const limiter = rateLimit({
  name: 'emailCleanup',
  maxCalls: 10,           // Max 10 calls
  window: 3600000,        // Per hour
  key: (request) => request.auth.uid
});

exports.cleanupEmail = functions
  .https
  .onCall(limiter(async (data, context) => {
    return await processEmail(data.email);
  }));
```

### 3. Secure External API Calls

```javascript
// ✅ Use Secret Manager for API keys
const secretManager = require('@google-cloud/secret-manager');

async function getApiKey() {
  const [version] = await secretManager
    .v1beta1()
    .accessSecretVersion({
      name: 'projects/12345/secrets/gravatar-api-key/versions/latest'
    });
  
  return version.payload.data.toString();
}
```

---

## Testing Strategy

### Unit Tests

```javascript
// functions/test/emailCleanup.test.js
const admin = require('firebase-admin');
const test = require('firebase-functions-test')();
const { cleanupDuplicateEmails } = require('../index.js');

describe('Email Cleanup', () => {
  it('should remove duplicate emails', async () => {
    const wrapped = test.wrap(cleanupDuplicateEmails);
    
    const result = await wrapped({
      email: 'test@example.com'
    });
    
    expect(result.success).toBe(true);
  });
  
  it('should reject invalid email', async () => {
    const wrapped = test.wrap(cleanupDuplicateEmails);
    
    await expect(
      wrapped({ email: 'invalid' })
    ).rejects.toThrow('Invalid email');
  });
});
```

### Integration Tests

```bash
# Start emulator
firebase emulators:start --only functions,firestore

# Run tests against emulator
npm test
```

---

## Deployment Checklist

### Pre-Deployment

- [ ] All tests passing: `npm test`
- [ ] Linting passes: `npm run lint`
- [ ] No hardcoded secrets
- [ ] Error handling comprehensive
- [ ] Timeout values appropriate
- [ ] Memory allocation sufficient
- [ ] Rate limiting configured
- [ ] Input validation strict
- [ ] Code reviewed

### Deployment Steps

```bash
# 1. Deploy to staging
firebase deploy --project staging --only functions

# 2. Test in staging
curl -X POST https://staging-project.cloudfunctions.net/emailCleanup \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}'

# 3. Monitor staging logs
firebase functions:log --project staging --follow

# 4. Deploy to production
firebase deploy --project default --only functions

# 5. Verify production
firebase functions:describe emailCleanup --project default

# 6. Monitor production
firebase functions:log --project default --follow
```

### Post-Deployment

- [ ] Function execution working
- [ ] Error rates normal
- [ ] Response times acceptable
- [ ] Logs clean and informative
- [ ] No unexpected errors

---

## Common Issues

### Issue: Cold Start Latency

**Cause:** Function initialization taking too long

**Solution:**
- Minify dependencies
- Use Node.js 20 runtime
- Pre-warm functions with cron jobs

### Issue: Timeout Errors

**Cause:** Function exceeds timeout

**Solution:**
- Increase timeout with `runWith({ timeoutSeconds: ... })`
- Optimize database queries
- Use pagination for large datasets

### Issue: High Memory Usage

**Cause:** Loading too much data into memory

**Solution:**
- Process in chunks/streaming
- Limit batch sizes
- Use `runWith({ memory: '4GB' })`

---

## Related Documentation

- [FIREBASE_CONFIGURATION.md](./FIREBASE_CONFIGURATION.md) - Firebase setup
- [FIRESTORE_ARCHITECTURE.md](./FIRESTORE_ARCHITECTURE.md) - Data modeling
- [SECURITY_HARDENING_COMPLETE.md](./SECURITY_HARDENING_COMPLETE.md) - Security
- [Google Cloud Functions Docs](https://cloud.google.com/functions/docs)

