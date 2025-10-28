import '../models/news_item.dart';
import '../models/rating_item.dart';
import '../models/comment.dart';

abstract class NewsRepository {
  Future<List<NewsItem>> getNewsList();
  Future<NewsItem?> getNewsDetail(String news_item_id);
  Future<List<Comment>> getComments(String news_item_id);
  Future<int> getRatingsCount(String news_item_id);
  Future<void> submitRating(RatingItem rating_item);
  Future<void> submitComment(Comment comment);
}