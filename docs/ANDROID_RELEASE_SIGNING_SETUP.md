# Android Release Signing Setup (Play Store)

## Why this is critical

- Release builds must never use the debug keystore.
- Losing your upload keystore blocks future update uploads.
- Keystore credentials must stay out of source control.

## 1. Generate upload keystore

Run from repository root:

keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

Best practices:

- Use strong, unique passwords.
- Keep an offline backup of upload-keystore.jks.
- Do not rename or lose the keystore file.
- Store alias/passwords in a secure password vault.

## 2. Create android/key.properties

Copy template:

- Source: android/key.properties.example
- Target: android/key.properties

Expected keys:

- storePassword
- keyPassword
- keyAlias
- storeFile

Default template path points to:

- ../upload-keystore.jks

## 3. Git safety

These are ignored by .gitignore:

- android/key.properties
- \*.jks
- \*.keystore
- upload-keystore.jks

Never commit keystores or passwords.

## 4. Gradle release behavior

Release builds now enforce:

- android/key.properties must exist
- required keys must be present
- storeFile path must resolve to an existing keystore
- release signing config (not debug)
- minify and resource shrinking enabled

## 5. Play App Signing recommendation

Enable Play App Signing in Google Play Console:

- Google manages the app signing key securely.
- You keep only the upload key.
- Better operational recovery if upload key is lost.

## 6. CI/CD security

- Inject key.properties values from CI secrets.
- Store keystore in encrypted CI secret storage/artifacts.
- Restrict deployment permissions to release maintainers.
- Do not print credentials in CI logs.

## 7. Release verification

1. Build production release AAB:
   - flutter build appbundle --flavor production --release
2. Verify signature:
   - apksigner verify --print-certs path/to/app-release.aab
3. Install/test on physical device.
4. Confirm no debug signing references remain.

## 8. Common anti-patterns to avoid

- Using debug signing for production.
- Committing key.properties or keystore files.
- Hardcoding passwords in Gradle files.
- Sharing keystores through insecure channels.
