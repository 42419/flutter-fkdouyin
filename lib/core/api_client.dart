import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String base = 'https://dapi.liyunfei.eu.org/api';

  Future<Map<String, dynamic>> getJson(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$base$path').replace(queryParameters: query);
    final resp = await http.get(uri, headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    });
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return {};
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('请求失败 ${resp.statusCode}: ${resp.reasonPhrase}');
  }
}
