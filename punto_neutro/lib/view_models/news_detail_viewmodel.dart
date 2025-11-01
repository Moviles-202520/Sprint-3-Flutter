import 'package:flutter/material.dart';
import '../domain/repositories/news_repository.dart';
import '../domain/models/news_item.dart';
import '../domain/models/rating_item.dart';
import '../domain/models/comment.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/analytics_service.dart';
import '../core/observers/rating_observer.dart';
import '../core/observers/comment_tracker.dart';
import 'package:flutter/foundation.dart';
import '../../data/repositories/hybrid_news_repository.dart';

class NewsDetailViewModel extends ChangeNotifier {

  // ===== BOOKMARKS =====
  final HybridNewsRepository _hybridNewsRepository;
  bool isBookmarked = false;
  bool _bookmarkLoaded = false;

  /// Carga el estado de bookmark solo una vez
  Future<void> loadBookmarkStateOnce() async {
    if (_bookmarkLoaded) return;
    final id = int.tryParse(news_item_id ?? news_item_id ?? ''); // ajusta si tu id tiene otro nombre
    if (id == null) return;
    try {
      isBookmarked = await _hybridNewsRepository.isBookmarked(id);
      _bookmarkLoaded = true;
      notifyListeners();
    } catch (_) {}
  }

  /// Alterna el estado de bookmark y sincroniza vía repositorio híbrido
  Future<void> toggleBookmark() async {
    final id = int.tryParse(news_item_id ?? news_item_id ?? '');
    if (id == null) return;
    final next = !isBookmarked;
    try {
      await _hybridNewsRepository.toggleBookmark(id, value: next);
      isBookmarked = next;
      notifyListeners();
    } catch (_) {
      // Si falla, deja el estado igual
    }
  }


  // Lleva registro de eventos 'started' disparados por noticia y tipo
  bool _ratingStarted = false;
  bool _ratingCompleted = false;
  bool _commentStarted = false;
  bool _commentCompleted = false;
  final NewsRepository _repository;
  final String news_item_id;
  final String userProfileId;

  NewsItem? _news_item;
  List<Comment> _comments = [];
  bool _is_loading = true;
  bool _is_submitting_rating = false;
  bool _is_submitting_comment = false;
  // Realtime observers
  final RatingObserver _ratingObserver = RatingObserver();
  final CommentTracker _commentTracker = CommentTracker();
  int _commentStartedCount = 0;
  int _commentCompletedCount = 0;
  List<Map<String, dynamic>> _liveRatings = const [];
  // Shared controller for comment draft so overlays and inline input stay in sync
  final TextEditingController commentDraftController = TextEditingController();

  NewsDetailViewModel(this._repository, this.news_item_id, this.userProfileId, this._hybridNewsRepository) {
    _loadData();
  }

  NewsItem? get news_item => _news_item;
  List<Comment> get comments => _comments;
  bool get is_loading => _is_loading;
  bool get is_submitting_rating => _is_submitting_rating;
  bool get is_submitting_comment => _is_submitting_comment;
  int get commentStartedCount => _commentStartedCount;
  int get commentCompletedCount => _commentCompletedCount;
  List<Map<String, dynamic>> get liveRatings => _liveRatings;

  Future<void> _loadData() async {
    try {
      _is_loading = true;
      notifyListeners();
      
      _news_item = await _repository.getNewsDetail(news_item_id);
      // Record viewed article + category as a fallback in case the tap-path
      // did not persist the viewed_categories row. incrementArticlesViewed
      // is idempotent for the same news_item_id in a session.
      try {
        final catId = int.tryParse(_news_item?.category_id ?? '');
        print('🔔 [DETAIL] Recording view for news $news_item_id, category=$catId');
        await AnalyticsService().incrementArticlesViewed(_news_item!.news_item_id, catId);
      } catch (e) {
        print('⚠️ [DETAIL] Error recording view on detail load: $e');
      }
  _comments = await _repository.getComments(news_item_id);
  _attachRealtime();
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      _is_loading = false;
      notifyListeners();
    }
  }
  void _attachRealtime() {
    final nid = int.tryParse(news_item_id);
    if (nid == null) return;
    // Ratings stream (BQ3/BQ4)
    _ratingObserver.start(newsItemId: nid, onUpdate: (rows) {
      // Debug: show rating rows count for realtime updates
      // ignore: avoid_print
      print('🟢 [OBS] Ratings update for news $nid: ${rows.length} rows');
      _liveRatings = rows;
      notifyListeners();
    });
    // Comment started/completed (BQ1)
    _commentTracker.start(
      newsItemId: nid,
      onStarted: (rows) {
        // ignore: avoid_print
        print('🟡 [OBS] Comment STARTED for news $nid: ${rows.length} events');
        _commentStartedCount = rows.length;
        notifyListeners();
      },
      onCompleted: (rows) {
        // ignore: avoid_print
        print('🔵 [OBS] Comment COMPLETED for news $nid: ${rows.length} rows');
        _commentCompletedCount = rows.length;
        // Also update local comments list if a new one appears
        try {
          _comments = rows.map((r) => Comment(
            comment_id: r['comment_id'].toString(),
            news_item_id: r['news_item_id'].toString(),
            user_profile_id: r['user_profile_id']?.toString() ?? '',
            user_name: r['user_name']?.toString() ?? 'User',
            content: r['content']?.toString() ?? '',
            timestamp: DateTime.tryParse(r['timestamp'].toString()) ?? DateTime.now(),
          )).toList();
        } catch (_) {}
        notifyListeners();
      },
    );
  }

