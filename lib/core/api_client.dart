import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String base = 'https://douyin-hono.liyunfei.eu.org/api';

  Future<Map<String, dynamic>> getJson(String url, {Map<String, String>? query, String? token}) async {
    final uri = Uri.parse(url).replace(queryParameters: query);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.bodyBytes.isEmpty) return {};
      final decodedBody = utf8.decode(resp.bodyBytes);
      return jsonDecode(decodedBody) as Map<String, dynamic>;
    }
    throw Exception('请求失败 ${resp.statusCode}: ${resp.reasonPhrase}');
  }

  Future<Map<String, dynamic>> getHistory({int page = 1, int limit = 10, required String token}) async {
    return getJson('$base/history', query: {
      'page': page.toString(),
      'limit': limit.toString(),
    }, token: token);
  }

  Future<void> deleteHistoryItem(int id, String token) async {
    final uri = Uri.parse('$base/history/$id');
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
    };
    final resp = await http.delete(uri, headers: headers);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('删除失败 ${resp.statusCode}: ${resp.reasonPhrase}');
    }
  }

  Future<void> clearHistory(String token) async {
    final uri = Uri.parse('$base/history');
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
    };
    final resp = await http.delete(uri, headers: headers);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('清空失败 ${resp.statusCode}: ${resp.reasonPhrase}');
    }
  }
}
