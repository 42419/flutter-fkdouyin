import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:universal_io/io.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import '../core/rate_limiter.dart';
import 'web_download_helper.dart';

@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
  send?.send([id, status, progress]);
}

class DownloadService {
  final Dio _dio = Dio();
  final RateLimiter limiter;
  final ReceivePort _port = ReceivePort();
  final Map<String, _DownloadTaskInfo> _tasks = {};

  DownloadService(this.limiter) {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _bindBackgroundIsolate();
      FlutterDownloader.registerCallback(downloadCallback);
    }
  }

  void dispose() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _unbindBackgroundIsolate();
      _port.close();
    }
  }

  void _bindBackgroundIsolate() {
    final isSuccess = IsolateNameServer.registerPortWithName(
      _port.sendPort,
      'downloader_send_port',
    );
    if (!isSuccess) {
      _unbindBackgroundIsolate();
      _bindBackgroundIsolate();
      return;
    }
    _port.listen((dynamic data) {
      final String id = data[0];
      final int status = data[1];
      final int progress = data[2];

      if (_tasks.containsKey(id)) {
        final task = _tasks[id]!;
        if (task.onProgress != null) {
          task.onProgress!(progress);
        }

        if (status == DownloadTaskStatus.complete.index) {
          task.completer.complete();
          _tasks.remove(id);
        } else if (status == DownloadTaskStatus.failed.index) {
          task.completer.completeError(Exception('Download failed'));
          _tasks.remove(id);
        } else if (status == DownloadTaskStatus.canceled.index) {
           task.completer.completeError(Exception('Download canceled'));
           _tasks.remove(id);
        }
      }
    });
  }

  void _unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return true;
    try {
      // Android 13+ 需要通知权限
      if (Platform.isAndroid) {
        await Permission.notification.request();
      }
      
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

    // 2. 下载到应用文档目录 (更安全，避免被系统清理)
    final appDocDir = await getApplicationDocumentsDirectory();
    final name = filename ?? 'douyin_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final savePath = '${appDocDir.path}/$name';

    // 移动端/桌面端直接下载，不走代理
    const userAgent = 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

    if (Platform.isAndroid || Platform.isIOS) {
       final completer = Completer<void>();
       
       try {
         final taskId = await FlutterDownloader.enqueue(
            url: url,
            savedDir: appDocDir.path,
            fileName: name,
            headers: {'User-Agent': userAgent},
            showNotification: true,
            openFileFromNotification: false,
            saveInPublicStorage: false,
         );
         
         if (taskId != null) {
            _tasks[taskId] = _DownloadTaskInfo(completer, onProgress);
            
            // 启动一个定时器轮询状态，作为回调失效的兜底
            Timer.periodic(const Duration(seconds: 1), (timer) async {
              if (completer.isCompleted) {
                timer.cancel();
                return;
              }
              final tasks = await FlutterDownloader.loadTasksWithRawQuery(query: 'SELECT * FROM task WHERE task_id="$taskId"');
              if (tasks != null && tasks.isNotEmpty) {
                final task = tasks.first;
                if (task.status == DownloadTaskStatus.complete) {
                   if (!_tasks.containsKey(taskId)) return; // 已经被回调处理了
                   _tasks[taskId]?.completer.complete();
                   _tasks.remove(taskId);
                   timer.cancel();
                } else if (task.status == DownloadTaskStatus.failed) {
                   if (!_tasks.containsKey(taskId)) return;
                   _tasks[taskId]?.completer.completeError(Exception('Download failed (polled)'));
                   _tasks.remove(taskId);
                   timer.cancel();
                } else if (task.status == DownloadTaskStatus.canceled) {
                   if (!_tasks.containsKey(taskId)) return;
                   _tasks[taskId]?.completer.completeError(Exception('Download canceled (polled)'));
                   _tasks.remove(taskId);
                   timer.cancel();
                } else if (task.status == DownloadTaskStatus.running) {
                   if (onProgress != null) {
                     onProgress(task.progress);
                   }
                }
              }
            });

            await completer.future;
            
            // 3. 保存到相册
            await Gal.putVideo(savePath, album: 'fkdouyin');
            
            // 4. 清理临时文件
            final file = File(savePath);
            if (await file.exists()) {
              await file.delete();
            }
         } else {
            throw Exception('Failed to start download');
         }
       } catch (e) {
          // 清理临时文件
          final file = File(savePath);
          if (await file.exists()) {
            await file.delete();
          }
          rethrow;
       }
       return;
    }

    try {
      final resp = await _dio.download(
        url,
        savePath,
        onReceiveProgress: (r, t) {
          if (t > 0 && onProgress != null) {
            onProgress(((r / t) * 100).clamp(0, 100).toInt());
          }
        },
        options: Options(
          followRedirects: true, 
          responseType: ResponseType.bytes, 
          validateStatus: (s) => s != null && s < 500,
          headers: {'User-Agent': userAgent},
        ),
      );

      if (resp.statusCode != 200) throw Exception('下载失败: ${resp.statusCode}');

      // 3. 保存到相册
      await Gal.putVideo(savePath, album: 'fkdouyin');

      // 4. 清理临时文件
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // 清理临时文件
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }
}

class _DownloadTaskInfo {
  final Completer<void> completer;
  final void Function(int)? onProgress;
  _DownloadTaskInfo(this.completer, this.onProgress);
}
