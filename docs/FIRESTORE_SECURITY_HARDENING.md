# Firestore Security Hardening

## What Changed

- Disabled all list queries on private users collection.
- Restricted private user reads to self only.
- Added dedicated publicProfiles collection for safe cross-user profile data.
- Added validation for allowed public profile fields only.
- Added helper relationship function isTenantOfOwner(ownerId) for relationship-aware rule extensions.

## Rules Summary

- /users/{userId}
  - get: authenticated user can read only their own document.
  - list: denied.
  - create/update: authenticated user can write only their own document with existing field constraints.
  - delete: denied.

- /publicProfiles/{userId}
  - get: any authenticated user.
  - list: denied.
  - create/update: authenticated user can write only their own public profile document.
  - delete: denied.

## Allowed publicProfiles Fields

- name
- phone_optional
- rating
- profileImage
- updatedAt

## Data Migration

Run one-time migration to seed publicProfiles from users:

```bash
node tools/migrate_users_to_public_profiles.js
```

## Attack Simulation Checklist

Run with Firestore Emulator and verify all expectations.

1. Attempt list query on users with limit=1
- Query: users.limit(1).get()
- Expected: denied.

2. Attempt read of another user private doc
- Query: users/{otherUid}
- Expected: denied.

3. Attempt repeated scraping with different user IDs
- Query: users/{uid1}, users/{uid2}, users/{uid3} as same actor
- Expected: only own uid returns, all others denied.

4. Attempt read of public profile
- Query: publicProfiles/{targetUid}
- Expected: allowed when authenticated.

5. Attempt write to another user's public profile
- Query: write publicProfiles/{otherUid}
- Expected: denied.

## Production Checklist

1. Deploy updated firestore.rules.
2. Run users -> publicProfiles migration script.
3. Update any client views that read other users from users collection to read publicProfiles.
4. Run emulator attack simulation checklist.
5. Enable Firestore Data Access audit logging in GCP for monitoring.
