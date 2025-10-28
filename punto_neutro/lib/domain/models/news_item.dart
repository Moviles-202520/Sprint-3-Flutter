class NewsItem {
  final String news_item_id;
  final String user_profile_id;
  final String title;
  final String short_description;
  final String image_url;
  final String category_id;
  final String author_type;
  final String author_institution;
  final int days_since;
  final int comments_count;
  final double average_reliability_score;
  final bool is_fake;
  final bool is_verified_source;
  final bool is_verified_data;
  final bool is_recognized_author;
  final bool is_manipulated;
  final String long_description;
  final String original_source_url;
  final DateTime publication_date;
  final DateTime added_to_app_date;
  final int total_ratings;

  const NewsItem({
    required this.news_item_id,
    required this.user_profile_id,
    required this.title,
    required this.short_description,
    required this.image_url,
    required this.category_id,
    required this.author_type,
    required this.author_institution,
    required this.days_since,
    required this.comments_count,
    required this.average_reliability_score,
    required this.is_fake,
    required this.is_verified_source,
    required this.is_verified_data,
    required this.is_recognized_author,
    required this.is_manipulated,
    required this.long_description,
    required this.original_source_url,
    required this.publication_date,
    required this.added_to_app_date,
    required this.total_ratings,
  });
  String get id => news_item_id;
}