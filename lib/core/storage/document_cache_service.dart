import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class DocumentCacheService {
  static Future<File?> getIfFresh(String url, Duration ttl) async {
    final dir = await _cacheDir();
    final key = _key(url);
    final file = File('${dir.path}${Platform.pathSeparator}$key.bin');
    final meta = File('${dir.path}${Platform.pathSeparator}$key.meta');

    if (!await file.exists() || !await meta.exists()) {
      return null;
    }

    final savedMs = int.tryParse(await meta.readAsString()) ?? 0;
    final ageMs = DateTime.now().millisecondsSinceEpoch - savedMs;
    if (ageMs > ttl.inMilliseconds) {
      return null;
    }

    return file;
  }

  static Future<File> getOrFetch(String url, Duration ttl) async {
    final cached = await getIfFresh(url, ttl);
    if (cached != null) {
      return cached;
    }
    return _downloadAndStore(url);
  }

  static Future<void> clearExpired(Duration ttl) async {
    final dir = await _cacheDir();
    final entities = dir.listSync();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    for (final entity in entities) {
      if (entity is! File || !entity.path.endsWith('.meta')) {
        continue;
      }

      final savedMs = int.tryParse(await entity.readAsString()) ?? 0;
      if (nowMs - savedMs <= ttl.inMilliseconds) {
        continue;
      }

      final base = entity.path.substring(0, entity.path.length - 5);
      final bin = File('$base.bin');
      try {
        if (await bin.exists()) {
          await bin.delete();
        }
        await entity.delete();
      } catch (_) {}
    }
  }

  static Future<File> _downloadAndStore(String url) async {
    final dir = await _cacheDir();
    final key = _key(url);
    final file = File('${dir.path}${Platform.pathSeparator}$key.bin');
    final meta = File('${dir.path}${Platform.pathSeparator}$key.meta');

    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Download failed (${response.statusCode}).');
    }

    await file.writeAsBytes(response.bodyBytes, flush: true);
    await meta.writeAsString(
      '${DateTime.now().millisecondsSinceEpoch}',
      flush: true,
    );

    return file;
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
