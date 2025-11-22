import '../core/api_client.dart';
import '../models/video_model.dart';
import '../core/aweme_extractor.dart';

class VideoService {
  final ApiClient _client;
  VideoService(this._client);
  Future<VideoModel> resolveShortLink(String shortLink) async {
    final data = await _client.getJson('/analysis', query: {'url': shortLink});
    return VideoModel.fromApi(data);
  }
  Future<VideoModel> fetchById(String id) async {
    final data = await _client.getJson('/douyin/web/fetch_one_video', query: {'aweme_id': id});
    return VideoModel.fromApi(data);
  }
  Future<VideoModel?> parseInput(String input) async {
    final r = AwemeExtractor.parse(input);
    if (r.awemeId != null) return fetchById(r.awemeId!);
    if (r.shortLink != null && r.needsRedirect) return resolveShortLink(r.shortLink!);
    return null;
  }
}
