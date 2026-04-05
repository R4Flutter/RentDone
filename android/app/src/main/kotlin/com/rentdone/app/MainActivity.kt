package com.rentdone.app

import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {
	private var nativeAdFactory: CreditCardNativeAdFactory? = null
	private val admobAppIdPattern = Regex("^ca-app-pub-[0-9]{16}~[0-9]{10}$")
	private val admobTestAppId = "ca-app-pub-3940256099942544~3347511713"

	override fun onCreate(savedInstanceState: Bundle?) {
		if (!BuildConfig.DEBUG && BuildConfig.ADMOB_IS_PRODUCTION) {
			val admobId = BuildConfig.ADMOB_APP_ID
			check(admobId.isNotBlank()) { "AdMob App ID missing for production runtime" }
			check(admobId != admobTestAppId) { "AdMob test App ID is forbidden in production runtime" }
			check(admobAppIdPattern.matches(admobId)) { "Invalid AdMob App ID format in production runtime" }
		}
		super.onCreate(savedInstanceState)
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		nativeAdFactory = CreditCardNativeAdFactory(this)
		GoogleMobileAdsPlugin.registerNativeAdFactory(
			flutterEngine,
			"creditCardNativeFactory",
			nativeAdFactory!!,
		)
	}

	override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
		GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "creditCardNativeFactory")
		nativeAdFactory = null
		super.cleanUpFlutterEngine(flutterEngine)
	}
}
