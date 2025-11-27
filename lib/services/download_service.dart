import 'package:universal_io/io.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/rate_limiter.dart';
import 'web_download_helper.dart';

class DownloadService {
  final Dio _dio = Dio();
  final RateLimiter limiter;
  DownloadService(this.limiter);

  Future<bool> requestPermission() async {
    if (kIsWeb) return true;
    try {
      final hasAccess = await Gal.hasAccess();
      if (hasAccess) return true;
      return await Gal.requestAccess();
    } catch (e) {
      return false;
    }
  }

  Future<void> download(String url, {String? filename, String? token, void Function(int)? onProgress}) async {
    if (limiter.isLimited || !limiter.tryConsume()) {
      throw Exception('下载频率受限');
    }

    if (kIsWeb) {
      final name = filename ?? 'douyin_${DateTime.now().millisecondsSinceEpoch}.mp4';
      await downloadVideoWeb(url, name, token: token, onProgress: onProgress);
      return;
    }

    // 1. 自动申请权限
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      // 再次检查是否被永久拒绝，如果是，抛出特定异常供 UI 处理
      if (await Permission.storage.isPermanentlyDenied || 
          await Permission.photos.isPermanentlyDenied || 
          await Permission.videos.isPermanentlyDenied) {
        throw Exception('permission_permanently_denied');
      }
      throw Exception('未授予保存到相册的权限');
    }

    // 2. 下载到临时目录 (避免 Android 10+ 存储权限问题)
    final tempDir = await getTemporaryDirectory();
    final name = filename ?? 'douyin_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final tempPath = '${tempDir.path}/$name';

    // 后端下载代理地址
    const apiBase = 'https://douyin-hono.liyunfei.eu.org';
    final apiUrl = '$apiBase/api/download?url=${Uri.encodeComponent(url)}&filename=${Uri.encodeComponent(name)}';

    try {
      final resp = await _dio.download(
        apiUrl,
        tempPath,
        onReceiveProgress: (r, t) {
          if (t > 0 && onProgress != null) {
            onProgress(((r / t) * 100).clamp(0, 100).toInt());
          }
        },
        options: Options(
          followRedirects: true, 
          responseType: ResponseType.bytes, 
          validateStatus: (s) => s != null && s < 500,
          headers: token != null && token.isNotEmpty
              ? {'Authorization': 'Bearer $token'}
              : null,
        ),
      );

      if (resp.statusCode != 200) throw Exception('下载失败: ${resp.statusCode}');

      // 3. 保存到相册
      await Gal.putVideo(tempPath, album: 'fkdouyin');

      // 4. 清理临时文件
      final file = File(tempPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // 清理临时文件
      final file = File(tempPath);
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }
}
