import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  final String baseUrl;

  AuthService({required this.baseUrl});

  Future<String> login({required String email, required String password}) async {
    final uri = Uri.parse('$baseUrl/login');
    final resp = await http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final token = data['token'] as String?;
      if (token == null || token.isEmpty) {
        throw Exception('登录返回数据异常');
      }
      return token;
    }
    throw Exception('登录失败 ${resp.statusCode}: ${resp.reasonPhrase ?? ''}');
  }

  Future<bool> verifyToken(String token) async {
    final uri = Uri.parse('$baseUrl/me');
    final resp = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (resp.statusCode == 200) {
      return true;
    }
    if (resp.statusCode == 401) {
      return false;
    }
    throw Exception('验证登录状态失败 ${resp.statusCode}: ${resp.reasonPhrase ?? ''}');
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/change_password');
    final resp = await http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      }),
    );

    if (resp.statusCode == 200) {
      return;
    }
    if (resp.statusCode == 401) {
      throw Exception('原密码错误或登录已过期');
    }
    throw Exception('修改密码失败 ${resp.statusCode}: ${resp.reasonPhrase ?? ''}');
  }
}
