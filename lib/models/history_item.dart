class HistoryItem {
  final int id;
  final String userId;
  final String videoUrl;
  final String? title;
  final String? coverUrl;
  final int createdAt;

  HistoryItem({
    required this.id,
    required this.userId,
    required this.videoUrl,
    this.title,
    this.coverUrl,
    required this.createdAt,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'],
      userId: json['user_id'],
      videoUrl: json['video_url'],
      title: json['title'],
      coverUrl: json['cover_url'],
      createdAt: json['created_at'],
    );
  }
}
