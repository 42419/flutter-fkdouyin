import 'package:flutter/material.dart';
import '../services/video_service.dart';
import '../core/rate_limiter.dart';
import '../models/video_model.dart';

class VideoProvider extends ChangeNotifier {
  final VideoService service;
  final RateLimiter limiter;
  VideoModel? current;
  bool loading = false;
  String? error;
  int progress = 0;

  VideoProvider({required this.service, required this.limiter});

  Future<void> parse(String input, {String? token}) async {
    if (loading) return;
    error = null;
    loading = true;
    notifyListeners();

    if (limiter.isLimited) {
      error = '频率限制，请等待 ${limiter.remainingSeconds()} 秒';
      loading = false;
      notifyListeners();
      return;
    }
    if (!limiter.tryConsume()) {
      error = '请求过快，请稍后';
      loading = false;
      notifyListeners();
      return;
    }

    try {
      final video = await service.parseInput(input, token: token);
      if (video == null) {
        error = '未解析到视频（可能是主页链接）';
      }
      current = video;
    } catch (e) {
      error = '解析失败: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setDownloadProgress(int p) {
    progress = p;
    notifyListeners();
  }
}
