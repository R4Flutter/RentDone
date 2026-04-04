import 'dart:async';

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class DocumentCacheService {
  static const int _defaultMaxCacheBytes = 500 * 1024 * 1024;
  static final int _maxCacheBytes = int.fromEnvironment(
    'DOCUMENT_CACHE_MAX_BYTES',
    defaultValue: _defaultMaxCacheBytes,
  );
  static Future<void> _lock = Future<void>.value();

  static Future<File?> getIfFresh(String url, Duration ttl) async {
    return _withLock(() async {
      final dir = await _cacheDir();
      final key = _key(url);
      final file = File('${dir.path}${Platform.pathSeparator}$key.bin');
      final metaFile = File('${dir.path}${Platform.pathSeparator}$key.meta');

      if (!await file.exists() || !await metaFile.exists()) {
        return null;
      }

      final fileSize = await file.length();
      final meta = await _readMeta(metaFile, fallbackSizeBytes: fileSize);
      if (meta == null) {
        await _deleteCacheEntry(file, metaFile);
        return null;
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - meta.createdAtMs > ttl.inMilliseconds) {
        await _deleteCacheEntry(file, metaFile);
        return null;
      }

      await _writeMeta(
        metaFile,
        meta.copyWith(lastAccessMs: nowMs, sizeBytes: fileSize),
      );
      return file;
    });
  }

  static Future<File> getOrFetch(String url, Duration ttl) async {
    final cached = await getIfFresh(url, ttl);
    if (cached != null) {
      return cached;
    }
    return _downloadAndStore(url);
  }

  static Future<void> clearExpired(Duration ttl) async {
    await _withLock(() async {
      final dir = await _cacheDir();
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      for (final entity in dir.listSync()) {
        if (entity is! File || !entity.path.endsWith('.meta')) {
          continue;
        }

        final base = entity.path.substring(0, entity.path.length - 5);
        final binFile = File('$base.bin');
        if (!await binFile.exists()) {
          try {
            await entity.delete();
          } catch (_) {}
          continue;
        }

        final meta = await _readMeta(
          entity,
          fallbackSizeBytes: await binFile.length(),
        );
        if (meta == null) {
          await _deleteCacheEntry(binFile, entity);
          continue;
        }

        if (nowMs - meta.createdAtMs > ttl.inMilliseconds) {
          await _deleteCacheEntry(binFile, entity);
        }
      }

      await _enforceSizeLimit(dir);
    });
  }

  static Future<File> _downloadAndStore(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Download failed (${response.statusCode}).');
    }

    return _withLock(() async {
      final dir = await _cacheDir();
      final key = _key(url);
      final file = File('${dir.path}${Platform.pathSeparator}$key.bin');
      final metaFile = File('${dir.path}${Platform.pathSeparator}$key.meta');

      await file.writeAsBytes(response.bodyBytes, flush: true);

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await _writeMeta(
        metaFile,
        _CacheMeta(
          createdAtMs: nowMs,
          lastAccessMs: nowMs,
          sizeBytes: response.bodyBytes.length,
        ),
      );

      await _enforceSizeLimit(dir);
      return file;
    });
  }

  static Future<T> _withLock<T>(Future<T> Function() action) {
    final previous = _lock;
    final gate = Completer<void>();
    _lock = gate.future;

    return previous
        .catchError((_) {})
        .then((_) => action())
        .whenComplete(() {
          if (!gate.isCompleted) {
            gate.complete();
          }
        });
  }

  static Future<void> _enforceSizeLimit(Directory dir) async {
    if (_maxCacheBytes <= 0) {
      return;
    }

    final lruEntries = <String, _CacheEntry>{};
    var totalBytes = 0;

    final cacheEntries = <_CacheEntry>[];
    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.meta')) {
        continue;
      }

      final base = entity.path.substring(0, entity.path.length - 5);
      final binFile = File('$base.bin');
      if (!await binFile.exists()) {
        try {
          await entity.delete();
        } catch (_) {}
        continue;
      }

      final binSize = await binFile.length();
      final meta = await _readMeta(entity, fallbackSizeBytes: binSize);
      if (meta == null) {
        await _deleteCacheEntry(binFile, entity);
        continue;
      }

      final normalizedMeta =
          meta.sizeBytes == binSize ? meta : meta.copyWith(sizeBytes: binSize);
      if (normalizedMeta.sizeBytes != meta.sizeBytes) {
        await _writeMeta(entity, normalizedMeta);
      }

      cacheEntries.add(
        _CacheEntry(
          cacheKey: base,
          binFile: binFile,
          metaFile: entity,
          meta: normalizedMeta,
        ),
      );
    }

    cacheEntries.sort(
      (a, b) => a.meta.lastAccessMs.compareTo(b.meta.lastAccessMs),
    );

    for (final entry in cacheEntries) {
      lruEntries[entry.cacheKey] = entry;
      totalBytes += entry.meta.sizeBytes;
    }

    while (totalBytes > _maxCacheBytes && lruEntries.isNotEmpty) {
      final oldestKey = lruEntries.keys.first;
      final oldest = lruEntries.remove(oldestKey);
      if (oldest == null) {
        break;
      }

      totalBytes -= oldest.meta.sizeBytes;
      await _deleteCacheEntry(oldest.binFile, oldest.metaFile);
    }
  }

  static Future<_CacheMeta?> _readMeta(
    File metaFile, {
    required int fallbackSizeBytes,
  }) async {
    try {
      final raw = await metaFile.readAsString();
      return _CacheMeta.fromRaw(raw, fallbackSizeBytes: fallbackSizeBytes);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeMeta(File metaFile, _CacheMeta meta) {
    return metaFile.writeAsString(meta.toRaw(), flush: true);
  }

  static Future<void> _deleteCacheEntry(File binFile, File metaFile) async {
    try {
      if (await binFile.exists()) {
        await binFile.delete();
      }
    } catch (_) {}

    try {
      if (await metaFile.exists()) {
        await metaFile.delete();
      }
    } catch (_) {}
  }

  static String _key(String url) {
    return sha1.convert(utf8.encode(url)).toString();
  }

  static Future<Directory> _cacheDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}document_cache',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}

class _CacheMeta {
  const _CacheMeta({
    required this.createdAtMs,
    required this.lastAccessMs,
    required this.sizeBytes,
  });

  final int createdAtMs;
  final int lastAccessMs;
  final int sizeBytes;

  _CacheMeta copyWith({
    int? createdAtMs,
    int? lastAccessMs,
    int? sizeBytes,
  }) {
    return _CacheMeta(
      createdAtMs: createdAtMs ?? this.createdAtMs,
      lastAccessMs: lastAccessMs ?? this.lastAccessMs,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }

  String toRaw() {
    return jsonEncode({
      'createdAtMs': createdAtMs,
      'lastAccessMs': lastAccessMs,
      'sizeBytes': sizeBytes,
    });
  }

  static _CacheMeta fromRaw(
    String raw, {
    required int fallbackSizeBytes,
  }) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('{')) {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid metadata payload.');
      }

      final createdAtMs = (decoded['createdAtMs'] as num?)?.toInt() ?? 0;
      final lastAccessMs = (decoded['lastAccessMs'] as num?)?.toInt() ?? 0;
      final sizeBytes =
          (decoded['sizeBytes'] as num?)?.toInt() ?? fallbackSizeBytes;

      return _CacheMeta(
        createdAtMs: createdAtMs > 0 ? createdAtMs : lastAccessMs,
        lastAccessMs: lastAccessMs > 0 ? lastAccessMs : createdAtMs,
        sizeBytes: sizeBytes > 0 ? sizeBytes : fallbackSizeBytes,
      );
    }

    final savedMs = int.tryParse(trimmed) ?? 0;
    return _CacheMeta(
      createdAtMs: savedMs,
      lastAccessMs: savedMs,
      sizeBytes: fallbackSizeBytes,
    );
  }
}

class _CacheEntry {
  const _CacheEntry({
    required this.cacheKey,
    required this.binFile,
    required this.metaFile,
    required this.meta,
  });

  final String cacheKey;
  final File binFile;
  final File metaFile;
  final _CacheMeta meta;
}
