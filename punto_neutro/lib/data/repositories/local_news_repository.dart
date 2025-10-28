import 'hybrid_news_repository.dart';
import '../../domain/repositories/news_repository.dart';
import '../../domain/models/news_item.dart';
import '../../domain/models/comment.dart';
import '../../domain/models/rating_item.dart';

/// LocalNewsRepository acts as a simple facade over HybridNewsRepository.
/// Consumers should depend on NewsRepository (interface) and can be
/// provided with LocalNewsRepository() to get offline-capable behavior.
class LocalNewsRepository implements NewsRepository {

  @override
  Future<List<NewsItem>> getNewsList() => _impl.getNewsList();
  final HybridNewsRepository _impl = HybridNewsRepository();

  LocalNewsRepository();

  @override
  Future<NewsItem?> getNewsDetail(String news_item_id) => _impl.getNewsDetail(news_item_id);

  @override
  Future<List<Comment>> getComments(String news_item_id) => _impl.getComments(news_item_id);

  @override
  Future<int> getRatingsCount(String news_item_id) => _impl.getRatingsCount(news_item_id);

  @override
  Future<void> submitComment(Comment comment) => _impl.submitComment(comment);

  @override
  Future<void> submitRating(RatingItem rating_item) => _impl.submitRating(rating_item);

  /// For callers that want to manually trigger a sync (e.g., pull-to-refresh)
  Future<void> syncPending() => _impl.syncPendingData();

  /// Dispose resources used by the implementation
  Future<void> dispose() => _impl.dispose();
}
