import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String base = 'https://dapi.liyunfei.eu.org/api';

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
}
