package com.example.rentdone

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class CreditCardNativeAdFactory(private val context: Context) : GoogleMobileAdsPlugin.NativeAdFactory {
    override fun createNativeAd(nativeAd: NativeAd, customOptions: MutableMap<String, Any>?): NativeAdView {
        val adView = LayoutInflater.from(context)
            .inflate(R.layout.native_credit_card_ad, null) as NativeAdView

        val headline = adView.findViewById<TextView>(R.id.ad_headline)
        val body = adView.findViewById<TextView>(R.id.ad_body)
        val advertiser = adView.findViewById<TextView>(R.id.ad_advertiser)
        val cta = adView.findViewById<Button>(R.id.ad_call_to_action)

        adView.headlineView = headline
        adView.bodyView = body
        adView.advertiserView = advertiser
        adView.callToActionView = cta

        headline.text = nativeAd.headline

        if (nativeAd.body == null) {
            body.visibility = View.GONE
        } else {
            body.visibility = View.VISIBLE
            body.text = nativeAd.body
        }

        if (nativeAd.advertiser == null) {
            advertiser.visibility = View.GONE
        } else {
            advertiser.visibility = View.VISIBLE
            advertiser.text = nativeAd.advertiser
        }

        if (nativeAd.callToAction == null) {
            cta.visibility = View.GONE
        } else {
            cta.visibility = View.VISIBLE
            cta.text = nativeAd.callToAction
        }

        adView.setNativeAd(nativeAd)
        return adView
    }
}
