import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  static const _tokenKey = 'auth_token';

  final AuthService service;
  String? _token;
  bool _initialised = false;
  bool _loading = false;
  String? _error;

  AuthProvider({required this.service});

  String? get token => _token;
  bool get isAuthed => _token != null && _token!.isNotEmpty;
  bool get initialised => _initialised;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> init() async {
    if (_initialised) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_tokenKey);

    if (stored != null && stored.isNotEmpty) {
      try {
        final valid = await service.verifyToken(stored);
        if (valid) {
          _token = stored;
        } else {
          await prefs.remove(_tokenKey);
          _token = null;
        }
      } catch (_) {
        // 验证异常时保持本地状态不变，交由后续登录流程处理
      }
    }

    _initialised = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final newToken = await service.login(email: email, password: password);
      _token = newToken;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, newToken);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    final currentToken = _token;
    if (currentToken == null || currentToken.isEmpty) {
      throw Exception('未登录，无法修改密码');
    }

    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await service.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
        token: currentToken,
      );
    } catch (e) {
      final msg = e.toString();
      // 如果是 401，认为登录已失效，自动登出
      if (msg.contains('登录已过期') || msg.contains('401')) {
        await logout();
      }
      _error = msg;
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
