import 'package:flutter/foundation.dart';

class AdMobConfig {
  AdMobConfig._();

  // User-provided AdMob app ID.
  static const String appId = 'ca-app-pub-5463912491137261~7897724434';

  static const String _releaseNativeUnit = String.fromEnvironment(
    'ADMOB_NATIVE_CREDIT_UNIT',
    defaultValue: 'ca-app-pub-5463912491137261/9866674007',
  );

  static const String _releaseRewardedUnit = String.fromEnvironment(
    'ADMOB_REWARDED_CREDIT_UNIT',
    defaultValue: 'ca-app-pub-5463912491137261/6269074309',
  );

  static const String _testNativeAndroid =
      'ca-app-pub-3940256099942544/2247696110';
  static const String _testNativeIos =
      'ca-app-pub-3940256099942544/3986624511';

  static const String _testRewardedAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedIos =
      'ca-app-pub-3940256099942544/1712485313';

  static bool get isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static bool get useTestAds {
    return kDebugMode;
  }

  // Debug sessions can be noisy due to Android platform view log spam
  // from native ads. Keep this off by default in debug and enable only
  // when explicitly validating native ad integration.
  static bool get enableNativeAdsInDebug {
    return const bool.fromEnvironment(
      'ENABLE_NATIVE_ADS_IN_DEBUG',
      defaultValue: false,
    );
  }

  static bool get shouldLoadNativeAds {
    return !kDebugMode || enableNativeAdsInDebug;
  }

  static String get nativeUnitId {
    if (useTestAds) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? _testNativeIos
          : _testNativeAndroid;
    }
    return _releaseNativeUnit;
  }

  static String get rewardedUnitId {
    if (useTestAds) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? _testRewardedIos
          : _testRewardedAndroid;
    }
    return _releaseRewardedUnit;
  }

  static bool get isAffiliateEnabled {
    return const bool.fromEnvironment(
      'ENABLE_CREDIT_CARD_AFFILIATE',
      defaultValue: true,
    );
  }

  static String get affiliateCreditCardUrl {
    return const String.fromEnvironment(
      'CREDIT_CARD_AFFILIATE_URL',
      defaultValue: 'https://example.com/credit-card-offer',
    );
  }
}
