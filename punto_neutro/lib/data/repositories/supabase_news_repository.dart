import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/news_repository.dart';
import '../../domain/models/news_item.dart';
import '../../domain/models/rating_item.dart';
import '../../domain/models/comment.dart';

class SupabaseNewsRepository implements NewsRepository {
  @override
  Future<List<NewsItem>> getNewsList() async {
    try {
      final response = await _supabase
          .from('news_items')
          .select()
          .order('publication_date', ascending: false)
          .limit(20);
      return response.map<NewsItem>((item) => _mapToNewsItem(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      print('❌ Error cargando lista de noticias: $e');
      return [];
    }
  }
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<NewsItem> getNewsDetail(String news_item_id) async {
    try {
      final response = await _supabase
          .from('news_items')
          .select()
          .eq('news_item_id', int.parse(news_item_id)) // ✅ CONVERTIR A INT
          .single();

      return _mapToNewsItem(response);
    } catch (e) {
      print('❌ Error cargando noticia: $e');
      throw Exception('No se pudo cargar la noticia');
    }
  }

  @override
  Future<List<Comment>> getComments(String news_item_id) async {
    try {
      final response = await _supabase
          .from('comments')
          .select()
          .eq('news_item_id', int.parse(news_item_id))
          .order('timestamp', ascending: false);

      return response.map<Comment>((comment) {
        return Comment(
          comment_id: comment['comment_id']?.toString() ?? 'unknown',
          news_item_id: comment['news_item_id']?.toString() ?? news_item_id,
          user_profile_id: comment['user_profile_id']?.toString() ?? '1',
          user_name: comment['user_name'] as String? ?? 'Usuario',
          content: comment['content'] as String? ?? '',
          timestamp: comment['timestamp'] != null 
              ? DateTime.parse(comment['timestamp'] as String)
              : DateTime.now(),
        );
      }).toList();
    } catch (e) {
      print('❌ Error cargando comentarios: $e');
      return [];
    }
  }

  // ✅ IMPLEMENTAR EL MÉTODO DE LA INTERFAZ
  @override
  Future<int> getRatingsCount(String news_item_id) async {
    try {
      final response = await _supabase
          .from('rating_items')
          .select()
          .eq('news_item_id', int.parse(news_item_id));
      
      return response.length;
    } catch (e) {
      print('❌ Error contando ratings: $e');
      return 0;
    }
  }

  @override
  Future<void> submitRating(RatingItem rating_item) async {
    try {
      final payload = {
        'news_item_id': int.tryParse(rating_item.news_item_id) ?? 1,
        'user_profile_id': int.tryParse(rating_item.user_profile_id) ?? 1,
        'assigned_reliability_score': rating_item.assigned_reliability_score,
        'comment_text': rating_item.comment_text,
        'rating_date': rating_item.rating_date.toIso8601String(),
        'is_completed': rating_item.is_completed,
      };
  print('📤 [DEBUG] Payload enviado a Supabase (submitRating): $payload');
  // El insert lo realiza AnalyticsService.trackRatingGiven
  print('✅ Rating NO enviado aquí, lo maneja AnalyticsService');
    } catch (e) {
      print('❌ Error enviando rating: $e');
    }
  }

  @override
  Future<void> submitComment(Comment comment) async {
    try {
      // El insert lo realiza AnalyticsService.trackCommentCompleted
      print('✅ Comentario NO enviado aquí, lo maneja AnalyticsService');
    } catch (e) {
      print('❌ Error guardando comentario: $e');
      rethrow;
    }
  }

  Future<void> pushBookmarks(List<int> newsIds, int userProfileId) async {
    if (newsIds.isEmpty) return;
    final rows = newsIds.map((id) => {'user_profile_id': userProfileId, 'news_item_id': id}).toList();
    await _supabase.from('bookmarks').upsert(rows, onConflict: 'user_profile_id,news_item_id');
  }

  Future<void> deleteBookmark(int newsId, int userProfileId) async {
    await _supabase.from('bookmarks').delete().match({'user_profile_id': userProfileId, 'news_item_id': newsId});
  }

  Future<Set<int>> fetchRemoteBookmarks(int userProfileId) async {
    final data = await _supabase.from('bookmarks').select('news_item_id').eq('user_profile_id', userProfileId);
    return {for (final r in data) (r['news_item_id'] as num).toInt()};
  }
  
  NewsItem _mapToNewsItem(Map<String, dynamic> response) {
  return NewsItem(
    news_item_id: (response['news_item_id']?.toString() ?? '0'), // ✅ CONVERTIR A STRING
    user_profile_id: (response['user_profile_id']?.toString() ?? '0'), // ✅ CONVERTIR A STRING
    title: response['title'] as String? ?? 'Sin título',
    short_description: response['short_description'] as String? ?? '',
    image_url: response['image_url'] as String? ?? '',
    category_id: (response['category_id']?.toString() ?? ''), // ✅ CONVERTIR A STRING
    author_type: response['author_type'] as String? ?? '',
    author_institution: response['author_institution'] as String? ?? '',
    days_since: (response['days_since'] as int?) ?? 0,
    comments_count: (response['comments_count'] as int?) ?? 0,
    average_reliability_score: (response['average_reliability_score'] as num?)?.toDouble() ?? 0.5,
    is_fake: response['is_fake'] as bool? ?? false,
    is_verified_source: response['is_verified_source'] as bool? ?? false,
    is_verified_data: response['is_verified_data'] as bool? ?? false,
    is_recognized_author: response['is_recognized_author'] as bool? ?? false,
    is_manipulated: response['is_manipulated'] as bool? ?? false,
    long_description: response['long_description'] as String? ?? '',
    original_source_url: response['original_source_url'] as String? ?? '',
    publication_date: response['publication_date'] != null 
        ? DateTime.parse(response['publication_date'] as String)
        : DateTime.now(),
    added_to_app_date: response['added_to_app_date'] != null
        ? DateTime.parse(response['added_to_app_date'] as String)
        : DateTime.now(),
    total_ratings: (response['total_ratings'] as int?) ?? 0,
  );
}
}