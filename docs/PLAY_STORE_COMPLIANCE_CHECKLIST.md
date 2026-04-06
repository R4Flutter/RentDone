# Play Store Compliance Checklist (RentDone)

Last updated: April 5, 2026

This checklist maps product, policy, and release tasks needed before Google Play production submission.

## 1. Privacy Policy and Legal Disclosures

- [ ] Host public privacy policy URL at `https://rentdone.app/privacy-policy`.
- [ ] Ensure policy URL is accessible without login and without geo-blocking.
- [ ] Ensure policy content matches app behavior and SDKs in production.
- [ ] Set the same policy URL in Play Console -> App content -> Privacy Policy.
- [ ] Verify in-app policy entry exists for owner and tenant flows.

## 2. Data Safety Form (Play Console)

- [ ] Declare data collection for account details (name, email, phone).
- [ ] Declare payment-related metadata handling.
- [ ] Declare analytics and crash diagnostics usage.
- [ ] Declare optional location usage if enabled in production.
- [ ] Declare ad-related identifiers if AdMob is active.
- [ ] Confirm each declared purpose (app functionality, analytics, fraud prevention, etc.) matches actual code.

## 3. Account and User Data Requirements

- [ ] Provide clear in-app account deletion path or documented deletion request flow.
- [ ] Ensure deletion requests remove or anonymize user data within policy commitments.
- [ ] Confirm signed-in user can access profile and privacy controls easily.

## 4. Permission Hygiene

- [ ] Keep only permissions required by active features.
- [ ] Remove or justify background/sensitive permissions.
- [ ] Ensure runtime permission prompts include clear user-facing reason.
- [ ] Validate no hidden or undocumented data access paths exist.

## 5. Ads and Monetization Compliance

- [ ] Use production AdMob IDs in production builds only.
- [ ] Confirm no test ad IDs are shipped in release flavor.
- [ ] Label ad surfaces clearly where required.
- [ ] Ensure ad personalization disclosures are reflected in policy and Data Safety.

## 6. Payments and Financial Safety

- [ ] Verify payment flows are server-authoritative for quote/intent/verification.
- [ ] Ensure payment failures do not expose sensitive internals to users.
- [ ] Ensure webhook and callback validation is enabled in backend.
- [ ] Confirm refund/support contact paths are visible to users.

## 7. Security and Stability Gates

- [ ] Run `flutter analyze` and resolve high-priority warnings before release.
- [ ] Run unit tests and critical integration tests on release candidate.
- [ ] Deploy and validate Firestore and Storage rules in staging before production.
- [ ] Validate Crashlytics and Analytics are enabled only in intended environments.

## 8. Release Build Readiness

- [ ] Confirm Android package name matches Firebase config (`google-services.json`).
- [ ] Build signed `productionRelease` APK/AAB with release keystore.
- [ ] Verify app name, icon, versionCode/versionName, and Play listing metadata.
- [ ] Validate deep links, login redirects, and role guards on release build.

## 9. Submission Artifacts

- [ ] Update store listing privacy text and support email.
- [ ] Upload current screenshots that reflect latest UI and policy access.
- [ ] Add short "What's New" notes for the release.
- [ ] Complete content rating and app access declarations.

## 10. Final Go/No-Go

- [ ] Dry-run checklist review with engineering + product owner.
- [ ] Confirm no blocker remains in Play Console pre-launch report.
- [ ] Tag release commit and archive release notes/checklist snapshot.

---

Notes:

- Keep this checklist in sync with `docs/PRIVACY_POLICY.md` and Play Console declarations.
- Any new SDK, permission, or data category must update both policy and Data Safety before release.
