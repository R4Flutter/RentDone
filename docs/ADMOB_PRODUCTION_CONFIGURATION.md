# AdMob Production Configuration Guard

Last updated: April 5, 2026

## Objective

Ensure production Android builds use only valid live AdMob IDs and fail fast when configuration is missing or unsafe.

## Environment keys

- Production App ID: `ADMOB_APP_ID_PRODUCTION`
- Non-production App ID: `ADMOB_APP_ID_TEST`
- Backward-compatible non-production alias: `ADMOB_APP_ID_STAGING`

## Strict validation implemented

1. Non-empty check

- `ADMOB_APP_ID_PRODUCTION` must not be blank for production flavor builds.

2. Test ID block (release)

- Blocked test App ID in production/release:
  - `ca-app-pub-3940256099942544~3347511713`

3. Format validation

- Required App ID format:
  - `^ca-app-pub-[0-9]{16}~[0-9]{10}$`

4. Runtime guard

- `MainActivity` validates `BuildConfig.ADMOB_APP_ID` in non-debug production runtime and crashes on invalid values.

5. Dart-side production guard

- `AdMobConfig.enforceProductionGuardrails()` validates app ID and required ad unit IDs in non-debug mode.

## Build-time injection and separation

- `android/app/build.gradle.kts` injects:
  - `BuildConfig.ADMOB_APP_ID`
  - `BuildConfig.ADMOB_IS_PRODUCTION`
- Flavor behavior:
  - `staging`: uses `ADMOB_APP_ID_TEST` (or `ADMOB_APP_ID_STAGING` fallback)
  - `production`: uses `ADMOB_APP_ID_PRODUCTION` only

## CI/CD enforcement

Workflow: `.github/workflows/android-release-guard.yml`

Required secret:

- `ADMOB_APP_ID_PRODUCTION`

The workflow fails if:

- secret is missing
- test App ID is used
- App ID format is invalid

## Flutter build command (production)

Use production App ID in Dart define:

`flutter build appbundle --flavor production --release --dart-define=ADMOB_APP_ID=<your-live-app-id>`

Also define release ad unit IDs:

- `ADMOB_NATIVE_CREDIT_UNIT`
- `ADMOB_REWARDED_CREDIT_UNIT`
- `ADMOB_BANNER_TRANSACTION_UNIT`

## Risk mapping

- Missing ID: startup/runtime failure or ad initialization failure
- Test ID in release: policy violation risk
- Wrong ID: monetization loss
- Hardcoded ID: operational/security risk

## Play Store reminders

- Keep AdMob usage reflected in Privacy Policy and Data safety form.
- Ensure production IDs are used only in release builds.
