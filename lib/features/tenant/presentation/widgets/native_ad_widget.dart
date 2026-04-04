import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:rentdone/core/ads/admob_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({
    super.key,
    this.placementKey = 'default_native_placement',
    this.initialDelay = const Duration(seconds: 8),
    this.minInterval = const Duration(hours: 24),
  });

  final String placementKey;
  final Duration initialDelay;
  final Duration minInterval;

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  static final Set<String> _shownPlacementsThisSession = <String>{};

  NativeAd? _nativeAd;
  bool _isLoaded = false;
  bool _isLoading = false;
  bool _isAdFreeActive = false;

  String get _lastShownPrefsKey =>
      'native_ad_last_shown_${widget.placementKey}';

  @override
  void initState() {
    super.initState();
    unawaited(_prepareAndLoad());
  }

  Future<void> _prepareAndLoad() async {
    if (kIsWeb) return;
    final isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!isMobile) return;
    if (!AdMobConfig.shouldLoadNativeAds) return;

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
          final lastShown = DateTime.fromMillisecondsSinceEpoch(lastShownMs);
          final elapsed = DateTime.now().difference(lastShown);
          if (elapsed < widget.minInterval) {
            return;
          }
        }
      } catch (_) {
        // Continue without persistent cooldown if storage is unavailable.
      }
    }

    _load();
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

  void _load() {
    if (kIsWeb) {
      return;
    }
    final isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!isMobile) return;
    if (!AdMobConfig.shouldLoadNativeAds) {
      return;
    }
    if (_isLoading || _isLoaded) return;

    _isLoading = true;

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
            _isLoading = false;
          });
          unawaited(_recordShown());
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _nativeAd = null;
            _isLoaded = false;
            _isLoading = false;
          });
        },
      ),
      // Native ads require a factory configured in platform code.
      // If missing, the ad will fail and this widget stays hidden.
      factoryId: 'creditCardNativeFactory',
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
      // Keep runtime behavior even if persistence fails.
    }
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdFreeActive) {
      return const SizedBox.shrink();
    }

    if (!AdMobConfig.shouldLoadNativeAds) {
      if (AdMobConfig.showAdPlaceholderInDebug) {
        return _DebugAdPlaceholder(
          label: 'Native Ad (disabled)',
          subtitle: 'Enable native ads for this build to validate placement.',
        );
      }
      return const SizedBox.shrink();
    }

    if (!_isLoaded || _nativeAd == null) {
      if (AdMobConfig.showAdPlaceholderInDebug) {
        return _DebugAdPlaceholder(
          label: 'Native Ad Slot',
          subtitle: _isLoading
              ? 'Loading test ad...'
              : 'Waiting for ad fill from AdMob.',
        );
      }
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

class _DebugAdPlaceholder extends StatelessWidget {
  const _DebugAdPlaceholder({required this.label, required this.subtitle});

  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
        color: scheme.surface.withValues(alpha: 0.7),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Text(
            'Debug Preview',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
