import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:punto_neutro/core/local_file_service.dart';

class ImageCacheService {
  static final ImageCacheService instance = ImageCacheService._();
  ImageCacheService._();

  static const _boxName = 'image_cache_index';
  static const _defaultMaxBytes = 50 * 1024 * 1024;
  static const _defaultMaxFiles = 400;

  Box<dynamic> get _index => Hive.box<dynamic>(_boxName);

  static Future<void> ensureBoxOpened() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<dynamic>(_boxName);
    }
  }

  Future<String?> getCachedNameForUrl(String url) async {
    final map = _index.get(url) as Map?;
    if (map == null) return null;
    final name = map['name'] as String?;
    if (name == null) return null;

    final bytes = await LocalFileService().readBinaryFile(name);
    if (bytes == null) {
      await _index.delete(url);
      return null;
    }
    map['last'] = DateTime.now().millisecondsSinceEpoch;
    await _index.put(url, map);
    return name;
  }

  Future<void> prefetchUrls(
      List<String> urls, {
        int concurrency = 4,
        Duration timeout = const Duration(seconds: 8),
        int maxBytesBudget = _defaultMaxBytes,
        int maxFilesBudget = _defaultMaxFiles,
      }) async {
    final pending = <String>[];
    for (final u in urls) {
      if (_index.get(u) == null) pending.add(u);
    }
    if (pending.isEmpty) return;

    for (var i = 0; i < pending.length; i += concurrency) {
      final chunk = pending.sublist(i, min(pending.length, i + concurrency));
      await Future.wait(chunk.map((u) => _downloadAndStore(u, timeout: timeout)));
      await _enforceBudget(maxBytesBudget, maxFilesBudget);
    }
  }

  String _nameForUrl(String url) => sha1.convert(utf8.encode(url)).toString();

  Future<void> _downloadAndStore(String url, {required Duration timeout}) async {
    try {
      final name = _nameForUrl(url);
      final already = await LocalFileService().readBinaryFile(name);
      if (already != null) {
        await _index.put(url, {
          'name': name,
          'last': DateTime.now().millisecondsSinceEpoch,
          'size': already.length,
        });
        return;
      }

      final resp = await http.get(Uri.parse(url)).timeout(timeout);
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return;

      final bytes = Uint8List.fromList(resp.bodyBytes);
      await LocalFileService().writeBinaryFile(name, bytes);
      await _index.put(url, {
        'name': name,
        'last': DateTime.now().millisecondsSinceEpoch,
        'size': bytes.length,
      });
    } catch (_) {/*silent*/}
  }

  Future<void> _enforceBudget(int maxBytesBudget, int maxFilesBudget) async {
    int totalBytes = 0;
    final entries = <_E>[];
    for (final k in _index.keys) {
      final v = _index.get(k) as Map?;
      if (v == null) continue;
      final name = v['name'] as String? ?? '';
      final last = (v['last'] as num?)?.toInt() ?? 0;
      final size = (v['size'] as num?)?.toInt() ?? 0;
      entries.add(_E(k as String, name, last, size));
      totalBytes += size;
    }

    if (entries.length <= maxFilesBudget && totalBytes <= maxBytesBudget) return;

    entries.sort((a, b) => a.last.compareTo(b.last)); // LRU
    for (final e in entries) {
      if (entries.length <= maxFilesBudget && totalBytes <= maxBytesBudget) break;
      await LocalFileService().delete(e.name);
      await _index.delete(e.url);
      totalBytes -= e.size;
    }
  }
}

class _E {
  final String url;
  final String name;
  final int last;
  final int size;
  _E(this.url, this.name, this.last, this.size);
}
