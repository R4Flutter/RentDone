import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:rentdone/core/ads/admob_config.dart';

class RewardedAdService {
  RewardedAdService._();

  static final RewardedAdService instance = RewardedAdService._();

  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  Future<void> preload() async {
    if (!AdMobConfig.isSupportedPlatform) return;
    if (_rewardedAd != null || _isLoading) return;

    _isLoading = true;
    try {
      await RewardedAd.load(
        adUnitId: AdMobConfig.rewardedUnitId,
        request: const AdRequest(
          keywords: <String>['credit card', 'cashback', 'rent payment', 'upi'],
        ),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd?.dispose();
            _rewardedAd = ad;
            _isLoading = false;
          },
          onAdFailedToLoad: (_) {
            _isLoading = false;
          },
        ),
      );
    } catch (_) {
      _isLoading = false;
    }
  }

  Future<bool> showRewardedAd({
    required FutureOr<void> Function() onRewardEarned,
  }) async {
    if (!AdMobConfig.isSupportedPlatform) return false;

    await preload();
    final ad = _rewardedAd;
    if (ad == null) {
      return false;
    }

    final completer = Completer<bool>();
    var rewarded = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        unawaited(preload());
        if (!completer.isCompleted) {
          completer.complete(rewarded);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedAd = null;
        unawaited(preload());
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    _rewardedAd = null;
    ad.show(
      onUserEarnedReward: (_, reward) async {
        rewarded = true;
        await onRewardEarned();
      },
    );

    return completer.future;
  }
}
