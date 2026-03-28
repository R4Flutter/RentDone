import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:rentdone/core/ads/admob_config.dart';

class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({super.key});

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    if (!AdMobConfig.shouldLoadNativeAds) {
      return;
    }

    final ad = NativeAd(
      adUnitId: AdMobConfig.nativeUnitId,
      request: const AdRequest(
        keywords: <String>['credit card', 'cashback', 'rent payment', 'upi'],
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _nativeAd = ad as NativeAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _nativeAd = null;
            _isLoaded = false;
          });
        },
      ),
      // Native ads require a factory configured in platform code.
      // If missing, the ad will fail and this widget stays hidden.
      factoryId: 'creditCardNativeFactory',
    );

    ad.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdMobConfig.shouldLoadNativeAds) {
      return const SizedBox.shrink();
    }

    if (!_isLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: AdWidget(ad: _nativeAd!),
      ),
    );
  }
}
