import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String _releasesUrl = 'https://api.github.com/repos/42419/flutter-fkdouyin/releases/latest';
  static const String _proxyUrl = 'https://gh-proxy.org/';

  Future<void> checkUpdate(BuildContext context, {bool showNoUpdateToast = false}) async {
    try {
      // 1. Get current version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 2. Get latest version from GitHub
      final dio = Dio();
      final response = await dio.get(_releasesUrl);
      
      if (response.statusCode == 200) {
        final data = response.data;
        final String tagName = data['tag_name']; // e.g., "v1.1.0" or "1.1.0"
        final String latestVersion = tagName.replaceAll('v', '');
        String body = data['body'] ?? '修复了一些已知问题';

        // 移除 iOS 安装说明相关内容 (支持 Markdown 加粗格式)
        body = body.replaceAll(RegExp(r'(\*\*|)?iOS 安装说明(\*\*|)?[:：][\s\S]*'), '');
        
        // 移除可能残留的分隔线 (---, ***, ___)
        body = body.replaceAll(RegExp(r'\n\s*[-*_]{3,}\s*$'), '');
        
        body = body.trim();
        
        // Find download URL
        String downloadUrl = '';
        if (data['assets'] != null && (data['assets'] as List).isNotEmpty) {
          // Try to find apk asset
          final assets = data['assets'] as List;
          final apkAsset = assets.firstWhere(
            (element) => element['name'].toString().endsWith('.apk'),
            orElse: () => null,
          );
          
          if (apkAsset != null) {
            downloadUrl = _proxyUrl + apkAsset['browser_download_url'];
          }
        }
        
        // Fallback if no asset found or parsing failed
        if (downloadUrl.isEmpty) {
           downloadUrl = '${_proxyUrl}https://github.com/42419/flutter-fkdouyin/releases/download/$tagName/app-release.apk';
        }

        // 3. Compare versions
        if (_isNewVersion(currentVersion, latestVersion)) {
          if (context.mounted) {
            _showUpdateDialog(context, latestVersion, body, downloadUrl);
          }
        } else {
          if (showNoUpdateToast) {
            Fluttertoast.showToast(
              msg: "当前已是最新版本",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
            );
          }
        }
      }
    } catch (e) {
      if (showNoUpdateToast) {
        Fluttertoast.showToast(
          msg: "检查更新失败: $e",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
      }
    }
  }

  bool _isNewVersion(String current, String latest) {
    try {
      final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final lParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      // Compare major, minor, patch
      for (int i = 0; i < 3; i++) {
        final c = i < cParts.length ? cParts[i] : 0;
        final l = i < lParts.length ? lParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (e) {
      debugPrint('Version parse error: $e');
    }
    return false;
  }

  void _showUpdateDialog(BuildContext context, String version, String desc, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('发现新版本 $version'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: MarkdownBody(
              data: desc,
              styleSheet: MarkdownStyleSheet(
                p: Theme.of(context).textTheme.bodyMedium,
                listBullet: Theme.of(context).textTheme.bodyMedium,
              ),
              onTapLink: (text, href, title) {
                if (href != null) {
                  _launchUrl(href);
                }
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _launchUrl(downloadUrl);
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
