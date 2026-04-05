# Android Package Finalization (com.rentdone.app)

## Finalized package name

- Permanent Android package identity: com.rentdone.app

## Updated in codebase

- android/app/build.gradle.kts
  - namespace = "com.rentdone.app"
  - applicationId = "com.rentdone.app"
- android/app/src/main/AndroidManifest.xml
  - manifest package set to com.rentdone.app
- Kotlin source package declarations
  - package com.rentdone.app
- Kotlin folder structure
  - android/app/src/main/kotlin/com/rentdone/app/

## Required Firebase action (manual)

Current google-services.json still contains old package:

- com.example.rentdone

You must update Firebase configuration:

1. In Firebase Console, add (or recreate) Android app with package: com.rentdone.app
2. Download the new google-services.json
3. Replace android/app/google-services.json
4. Rebuild Android app

If not replaced, Android build fails with:

- No matching client found for package name 'com.rentdone.app'

## Verification checklist

1. ./android/gradlew :app:assembleStagingDebug (should pass after new google-services.json)
2. flutter build appbundle --flavor production --release
3. Validate Firebase Auth/FCM/Analytics on a device
4. Confirm Play Console listing uses com.rentdone.app
