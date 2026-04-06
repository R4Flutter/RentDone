import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val isReleaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()

if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { stream ->
        keystoreProperties.load(stream)
    }
}

val admobAppIdPattern = Regex("^ca-app-pub-[0-9]{16}~[0-9]{10}$")
val admobTestAppId = "ca-app-pub-3940256099942544~3347511713"

fun validateAdmobAppId(id: String, label: String, allowTestId: Boolean) {
    val normalized = id.trim()
    if (normalized.isBlank()) {
        throw GradleException("$label must not be empty.")
    }
    if (!allowTestId && normalized == admobTestAppId) {
        throw GradleException("$label must not use the AdMob test app ID in production/release builds.")
    }
    if (!admobAppIdPattern.matches(normalized)) {
        throw GradleException("$label has invalid format. Expected: ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX")
    }
}

android {
    namespace = "com.rentdone.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    val admobAppIdTest = providers.gradleProperty("ADMOB_APP_ID_TEST")
        .orElse(providers.environmentVariable("ADMOB_APP_ID_TEST"))
        .orElse(providers.gradleProperty("ADMOB_APP_ID_STAGING"))
        .orElse(admobTestAppId)
        .get()
        .trim()
    val admobAppIdProduction = providers.gradleProperty("ADMOB_APP_ID_PRODUCTION")
        .orElse(providers.environmentVariable("ADMOB_APP_ID_PRODUCTION"))
        .orElse("")
        .get()
        .trim()
    val admobAppIdProductionForConfig = if (admobAppIdProduction.isBlank()) admobTestAppId else admobAppIdProduction

    validateAdmobAppId(admobAppIdTest, "ADMOB_APP_ID_TEST/ADMOB_APP_ID_STAGING", allowTestId = true)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.rentdone.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = admobAppIdTest
    }

    buildFeatures {
        buildConfig = true
    }

    flavorDimensions += "env"
    productFlavors {
        create("staging") {
            dimension = "env"
            manifestPlaceholders["admobAppId"] = admobAppIdTest
            buildConfigField("String", "ADMOB_APP_ID", "\"$admobAppIdTest\"")
            buildConfigField("boolean", "ADMOB_IS_PRODUCTION", "false")
        }
        create("production") {
            dimension = "env"
            manifestPlaceholders["admobAppId"] = admobAppIdProductionForConfig
            buildConfigField("String", "ADMOB_APP_ID", "\"$admobAppIdProductionForConfig\"")
            buildConfigField("boolean", "ADMOB_IS_PRODUCTION", "true")
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

if (isReleaseTaskRequested) {
    if (!keystorePropertiesFile.exists()) {
        throw GradleException(
            "Missing android/key.properties. Create it from android/key.properties.example for release builds.",
        )
    }

    val requiredKeys = listOf("storePassword", "keyPassword", "keyAlias", "storeFile")
    val missingKeys = requiredKeys.filter { key ->
        (keystoreProperties[key] as String?)?.isBlank() != false
    }

    if (missingKeys.isNotEmpty()) {
        throw GradleException(
            "android/key.properties is missing required keys: ${missingKeys.joinToString(", ")}",
        )
    }

    val storeFilePath = keystoreProperties["storeFile"] as String
    val resolvedStoreFile = file(storeFilePath)
    if (!resolvedStoreFile.exists()) {
        throw GradleException(
            "Keystore file not found at '$storeFilePath'. Ensure storeFile points to a valid upload keystore.",
        )
    }
}

if (gradle.startParameter.taskNames.any {
        it.contains("Production", ignoreCase = true) && it.contains("Release", ignoreCase = true)
    }
) {
    val productionId = providers.gradleProperty("ADMOB_APP_ID_PRODUCTION")
        .orElse(providers.environmentVariable("ADMOB_APP_ID_PRODUCTION"))
        .orElse("")
        .get()
        .trim()
    validateAdmobAppId(productionId, "ADMOB_APP_ID_PRODUCTION", allowTestId = false)
}

flutter {
    source = "../.."
}
