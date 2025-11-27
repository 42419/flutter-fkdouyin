import 'package:http/http.dart' as http;
import '../core/api_client.dart';
import '../models/video_model.dart';
import '../core/aweme_extractor.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class VideoService {
  final ApiClient _client;
  VideoService(this._client);
  
  Future<VideoModel> resolveShortLink(String shortLink, {String? token}) async {
    if (kIsWeb) {
      try {
        // Web端使用后端API处理重定向，避免CORS问题
        const apiBase = 'https://douyin-hono.liyunfei.eu.org';
        final apiUrl = '$apiBase/api/redirect?url=${Uri.encodeComponent(shortLink)}';
        final data = await _client.getJson(apiUrl, token: token);
        
        if (data['success'] == true && data['url'] != null) {
          final result = AwemeExtractor.parse(data['url']);
          if (result.awemeId != null) {
            return fetchById(result.awemeId!, token: token);
          }
        }
        throw Exception('Web重定向API返回无效数据');
      } catch (e) {
        throw Exception('Web端解析短链接失败: $e');
      }
    }

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
          return fetchById(result.awemeId!, token: token);
        }
      }
      throw Exception('无法解析短链接');
    } catch (e) {
      throw Exception('解析短链接失败: $e');
    }
  }

  Future<VideoModel> fetchById(String id, {String? token}) async {
    // 使用 backend-hono 聚合解析接口
    const baseUrl = 'https://douyin-hono.liyunfei.eu.org/api/analysis';
    // 构造一个标准抖音视频链接，后端会从中提取 aweme_id
    final url = 'https://www.douyin.com/video/$id';
    final data = await _client.getJson(baseUrl, query: {'url': url}, token: token);
    return VideoModel.fromApi(data);
  }

  Future<VideoModel?> parseInput(String input, {String? token}) async {
    final r = AwemeExtractor.parse(input);
    if (r.awemeId != null) return fetchById(r.awemeId!, token: token);
    if (r.shortLink != null && r.needsRedirect) return resolveShortLink(r.shortLink!, token: token);
    return null;
  }
}
