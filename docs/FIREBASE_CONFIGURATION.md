# 🔧 Firebase Configuration & Project Structure

**Professional Setup Guide for Production**

---

## Overview

This guide outlines production-ready Firebase configuration with best practices for security, scalability, and team collaboration.

---

## Firebase Configuration Files

### `firebase.json` - Main Configuration

Your current production configuration:

```json
{
  "flutter": {
    "platforms": {
      "android": {
        "default": {
          "projectId": "rentdone-92c6f",
          "appId": "1:35844123331:android:3e3ff565505d29efb85076",
          "fileOutput": "android/app/google-services.json"
        }
      },
      "dart": {
        "lib/firebase_options.dart": {
          "projectId": "rentdone-92c6f",
          "configurations": {
            "android": "1:35844123331:android:3e3ff565505d29efb85076",
            "ios": "1:35844123331:ios:addaee0c2de20b92b85076",
            "macos": "1:35844123331:ios:addaee0c2de20b92b85076",
            "web": "1:35844123331:web:3c521fcb8545dd50b85076",
            "windows": "1:35844123331:web:96c9b87c3ea976e3b85076"
          }
        }
      }
    }
  },
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "functions": {
    "source": "functions"
  }
}
```

**Best Practices:**
- ✅ Separate iOS and macOS configurations
- ✅ Web configuration properly configured
- ✅ Firestore rules path documented
- ✅ Indexes path documented

---

## Project Structure

### Ideal Firebase Project Organization

```
rentdone/
├── firebase.json                    # Firebase CLI config (committed)
├── .firebaserc                      # Firebase project aliases (committed)
├── firestore.rules                  # Security rules (committed)
├── firestore.indexes.json           # Indexes config (committed)
├── firebaseEmulator.json            # Local emulator config (optional)
│
├── functions/                       # Cloud Functions
│   ├── package.json
│   ├── .eslintrc
│   ├── .env.local
│   ├── src/
│   │   ├── index.ts
│   │   ├── config/
│   │   ├── services/
│   │   ├── middleware/
│   │   └── utils/
│   └── tests/
│
├── lib/                             # Flutter app
│   ├── firebase/
│   │   └── firebase_config.dart     # Firebase initialization
│   ├── core/
│   │   └── exceptions/
│   │       └── security_exceptions.dart
│   ├── features/
│   │   └── */data/services/         # Firebase services
│   └── main.dart
│
├── docs/                            # Documentation
│   ├── FIRESTORE_ARCHITECTURE.md    # This guide
│   ├── SECURITY_HARDENING.md
│   └── DEPLOYMENT_CHECKLIST.md
│
└── android/, ios/, web/, etc.       # Platform-specific files
```

---

## Firebase CLI Setup

### Installation & Authentication

```bash
# Install Firebase CLI (global)
npm install -g firebase-tools

# Authenticate
firebase login

# List projects
firebase projects:list

# Set default project
firebase use rentdone-92c6f
```

### Create `.firebaserc` for Multiple Environments

```json
{
  "projects": {
    "default": "rentdone-92c6f",
    "staging": "rentdone-staging-123",
    "development": "rentdone-dev-456"
  },
  "targets": {
    "rentdone-92c6f": {
      "firestore": ["prod"]
    },
    "rentdone-staging-123": {
      "firestore": ["staging"]
    }
  }
}
```

**Usage:**
```bash
# Deploy to staging
firebase deploy --project staging

# Deploy to production
firebase deploy --project default
```

---

## Firestore Configuration

### `firestore.rules` - Security Rules Best Practices

**File Location:** `./firestore.rules`

**Structure:**
```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // === HELPER FUNCTIONS ===
    function isAuthenticated() { ... }
    function currentUid() { ... }
    function isOwner() { ... }
    
    // === COLLECTION RULES ===
    match /users/{userId} { ... }
    match /owners/{ownerId} { ... }
    match /properties/{propertyId} { ... }
    match /tenants/{tenantId} { ... }
    match /payments/{paymentId} { ... }
    
    // === CATCH-ALL (Explicit Deny) ===
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

**Deployment:**
```bash
# Validate rules
firebase rules:test firestore.rules

