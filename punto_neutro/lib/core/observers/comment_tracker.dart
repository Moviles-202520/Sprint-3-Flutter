import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// CommentTracker
/// - Emite conteos/filas en tiempo real para BQ1 (comment started vs completed)
/// - started: engagement_events (event_type=comment, action=started)
/// - completed: comments (is_completed=true)
class CommentTracker {
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<List<Map<String, dynamic>>>? _startedSub;
  StreamSubscription<List<Map<String, dynamic>>>? _completedSub;

  void start({
    required int newsItemId,
    required void Function(List<Map<String, dynamic>> startedRows) onStarted,
    required void Function(List<Map<String, dynamic>> completedRows) onCompleted,
  }) {
    // engagement_events started
    _startedSub?.cancel();
    _startedSub = _supabase
        .from('engagement_events')
        .stream(primaryKey: ['event_id'])
        .listen((rows) {
      final filtered = rows.where((r) =>
          r['news_item_id'] == newsItemId &&
          r['event_type'] == 'comment' &&
          r['action'] == 'started').toList();
      onStarted(filtered);
    }, onError: (e, st) {
      // ignore: avoid_print
      print('❌ [OBS] CommentTracker started error: $e');
    });

    // comments completed
    _completedSub?.cancel();
    _completedSub = _supabase
        .from('comments')
        .stream(primaryKey: ['comment_id'])
        .listen((rows) {
      final filtered = rows.where((r) =>
          r['news_item_id'] == newsItemId &&
          (r['is_completed'] == true)).toList();
      onCompleted(filtered);
    }, onError: (e, st) {
      // ignore: avoid_print
      print('❌ [OBS] CommentTracker completed error: $e');
    });
  }

  Future<void> dispose() async {
    await _startedSub?.cancel();
    await _completedSub?.cancel();
    _startedSub = null;
    _completedSub = null;
  }
}
