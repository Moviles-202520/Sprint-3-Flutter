import 'package:flutter_test/flutter_test.dart';
import 'package:punto_neutro/core/image_prefetch_service.dart';

void main() {
  group('ImagePrefetchService', () {
    late ImagePrefetchService service;

    setUp(() {
      service = ImagePrefetchService();
      service.resetMetrics();
    });

    test('debe ser singleton', () {
      final instance1 = ImagePrefetchService();
      final instance2 = ImagePrefetchService();
      expect(instance1, same(instance2));
    });

    test('debe inicializar métricas en cero', () {
      expect(service.prefetchedCount, 0);
      expect(service.cacheHits, 0);
      expect(service.cacheMisses, 0);
    });

    test('debe registrar cache hits correctamente', () {
      service.recordCacheHit();
      service.recordCacheHit();
      expect(service.cacheHits, 2);
      expect(service.cacheMisses, 0);
    });

    test('debe registrar cache misses correctamente', () {
      service.recordCacheMiss();
      service.recordCacheMiss();
      service.recordCacheMiss();
      expect(service.cacheMisses, 3);
      expect(service.cacheHits, 0);
    });

    test('debe calcular hit rate correctamente', () {
      service.recordCacheHit();
      service.recordCacheHit();
      service.recordCacheHit();
      service.recordCacheMiss();
      
      final stats = service.getStatistics();
      expect(stats['total_requests'], 4);
      expect(stats['cache_hits'], 3);
      expect(stats['cache_misses'], 1);
      expect(stats['hit_rate_percent'], '75.0');
    });

    test('debe manejar hit rate cuando no hay requests', () {
      final stats = service.getStatistics();
      expect(stats['hit_rate_percent'], '0.0');
    });

    test('debe resetear métricas correctamente', () {
      service.recordCacheHit();
      service.recordCacheMiss();
      
      service.resetMetrics();
      
      expect(service.cacheHits, 0);
      expect(service.cacheMisses, 0);
      expect(service.prefetchedCount, 0);
    });

    test('debe retornar estadísticas completas', () {
      service.recordCacheHit();
      service.recordCacheMiss();
      
      final stats = service.getStatistics();
      
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('prefetched_count'), true);
      expect(stats.containsKey('cache_hits'), true);
      expect(stats.containsKey('cache_misses'), true);
      expect(stats.containsKey('total_requests'), true);
      expect(stats.containsKey('hit_rate_percent'), true);
    });
  });
}
