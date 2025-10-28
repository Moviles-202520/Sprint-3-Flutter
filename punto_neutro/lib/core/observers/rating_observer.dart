import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// RatingObserver
/// - Provee actualizaciones en tiempo real de los ratings para un artículo.
/// - Útil para refrescar métricas relacionadas con BQ3/BQ4 (promedios, ventanas de tiempo, etc.).
class RatingObserver {
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  void start({required int newsItemId, required void Function(List<Map<String, dynamic>> rows) onUpdate}) {
    _sub?.cancel();
    _sub = _supabase
        .from('rating_items')
        .stream(primaryKey: ['rating_item_id'])
        .eq('news_item_id', newsItemId)
        .listen(onUpdate, onError: (e, st) {
      // ignore: avoid_print
      print('❌ [OBS] RatingObserver error: $e');
    });
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
