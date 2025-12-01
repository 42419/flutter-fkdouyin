class HistoryItem {
  final int id;
  final String userId;
  final String videoUrl;
  final String? title;
  final String? coverUrl;
  final String? author;
  final String? authorAvatar;
  final int createdAt;

  HistoryItem({
    required this.id,
    required this.userId,
    required this.videoUrl,
    this.title,
    this.coverUrl,
    this.author,
    this.authorAvatar,
    required this.createdAt,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'],
      userId: json['user_id'],
      videoUrl: json['video_url'],
      title: json['title'],
      coverUrl: json['cover_url'],
      author: json['author'],
      authorAvatar: json['author_avatar'],
      createdAt: json['created_at'],
    );
  }
}
