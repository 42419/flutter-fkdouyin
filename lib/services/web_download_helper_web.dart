import 'dart:html' as html;
import 'package:dio/dio.dart';

Future<void> downloadVideoWeb(String url, String filename, {String? token, void Function(int)? onProgress}) async {
  // 使用后端代理API下载，解决CORS问题
  const apiBase = 'https://douyin-hono.liyunfei.eu.org';
  final apiUrl = '$apiBase/api/download?url=${Uri.encodeComponent(url)}&filename=${Uri.encodeComponent(filename)}';

  try {
    final dio = Dio();
    final response = await dio.get(
      apiUrl,
      options: Options(
        responseType: ResponseType.bytes,
        headers: token != null && token.isNotEmpty
            ? {'Authorization': 'Bearer $token'}
            : null,
      ),
      onReceiveProgress: (received, total) {
        if (total != -1 && onProgress != null) {
          onProgress(((received / total) * 100).toInt());
        }
      },
    );

    final blob = html.Blob([response.data]);
    final downloadUrl = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: downloadUrl)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    
    html.document.body!.children.add(anchor);
    anchor.click();
    
    html.document.body!.children.remove(anchor);
    html.Url.revokeObjectUrl(downloadUrl);
  } catch (e) {
    // 如果代理下载失败，尝试直接打开链接（备用方案）
    html.window.open(url, '_blank');
    throw Exception('代理下载失败，已尝试在新窗口打开: $e');
  }
}
