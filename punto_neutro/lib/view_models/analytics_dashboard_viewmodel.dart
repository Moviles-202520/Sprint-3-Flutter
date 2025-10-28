import 'dart:async';
import 'package:flutter/material.dart';
import '../core/observers/rating_observer.dart';
import '../core/observers/comment_tracker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ViewModel para el dashboard de analítica con actualización en tiempo real
class AnalyticsDashboardViewModel extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final RatingObserver _ratingObserver = RatingObserver();
  final CommentTracker _commentTracker = CommentTracker();
  StreamSubscription<List<Map<String, dynamic>>>? _engagementSub;
  StreamSubscription<List<Map<String, dynamic>>>? _sessionSub;

  // Datos en vivo para cada BQ
  List<Map<String, dynamic>> _ratings = [];
  List<Map<String, dynamic>> _commentsCompleted = [];
  List<Map<String, dynamic>> _commentsStarted = [];
  List<Map<String, dynamic>> _engagementEvents = [];
  List<Map<String, dynamic>> _userSessions = [];

  // Exposición para la UI
  List<Map<String, dynamic>> get ratings => _ratings;
  List<Map<String, dynamic>> get commentsCompleted => _commentsCompleted;
  List<Map<String, dynamic>> get commentsStarted => _commentsStarted;
  List<Map<String, dynamic>> get engagementEvents => _engagementEvents;
  List<Map<String, dynamic>> get userSessions => _userSessions;

  void startRealtime({required int newsItemId}) {
    // Ratings
    _ratingObserver.start(newsItemId: newsItemId, onUpdate: (rows) {
      _ratings = rows;
      notifyListeners();
    });
    // Comments
    _commentTracker.start(
      newsItemId: newsItemId,
      onStarted: (rows) {
        _commentsStarted = rows;
        notifyListeners();
      },
      onCompleted: (rows) {
        _commentsCompleted = rows;
        notifyListeners();
      },
    );
    // Engagement events (para BQ1, BQ2)
    _engagementSub?.cancel();
    _engagementSub = _supabase
      .from('engagement_events')
      .stream(primaryKey: ['event_id'])
      .listen((rows) {
        _engagementEvents = rows;
        notifyListeners();
      });
    // User sessions (para BQ2, BQ5)
    _sessionSub?.cancel();
    _sessionSub = _supabase
      .from('user_sessions')
      .stream(primaryKey: ['session_id'])
      .listen((rows) {
        _userSessions = rows;
        notifyListeners();
      });
  }

  @override
  void dispose() {
    _ratingObserver.dispose();
    _commentTracker.dispose();
    _engagementSub?.cancel();
    _sessionSub?.cancel();
    super.dispose();
  }
}
