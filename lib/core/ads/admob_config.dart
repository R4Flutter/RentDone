import 'package:flutter/foundation.dart';

class AdMobConfig {
  AdMobConfig._();

  static final RegExp _appIdPattern = RegExp(
    r'^ca-app-pub-[0-9]{16}~[0-9]{10}$',
  );
  static final RegExp _unitIdPattern = RegExp(
    r'^ca-app-pub-[0-9]{16}/[0-9]{10}$',
  );
  static const String _testAppId = 'ca-app-pub-3940256099942544~3347511713';

  static const String appId = String.fromEnvironment(
    'ADMOB_APP_ID',
    defaultValue: '',
  );

  static const String _releaseNativeUnit = String.fromEnvironment(
    'ADMOB_NATIVE_CREDIT_UNIT',
    defaultValue: '',
  );

  static const String _releaseRewardedUnit = String.fromEnvironment(
    'ADMOB_REWARDED_CREDIT_UNIT',
    defaultValue: '',
  );

  static const String _releaseBannerTransactionUnit = String.fromEnvironment(
    'ADMOB_BANNER_TRANSACTION_UNIT',
    defaultValue: '',
  );

  static const String _testNativeAndroid =
      'ca-app-pub-3940256099942544/2247696110';
  static const String _testNativeIos = 'ca-app-pub-3940256099942544/3986624511';

  static const String _testRewardedAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedIos =
      'ca-app-pub-3940256099942544/1712485313';

  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';

  static bool get isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static bool get useTestAds {
    return kDebugMode;
  }

  static void enforceProductionGuardrails() {
    if (kDebugMode) {
      return;
    }

    if (appId.isEmpty) {
      throw StateError('Missing release AdMob config: ADMOB_APP_ID');
    }
    if (appId == _testAppId) {
      throw StateError('AdMob test App ID is forbidden in production builds');
    }
    if (!_appIdPattern.hasMatch(appId)) {
      throw StateError('Invalid AdMob App ID format for production builds');
    }

    _validateReleaseUnitId(
      key: 'ADMOB_NATIVE_CREDIT_UNIT',
      unitId: _releaseNativeUnit,
    );
    _validateReleaseUnitId(
      key: 'ADMOB_REWARDED_CREDIT_UNIT',
      unitId: _releaseRewardedUnit,
    );
    _validateReleaseUnitId(
      key: 'ADMOB_BANNER_TRANSACTION_UNIT',
      unitId: _releaseBannerTransactionUnit,
    );
  }

  static void _validateReleaseUnitId({
    required String key,
    required String unitId,
  }) {
    if (unitId.isEmpty) {
      throw StateError('Missing release AdMob config: $key');
    }
    if (!_unitIdPattern.hasMatch(unitId)) {
      throw StateError('Invalid AdMob unit ID format for $key');
    }
  }

  // Debug sessions can be noisy due to Android platform view log spam
  // from native ads. Keep this off by default in debug and enable only
  // when explicitly validating native ad integration.
  static bool get enableNativeAdsInDebug {
    return const bool.fromEnvironment(
      'ENABLE_NATIVE_ADS_IN_DEBUG',
      defaultValue: true,
    );
  }

  static bool get bypassAdThrottleInDebug {
    return kDebugMode;
  }

  static bool get showAdPlaceholderInDebug {
    return kDebugMode;
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
    if (_releaseNativeUnit.isEmpty) {
      throw StateError(
        'Missing release AdMob config: ADMOB_NATIVE_CREDIT_UNIT',
      );
    }
    return _releaseNativeUnit;
  }

  static String get rewardedUnitId {
    if (useTestAds) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? _testRewardedIos
          : _testRewardedAndroid;
    }
    if (_releaseRewardedUnit.isEmpty) {
      throw StateError(
        'Missing release AdMob config: ADMOB_REWARDED_CREDIT_UNIT',
      );
    }
    return _releaseRewardedUnit;
  }

  static bool get shouldLoadBannerAds {
    if (!isSupportedPlatform) return false;
    return useTestAds || _releaseBannerTransactionUnit.isNotEmpty;
  }

  static String get transactionBannerUnitId {
    if (useTestAds) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? _testBannerIos
          : _testBannerAndroid;
    }
    if (_releaseBannerTransactionUnit.isEmpty) {
      throw StateError(
        'Missing release AdMob config: ADMOB_BANNER_TRANSACTION_UNIT',
      );
    }
    return _releaseBannerTransactionUnit;
  }
}
