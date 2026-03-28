package com.example.rentdone

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {
	private var nativeAdFactory: CreditCardNativeAdFactory? = null

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
