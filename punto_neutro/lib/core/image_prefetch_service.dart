import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Servicio simple de prefetch de imágenes usando cached_network_image.
/// Descarga y cachea imágenes a disco automáticamente cuando el usuario
/// se acerca al final del feed.
class ImagePrefetchService {
  static final ImagePrefetchService _instance = ImagePrefetchService._internal();
  factory ImagePrefetchService() => _instance;
  ImagePrefetchService._internal();

  // Métricas básicas
  int _prefetchedCount = 0;
  int _cacheHits = 0;
  int _cacheMisses = 0;

  int get prefetchedCount => _prefetchedCount;
  int get cacheHits => _cacheHits;
  int get cacheMisses => _cacheMisses;

  /// Prefetch de imágenes para mejorar UX.
  /// [urls]: lista de URLs a precargar
  /// [context]: BuildContext necesario para precacheImage
  Future<void> prefetchImages(List<String> urls, BuildContext context) async {
    if (!context.mounted) return;

    for (final url in urls) {
      if (url.isEmpty) continue;

      try {
        // cached_network_image descarga y cachea automáticamente
        await precacheImage(
          CachedNetworkImageProvider(url),
          context,
        );
        _prefetchedCount++;
        print('✅ Prefetch: $url');
      } catch (e) {
        print('⚠️ Prefetch falló para $url: $e');
      }
    }
  }

  /// Registra un cache hit (cuando imagen ya estaba en cache)
  void recordCacheHit() {
    _cacheHits++;
  }

  /// Registra un cache miss (cuando imagen tuvo que descargarse)
  void recordCacheMiss() {
    _cacheMisses++;
  }

  /// Obtiene estadísticas del servicio
  Map<String, dynamic> getStatistics() {
    final total = _cacheHits + _cacheMisses;
    final hitRate = total > 0 ? (_cacheHits / total * 100).toStringAsFixed(1) : '0.0';

    return {
      'prefetched_count': _prefetchedCount,
      'cache_hits': _cacheHits,
      'cache_misses': _cacheMisses,
      'total_requests': total,
      'hit_rate_percent': hitRate,
    };
  }

  /// Resetea métricas (útil para testing)
  void resetMetrics() {
    _prefetchedCount = 0;
    _cacheHits = 0;
    _cacheMisses = 0;
  }
}
