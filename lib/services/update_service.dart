import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'web_reload_helper.dart';

class UpdateService {
  static const String _releasesUrl = 'https://api.github.com/repos/42419/flutter-fkdouyin/releases/latest';
  static const String _allReleasesUrl = 'https://api.github.com/repos/42419/flutter-fkdouyin/releases';
  static const String _proxyUrl = 'https://gh-proxy.org/';
  static const String _kIgnoreVersion = 'ignore_version';

  Future<List<Map<String, dynamic>>> getReleases() async {
    try {
      final dio = Dio();
      final response = await dio.get(_allReleasesUrl);
      
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (e) {
      debugPrint('Failed to fetch releases: $e');
    }
    return [];
  }

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
          final assets = data['assets'] as List;
          Map<String, dynamic>? targetAsset;

          // 尝试根据架构匹配 APK
          if (!kIsWeb && Platform.isAndroid) {
            try {
              final androidInfo = await DeviceInfoPlugin().androidInfo;
              final abis = androidInfo.supportedAbis;
              
              if (abis.isNotEmpty) {
                // 优先匹配首选架构
                for (final abi in abis) {
                  targetAsset = assets.firstWhere(
                    (element) {
                      final name = element['name'].toString().toLowerCase();
                      return name.endsWith('.apk') && name.contains(abi.toLowerCase());
                    },
                    orElse: () => null,
                  );
                  if (targetAsset != null) break;
                }
              }
            } catch (e) {
              debugPrint('Failed to get device info: $e');
            }
          }

          // 如果没找到特定架构的，或者不是 Android，尝试找通用 APK 或者任意 APK
          if (targetAsset == null) {
            targetAsset = assets.firstWhere(
              (element) => element['name'].toString().endsWith('.apk'),
              orElse: () => null,
            );
          }
          
          if (targetAsset != null) {
            downloadUrl = _proxyUrl + targetAsset['browser_download_url'];
          }
        }
        
        // Fallback if no asset found or parsing failed
        if (downloadUrl.isEmpty) {
           downloadUrl = '${_proxyUrl}https://github.com/42419/flutter-fkdouyin/releases/download/$tagName/app-release.apk';
        }

        // 3. Compare versions
        if (_isNewVersion(currentVersion, latestVersion)) {
          // Check if ignored
          if (!showNoUpdateToast) {
            final prefs = await SharedPreferences.getInstance();
            final ignoredVersion = prefs.getString(_kIgnoreVersion);
            if (ignoredVersion == latestVersion) {
              return;
            }
          }

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
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(_kIgnoreVersion, version);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('不再提醒', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (kIsWeb) {
                reloadPage();
              } else {
                _launchUrl(downloadUrl);
              }
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
