class Comment {
  final String comment_id;
  final String news_item_id;
  final String user_profile_id;
  final String user_name;
  final String content;
  final DateTime timestamp;

  Comment({
    required this.comment_id,
    required this.news_item_id,
    required this.user_profile_id,
    required this.user_name,
    required this.content,
    required this.timestamp,
  });

  String get time_ago {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  Map<String, dynamic> toJson() => {
    'comment_id': comment_id,
    'news_item_id': news_item_id,
    'user_profile_id': user_profile_id,
    'user_name': user_name,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };
}