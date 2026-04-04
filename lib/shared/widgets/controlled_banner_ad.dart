import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:rentdone/core/ads/admob_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ControlledBannerAd extends StatefulWidget {
  const ControlledBannerAd({
    super.key,
    required this.placementKey,
    this.initialDelay = const Duration(seconds: 10),
    this.minInterval = const Duration(hours: 24),
  });

  final String placementKey;
  final Duration initialDelay;
  final Duration minInterval;

  @override
  State<ControlledBannerAd> createState() => _ControlledBannerAdState();
}

class _ControlledBannerAdState extends State<ControlledBannerAd> {
  static final Set<String> _shownPlacementsThisSession = <String>{};

  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isLoading = false;
  bool _isAdFreeActive = false;

  String get _lastShownPrefsKey =>
      'banner_ad_last_shown_${widget.placementKey}';

  @override
  void initState() {
    super.initState();
    unawaited(_prepareAndLoad());
  }

  Future<void> _prepareAndLoad() async {
    if (kIsWeb) return;
    if (!AdMobConfig.shouldLoadBannerAds) return;

    final adFree = await _isTenantAdFreeActive();
    if (!mounted) return;
    if (adFree) {
      setState(() {
        _isAdFreeActive = true;
      });
      return;
    }

    final bypassThrottle = AdMobConfig.bypassAdThrottleInDebug;

    if (!bypassThrottle && widget.initialDelay > Duration.zero) {
      await Future<void>.delayed(widget.initialDelay);
      if (!mounted) return;
    }

    if (!bypassThrottle &&
        _shownPlacementsThisSession.contains(widget.placementKey)) {
      return;
    }

    if (!bypassThrottle) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastShownMs = prefs.getInt(_lastShownPrefsKey);
        if (lastShownMs != null) {
          final elapsed = DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch(lastShownMs),
          );
          if (elapsed < widget.minInterval) {
            return;
          }
        }
      } catch (_) {
        // Continue runtime load path even if local storage is unavailable.
      }
    }

    _loadBanner();
  }

  Future<bool> _isTenantAdFreeActive() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return false;

    try {
      final tenantDoc = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(uid)
          .get();
      final data = tenantDoc.data() ?? <String, dynamic>{};
      final raw = data['adSubscription'];
      if (raw is! Map) return false;
      final sub = Map<String, dynamic>.from(raw);
      final expiryRaw = sub['expiryDate'];
      final isActiveRaw = sub['isActive'];
      final isActive = isActiveRaw == true;
      if (!isActive) return false;

      DateTime? expiry;
      if (expiryRaw is Timestamp) {
        expiry = expiryRaw.toDate();
      } else if (expiryRaw is DateTime) {
        expiry = expiryRaw;
      } else if (expiryRaw is num) {
        expiry = DateTime.fromMillisecondsSinceEpoch(expiryRaw.toInt());
      }

      return expiry != null && expiry.isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  void _loadBanner() {
    if (_isLoading || _isLoaded || !mounted) return;
    final unitId = AdMobConfig.transactionBannerUnitId;
    if (unitId.isEmpty) return;

    _isLoading = true;

    final ad = BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(
        keywords: <String>['rent payment', 'bill reminders', 'upi', 'cashback'],
      ),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
            _isLoading = false;
          });
          unawaited(_recordShown());
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
            _isLoading = false;
          });
        },
      ),
    );

    ad.load();
  }

  Future<void> _recordShown() async {
    _shownPlacementsThisSession.add(widget.placementKey);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _lastShownPrefsKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Keep ad behavior even if persistence fails.
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdFreeActive) {
      return const SizedBox.shrink();
    }

    final ad = _bannerAd;
    if (!_isLoaded || ad == null) {
      if (AdMobConfig.showAdPlaceholderInDebug) {
        final scheme = Theme.of(context).colorScheme;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
            color: scheme.surface.withValues(alpha: 0.65),
          ),
          child: Text(
            _isLoading
                ? 'Banner Ad Slot: loading test ad...'
                : 'Banner Ad Slot: waiting for fill',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return Center(
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
