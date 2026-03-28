import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

class AppConfigService {
  AppConfigService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _cacheKey = 'app_config_cache';
  static const String _cacheAtKey = 'app_config_cache_at';
  static const Duration _cacheTtl = Duration(minutes: 5);

  AppConfig? _memoryCache;
  DateTime? _memoryCacheAt;

  Future<AppConfig> getConfig({bool forceRefresh = false}) async {
    if (!forceRefresh && _memoryCache != null && !_isStale(_memoryCacheAt)) {
      return _memoryCache!;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cached = _readFromPrefs(prefs);
      if (cached != null) {
        _memoryCache = cached;
        _memoryCacheAt = DateTime.now().toUtc();
        return cached;
      }
    }

    try {
      final snap = await _firestore.collection('appConfig').doc('global').get();
      final config = AppConfig.fromMap(snap.data());
      _memoryCache = config;
      _memoryCacheAt = DateTime.now().toUtc();
      await _saveToPrefs(prefs, config);
      return config;
    } catch (_) {
      return _memoryCache ?? AppConfig.defaults();
    }
  }

  AppConfig? _readFromPrefs(SharedPreferences prefs) {
    final cacheAt = prefs.getInt(_cacheAtKey);
    if (cacheAt == null) return null;
    final cacheTime = DateTime.fromMillisecondsSinceEpoch(cacheAt, isUtc: true);
    if (_isStale(cacheTime)) return null;

    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return AppConfig.fromMap(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToPrefs(SharedPreferences prefs, AppConfig config) async {
    final payload = jsonEncode(config.toMap());
    await prefs.setString(_cacheKey, payload);
    await prefs.setInt(
      _cacheAtKey,
      DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  bool _isStale(DateTime? timestamp) {
    if (timestamp == null) return true;
    return DateTime.now().toUtc().difference(timestamp) > _cacheTtl;
  }
}
