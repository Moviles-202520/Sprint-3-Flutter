class RatingItem {
  final String rating_item_id;
  final String news_item_id;
  final String user_profile_id;
  final double assigned_reliability_score;
  final String comment_text;
  final DateTime rating_date;
  final bool is_completed;

  RatingItem({
    required this.rating_item_id,
    required this.news_item_id,
    required this.user_profile_id,
    required this.assigned_reliability_score,
    required this.comment_text,
    required this.rating_date,
    required this.is_completed,
  });

  Map<String, dynamic> toJson() => {
    'rating_item_id': rating_item_id,
    'news_item_id': news_item_id,
    'user_profile_id': user_profile_id,
    'assigned_reliability_score': assigned_reliability_score,
    'comment_text': comment_text,
    'rating_date': rating_date.toIso8601String(),
    'is_completed': is_completed,
  };
}