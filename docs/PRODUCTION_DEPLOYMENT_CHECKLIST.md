# RentDone — Production Deployment Checklist

Use this checklist before every production release.

---

## 1. Firebase Configuration

- [ ] **Firebase Project** is set to the production project (not dev/staging)
- [ ] **App Check** enforcement is enabled in Firebase Console → App Check → APIs
- [ ] **Firestore Security Rules** deployed: `firebase deploy --only firestore:rules`
- [ ] **Storage Security Rules** deployed: `firebase deploy --only storage`
- [ ] **Firestore Indexes** deployed: `firebase deploy --only firestore:indexes`
- [ ] **Cloud Functions** deployed: `cd functions && npm run build && firebase deploy --only functions`
- [ ] **Firebase Analytics** enabled in Firebase Console
- [ ] **Firebase Crashlytics** enabled in Firebase Console

## 2. Razorpay Configuration

- [ ] **Production Razorpay keys** are configured in Cloud Functions secrets:
  - `RAZORPAY_KEY_ID_LIVE`
  - `RAZORPAY_KEY_SECRET_LIVE`
  - `RAZORPAY_MODE=live`
- [ ] **Webhook URL** is configured in Razorpay Dashboard → Settings → Webhooks
- [ ] **Test payment** completed successfully in test mode before switching to live

## 3. Android Signing

- [ ] **Release keystore** (`upload-keystore.jks`) exists and is securely stored
- [ ] **`android/key.properties`** is populated with correct credentials:
  ```properties
  storePassword=<your-store-password>
  keyPassword=<your-key-password>
  keyAlias=upload
  storeFile=../upload-keystore.jks
  ```
- [ ] **key.properties is NOT committed** to git (verify `.gitignore`)
- [ ] **Play Console** upload key is registered for App Signing

## 4. Environment Variables (CI/CD)

Ensure GitHub Secrets contain:
- [ ] `ADMOB_APP_ID_PRODUCTION` — Real AdMob App ID (NOT the Google test ID)
- [ ] `RAZORPAY_KEY_ID` — Production Razorpay key
- [ ] Keystore credentials if CI builds the release APK/AAB

## 5. Build Verification

```bash
# Run analysis
flutter analyze --fatal-infos

# Run tests
flutter test

# Build production AAB
flutter build appbundle --flavor production --release \
  --dart-define=ADMOB_APP_ID=$ADMOB_APP_ID_PRODUCTION
```

- [ ] `flutter analyze` returns zero issues
- [ ] All unit tests pass
- [ ] Production build completes without errors
- [ ] APK/AAB size is reasonable (< 30MB for APK)

## 6. Pre-Launch Checks

- [ ] **App version** bumped in `pubspec.yaml` (`version:`)
- [ ] **Changelog** updated
- [ ] **No `debugPrint`** outside `app_logger.dart` (run: `grep -r debugPrint lib/`)
- [ ] **No hardcoded test keys** in source code
- [ ] **ProGuard rules** configured for release shrinking
- [ ] **Crashlytics** receives test crash: `FirebaseCrashlytics.instance.crash()`

## 7. Play Store Submission

- [ ] **App listing** (title, description, screenshots) is complete
- [ ] **Privacy policy URL** is set
- [ ] **Content rating** questionnaire completed
- [ ] **Target audience** and data safety form filled
- [ ] **Internal testing track** verified before production rollout
- [ ] **Staged rollout** enabled (start at 5-10%)

## 8. Post-Launch Monitoring

- [ ] **Crashlytics dashboard** — monitor for new crashes in first 24h
- [ ] **Analytics events** — verify payment_success, payment_failure events flowing
- [ ] **Cloud Functions logs** — check for errors in Firebase Console → Functions → Logs
- [ ] **Error rate alerts** — set up Crashlytics alerts for crash-free rate < 99%

---

> **Tip:** Run the Android Release Guard CI workflow (`android-release-guard.yml`) to automatically validate AdMob IDs and build the production bundle before submission.
