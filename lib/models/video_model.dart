class VideoModel {
  final String awemeId;
  final String? title;
  final String? author;
  final String? coverUrl;
  final String? playUrl;
  final int? durationMs;
  VideoModel({required this.awemeId,this.title,this.author,this.coverUrl,this.playUrl,this.durationMs});
  factory VideoModel.fromApi(Map<String,dynamic> json){
    return VideoModel(
      awemeId: (json['aweme_id'] ?? json['id'] ?? '').toString(),
      title: json['title']?.toString(),
      author: json['author']?.toString(),
      coverUrl: json['cover']?.toString() ?? json['cover_url']?.toString(),
      playUrl: json['play']?.toString() ?? json['play_url']?.toString(),
      durationMs: json['duration'] is int ? json['duration'] : null,
    );
  }
}
