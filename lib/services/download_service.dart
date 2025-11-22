import 'dart:io';
import 'package:dio/dio.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/rate_limiter.dart';

class DownloadService {
  final Dio _dio = Dio();
  final RateLimiter limiter;
  DownloadService(this.limiter);

  Future<bool> ensurePermissions() async {
    if (!Platform.isAndroid) return true; // 仅安卓目标
    final sdkInt = await _androidSdkInt();
    if (sdkInt != null && sdkInt >= 33) {
      final status = await Permission.videos.request();
      return status.isGranted;
    } else {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
  }

  Future<int?> _androidSdkInt() async {
    try {
      final file = File('/system/build.prop');
      if (!await file.exists()) return null;
      final lines = await file.readAsLines();
      for (final l in lines) {
        if (l.startsWith('ro.build.version.sdk=')) {
          return int.tryParse(l.split('=').last.trim());
        }
      }
    } catch (_) {}
    return null;
  }

  Future<File> download(String url, String saveDir, {String? filename, void Function(int)? onProgress}) async {
    if (limiter.isLimited || !limiter.tryConsume()) {
      throw Exception('下载频率受限');
    }
    final ok = await ensurePermissions();
    if (!ok) throw Exception('未授予存储/媒体权限');

    final name = filename ?? 'douyin_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final dir = Directory(saveDir);
    if (!await dir.exists()) await dir.create(recursive: true);
    final filePath = '${dir.path}/$name';
    final tempPath = '$filePath.part';

    final resp = await _dio.download(
      url,
      tempPath,
      onReceiveProgress: (r, t) {
        if (t > 0 && onProgress != null) {
          onProgress(((r / t) * 100).clamp(0, 100).toInt());
        }
      },
      options: Options(followRedirects: true, responseType: ResponseType.bytes, validateStatus: (s) => s != null && s < 500),
    );
    if (resp.statusCode != 200) throw Exception('下载失败: ${resp.statusCode}');

    final partFile = File(tempPath);
    if (!await partFile.exists()) throw Exception('临时文件缺失');
    await partFile.rename(filePath);

    await GallerySaver.saveVideo(filePath, albumName: 'fkdouyin');
    return File(filePath);
  }
}