  Future<void> submitRating(double score, String? comment_text, String userProfileId) async {
    _ratingStarted = true;
    _is_submitting_rating = true;
    notifyListeners();

    try {
      // DEBUG: Verificar estado de autenticación
      final currentUser = Supabase.instance.client.auth.currentUser;
      final currentSession = Supabase.instance.client.auth.currentSession;
      print('🔐 [DEBUG] Supabase currentUser: $currentUser');
      print('🔐 [DEBUG] Supabase currentUser?.id: ${currentUser?.id}');
      print('🔐 [DEBUG] Supabase currentSession: ${currentSession != null ? "EXISTS" : "NULL"}');
      print('🔐 [DEBUG] Auth role: ${currentSession?.user.role}');
      

  // userProfileId ya viene como argumento desde el widget
      final rating_item = RatingItem(
        rating_item_id: 'rating_${DateTime.now().millisecondsSinceEpoch}',
        news_item_id: news_item_id,
        user_profile_id: userProfileId,
        assigned_reliability_score: score,
        comment_text: comment_text ?? '',
        rating_date: DateTime.now(),
        is_completed: true,
      );

      print('📤 [DEBUG] Enviando rating con user_profile_id: ${rating_item.user_profile_id}');
      print('📤 [DEBUG] news_item_id: ${rating_item.news_item_id}');
      
  // El insert lo realiza AnalyticsService.trackRatingGiven
      
      // Track rating completed event for BQ1
      await AnalyticsService().trackRatingGiven(
        int.tryParse(news_item_id) ?? 0,
        int.tryParse(userProfileId) ?? 0,
        score,
        comment_text ?? '',
      );
      _ratingCompleted = true;
      
      print('✅ [DEBUG] Rating enviado exitosamente');
    } catch (e, stackTrace) {
      print('❌ Error submitting rating: $e');
      print('❌ StackTrace: $stackTrace');
    } finally {
      _is_submitting_rating = false;
      notifyListeners();
    }
  }

  /// Mark that the user started a rating interaction (used by UI)
  void markRatingStarted() {
    _ratingStarted = true;
  }

  Future<void> submitComment(String content) async {
    _commentStarted = true;

    _is_submitting_comment = true;
    notifyListeners();

    try {
      final comment = Comment(
        comment_id: DateTime.now().millisecondsSinceEpoch.toString(),
        news_item_id: news_item_id,
        user_profile_id: userProfileId,
        user_name: 'You',
        content: content,
        timestamp: DateTime.now(),
      );
  // El insert lo realiza AnalyticsService.trackCommentCompleted
      
      // Track comment completed event for BQ1
      await AnalyticsService().trackCommentCompleted(
        int.tryParse(news_item_id) ?? 0,
        int.tryParse(userProfileId) ?? 0,
        content,
      );
      _commentCompleted = true;
      
      _comments.insert(0, comment);
    } catch (e) {
      print('Error submitting comment: $e');
    } finally {
      _is_submitting_comment = false;
      notifyListeners();
    }
  }

  /// Mark that the user started composing a comment (used by UI)
  void markCommentStarted() {
    _commentStarted = true;
  }

  @override
  void dispose() {
    // Stop realtime observers
    _ratingObserver.dispose();
    _commentTracker.dispose();
    // Dispose shared controller
    try {
      commentDraftController.dispose();
    } catch (_) {}
    // Si el usuario inició pero NO completó rating, registrar 'started'
    if (_ratingStarted && !_ratingCompleted) {
      AnalyticsService().flushRatingStart(int.tryParse(news_item_id) ?? 0, int.tryParse(userProfileId) ?? 0);
    }
    // Si el usuario inició pero NO completó comentario, registrar 'started'
    if (_commentStarted && !_commentCompleted) {
      AnalyticsService().flushCommentStart(int.tryParse(news_item_id) ?? 0, int.tryParse(userProfileId));
    }
    super.dispose();
  }
}