# Deploy rules (safe, no data affected)
firebase deploy --only firestore:rules

# Deploy with other services
firebase deploy
```

---

### `firestore.indexes.json` - Index Configuration

**File Location:** `./firestore.indexes.json`

**Complete Production Indexes:**

```json
{
  "indexes": [
    {
      "collectionGroup": "payments",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "ownerId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "payments",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "ownerId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "tenants",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "ownerId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

**Deployment:**
```bash
# Deploy indexes
firebase deploy --only firestore:indexes

# Monitor index creation
firebase firestore:indexes
```

---

## Environment Configuration

### Development, Staging, Production

Create separate projects for each environment:

```
rentdone-dev-456    (Development)
  ├── Unlimited billing
  ├── All features enabled
  └── Relaxed security rules

rentdone-staging-123 (Staging)
  ├── Data close to production
  ├── Full security rules
  └── Load testing enabled

rentdone-92c6f       (Production)
  ├── Strict monitoring
  ├── All security rules enforced
  └── Automated backups
```

**Switch Environments:**
```bash
# Development
firebase use development

# Staging
firebase use staging

# Production
firebase use default
```

---

## Security Best Practices

### 1. Protect `google-services.json` and Config Files

```gitignore
# .gitignore
google-services.json          # Android
GoogleService-Info.plist      # iOS
.env                          # Environment variables
.env.local                    # Local overrides
.firebase/                    # Local emulator data
```

### 2. Secure API Keys

**❌ Don't commit Firebase config to public repos**
```dart
// ❌ WRONG - Hardcoded keys
const apiKey = "AIzaSyD..."; // PUBLIC KEY (OK)
```

**✅ Do use Firebase initialization**
```dart
// ✅ CORRECT - Use generated firebase_options.dart
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}
```

### 3. Implement Firestore Security Rules

```firestore
// ✅ Good: Explicit ownership check
match /payments/{paymentId} {
  allow read: if resource.data.ownerId == request.auth.uid;
  allow create: if request.auth.uid != null
                && request.resource.data.ownerId == request.auth.uid;
}

// ❌ Bad: Open access
match /payments/{paymentId} {
  allow read, write: if request.auth != null;
}
```

---

## Monitoring & Logging

### Firebase Console Metrics

Monitor in Firebase Console:

1. **Firestore Usage**
   - Read/Write operations
   - Storage usage
   - Real-time database stats

2. **Security & Alerts**
   - Failed permission checks
   - Authentication failures
   - Unusual activity

3. **Performance**
   - Query latencies
   - Index creation status
   - Data distribution

### Enable Cloud Logging

```bash
# View production logs
firebase functions:log

# Detailed Firestore logs
firebase firestore:indexes
```

---

## Deployment Procedures

### Pre-Deployment Checklist

- [ ] **Code Review**
  - Changes reviewed by team lead
  - No hardcoded secrets

- [ ] **Testing**
  - Unit tests pass
  - Integration tests pass
  - Security rules tested

- [ ] **Rules Validation**
  ```bash
  firebase rules:test firestore.rules
  ```

- [ ] **Staging Deployment**
  ```bash
  firebase deploy --project staging
  ```

- [ ] **Monitoring**
  - 24 hours on staging
  - Error rates normal
  - Performance acceptable

### Production Deployment Steps

```bash
# 1. Create deployment backup
firebase firestore:export gs://your-backup-bucket

# 2. Deploy rules (safe, non-breaking)
firebase deploy --only firestore:rules

# 3. Deploy indexes (if changed)
firebase deploy --only firestore:indexes

# 4. Deploy full stack
firebase deploy

# 5. Monitor logs
firebase functions:log
```

---

## Backup & Recovery

### Automated Daily Backups

Configure in Google Cloud Console:

1. Go to **Firestore** > **Schedules**
2. Create daily backup schedule
3. Retention: 30 days (production standard)

### Manual Backup

```bash
# Export to Cloud Storage
firebase firestore:export gs://your-backup-bucket/$(date +%Y%m%d-%H%M%S)

# Restore from backup
firebase firestore:restore gs://your-backup-bucket/20240320-120000
```

---

## Scaling Considerations

### Firestore Scaling Limits

| Aspect | Limit | Status |
|--------|-------|--------|
| **Writes per second (single doc)** | 1 | Safe with batching |
| **Reads per second** | 10,000+ | Unlimited with indexes |
| **Document size** | 1MB | Use references for large data |
| **Batch operations** | 500 | Split into multiple batches |

### Optimization Strategies

1. **Use Collection Groups**
   - Query `payments` subcollections across all tenants
   - More efficient than joins

2. **Denormalization**
   - Cache frequently accessed data
   - Update via Cloud Functions

3. **Sharding**
   - For hot collections (counter documents)
   - Distribute writes across multiple documents

---

## Common Issues & Solutions

### Issue: "Composite index required"

**Cause:** Query needs an index that doesn't exist

**Solution:**
```bash
firebase deploy --only firestore:indexes
```

### Issue: "Permission denied" errors

**Cause:** Security rules blocking legitimate access

**Solution:**
1. Review rules in `firestore.rules`
2. Check user's `uid` vs. `ownerId` in data
3. Test with `firebase rules:test`

### Issue: Slow queries

**Cause:** Missing index or suboptimal query

**Solution:**
1. Check `firestore.indexes.json`
2. Monitor query latencies in Firebase Console
3. Add composite index if needed

---

## Team Collaboration

### `.firebaserc` - Share Project Config

```json
{
  "projects": {
    "default": "rentdone-92c6f"
  }
}
```

**Commit to repo** so team uses same project.

### Rules Review Process

1. Developer creates PR with `firestore.rules` changes
2. Code review (security focus)
3. Test on staging with `firebase deploy --project staging`
4. Monitor for errors
5. Merge and deploy to production

### Documentation

- [ ] `FIRESTORE_ARCHITECTURE.md` - Data model
- [ ] `SECURITY_HARDENING.md` - Security measures
- [ ] `DEPLOYMENT_CHECKLIST.md` - Deployment process
- [ ] Rules comments - In `firestore.rules`

---

## Performance Optimization Tips

### 1. Use Pagination
```dart
// Good: Limit queries to 20 results
.limit(20)
.get()

// Bad: Fetch all documents
.get()
```

### 2. Create Proper Indexes
```bash
firebase firestore:indexes  # List all indexes
```

### 3. Cache with Cloud Functions
```typescript
// Cache frequently accessed data
const cache = new Map();
```

### 4. Use Batch Writes
```dart
WriteBatch batch = FirebaseFirestore.instance.batch();
batch.set(docRef1, data1);
batch.set(docRef2, data2);
await batch.commit();  // Single transaction
```

---

## Launch Readiness Checklist

- [x] Firebase project created
- [x] Authentication configured
- [x] Firestore security rules implemented
- [x] Indexes created
- [x] Data model documented
- [x] Backup strategy configured
- [ ] Monitoring alerts set up
- [ ] Team trained on procedures
- [ ] Disaster recovery plan
- [ ] Security audit completed

---

## Related Documentation

- [FIRESTORE_ARCHITECTURE.md](./FIRESTORE_ARCHITECTURE.md) - Data modeling
- [SECURITY_HARDENING_COMPLETE.md](./SECURITY_HARDENING_COMPLETE.md) - Security implementation
- [Official Firebase Docs](https://firebase.google.com/docs)
- [Firestore Best Practices](https://firebase.google.com/docs/firestore/best-practices)

