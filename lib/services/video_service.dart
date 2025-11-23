import 'package:http/http.dart' as http;
import '../core/api_client.dart';
import '../models/video_model.dart';
import '../core/aweme_extractor.dart';

class VideoService {
  final ApiClient _client;
  VideoService(this._client);
  
  Future<VideoModel> resolveShortLink(String shortLink) async {
    // 本地处理短链接重定向
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(shortLink))
        ..followRedirects = false;
      final response = await client.send(request);
      final location = response.headers['location'];
      client.close();

      if (location != null && location.isNotEmpty) {
        // 从重定向后的 URL 中提取 ID
        final result = AwemeExtractor.parse(location);
        if (result.awemeId != null) {
          return fetchById(result.awemeId!);
        }
      }
      throw Exception('无法解析短链接');
    } catch (e) {
      throw Exception('解析短链接失败: $e');
    }
  }

  Future<VideoModel> fetchById(String id) async {
    // 使用 dapi 接口处理 ID 解析
    const baseUrl = 'https://dapi.liyunfei.eu.org/api/douyin/web/fetch_one_video';
    final data = await _client.getJson(baseUrl, query: {'aweme_id': id});
    return VideoModel.fromApi(data);
  }

  Future<VideoModel?> parseInput(String input) async {
    final r = AwemeExtractor.parse(input);
    if (r.awemeId != null) return fetchById(r.awemeId!);
    if (r.shortLink != null && r.needsRedirect) return resolveShortLink(r.shortLink!);
    return null;
  }
}
