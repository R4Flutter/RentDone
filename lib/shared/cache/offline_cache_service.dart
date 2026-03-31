/// Offline-first caching layer for critical dashboard and payment data
/// Uses SharedPreferences for persistent local cache
/// Enables app to work offline with stale data fallback
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:rentdone/core/logging/app_logger.dart';

class OfflineCacheService {
  static const _dashboardCacheKey = 'dashboard_cache';
  static const _paymentsCacheKey = 'payments_cache';
  static const _propertiesCacheKey = 'properties_cache';
  static const _tenantsCacheKey = 'tenants_cache';
  static const _cacheExpiryKey = 'cache_expiry_';

  // Cache expiry duration (24 hours)
  static const cacheDuration = Duration(hours: 24);

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Cache dashboard summary data
  Future<bool> cacheDashboardSummary(Map<String, dynamic> data) async {
    try {
      await _prefs.setString(_dashboardCacheKey, jsonEncode(data));
      await _setCacheExpiry(_dashboardCacheKey);
      if (kDebugMode) {
        AppLogger.debug('Dashboard cached locally', tag: 'OfflineCacheService');
      }
      return true;
    } catch (e) {
      AppLogger.warning(
        'Failed to cache dashboard: $e',
        tag: 'OfflineCacheService',
      );
      return false;
    }
  }

  /// Retrieve cached dashboard summary
  /// Returns null if cache doesn't exist or expired
  Map<String, dynamic>? getCachedDashboardSummary() {
    try {
      if (!_isCacheValid(_dashboardCacheKey)) return null;

      final cached = _prefs.getString(_dashboardCacheKey);
      if (cached == null) return null;

      return jsonDecode(cached) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.debug(
          'Failed to retrieve dashboard cache: $e',
          tag: 'OfflineCacheService',
        );
      }
      return null;
    }
  }

  /// Cache payment records
  Future<bool> cachePayments(List<Map<String, dynamic>> payments) async {
    try {
      await _prefs.setString(_paymentsCacheKey, jsonEncode(payments));
      await _setCacheExpiry(_paymentsCacheKey);
      if (kDebugMode) {
        AppLogger.debug(
          'Payments cached locally (${payments.length} records)',
          tag: 'OfflineCacheService',
        );
      }
      return true;
    } catch (e) {
      AppLogger.warning(
        'Failed to cache payments: $e',
        tag: 'OfflineCacheService',
      );
      return false;
    }
  }

  /// Retrieve cached payments
  List<Map<String, dynamic>> getCachedPayments() {
    try {
      if (!_isCacheValid(_paymentsCacheKey)) return [];

      final cached = _prefs.getString(_paymentsCacheKey);
      if (cached == null) return [];

      final decoded = jsonDecode(cached);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        AppLogger.debug(
          'Failed to retrieve payments cache: $e',
          tag: 'OfflineCacheService',
        );
      }
      return [];
    }
  }

  /// Cache property records
  Future<bool> cacheProperties(List<Map<String, dynamic>> properties) async {
    try {
      await _prefs.setString(_propertiesCacheKey, jsonEncode(properties));
      await _setCacheExpiry(_propertiesCacheKey);
      if (kDebugMode) {
        AppLogger.debug(
          'Properties cached locally (${properties.length} records)',
          tag: 'OfflineCacheService',
        );
      }
      return true;
    } catch (e) {
      AppLogger.warning(
        'Failed to cache properties: $e',
        tag: 'OfflineCacheService',
      );
      return false;
    }
  }

  /// Retrieve cached properties
  List<Map<String, dynamic>> getCachedProperties() {
    try {
      if (!_isCacheValid(_propertiesCacheKey)) return [];

      final cached = _prefs.getString(_propertiesCacheKey);
      if (cached == null) return [];

      final decoded = jsonDecode(cached);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        AppLogger.debug(
          'Failed to retrieve properties cache: $e',
          tag: 'OfflineCacheService',
        );
      }
      return [];
    }
  }

  /// Cache tenant records
  Future<bool> cacheTenants(List<Map<String, dynamic>> tenants) async {
    try {
      await _prefs.setString(_tenantsCacheKey, jsonEncode(tenants));
      await _setCacheExpiry(_tenantsCacheKey);
      if (kDebugMode) {
        AppLogger.debug(
          'Tenants cached locally (${tenants.length} records)',
          tag: 'OfflineCacheService',
        );
      }
      return true;
    } catch (e) {
      AppLogger.warning(
        'Failed to cache tenants: $e',
        tag: 'OfflineCacheService',
      );
      return false;
    }
  }

  /// Retrieve cached tenants
  List<Map<String, dynamic>> getCachedTenants() {
    try {
      if (!_isCacheValid(_tenantsCacheKey)) return [];

      final cached = _prefs.getString(_tenantsCacheKey);
      if (cached == null) return [];

      final decoded = jsonDecode(cached);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        AppLogger.debug(
          'Failed to retrieve tenants cache: $e',
          tag: 'OfflineCacheService',
        );
      }
      return [];
    }
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    try {
      await _prefs.remove(_dashboardCacheKey);
      await _prefs.remove(_paymentsCacheKey);
      await _prefs.remove(_propertiesCacheKey);
      await _prefs.remove(_tenantsCacheKey);
      await _prefs.remove('$_cacheExpiryKey$_dashboardCacheKey');
      await _prefs.remove('$_cacheExpiryKey$_paymentsCacheKey');
      await _prefs.remove('$_cacheExpiryKey$_propertiesCacheKey');
      await _prefs.remove('$_cacheExpiryKey$_tenantsCacheKey');
      if (kDebugMode) {
        AppLogger.debug('All caches cleared', tag: 'OfflineCacheService');
      }
    } catch (e) {
      AppLogger.warning(
        'Failed to clear caches: $e',
        tag: 'OfflineCacheService',
      );
    }
  }

  /// Check if cache is still valid (not expired)
  bool _isCacheValid(String key) {
    try {
      final expiryStr = _prefs.getString('$_cacheExpiryKey$key');
      if (expiryStr == null) return false;

      final expiry = DateTime.parse(expiryStr);
      return DateTime.now().isBefore(expiry);
    } catch (e) {
      return false;
    }
  }

  /// Set cache expiry timestamp
  Future<void> _setCacheExpiry(String key) async {
    final expiry = DateTime.now().add(cacheDuration);
    await _prefs.setString('$_cacheExpiryKey$key', expiry.toIso8601String());
  }
}

/// Global offline cache service instance
final offlineCacheService = OfflineCacheService();
