import 'dart:convert';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_model.dart';
import '../models/history_item.dart';
import '../core/api_client.dart';
import '../core/aweme_extractor.dart';

class HistoryService {
  static const _fileName = 'history.json';
  static const _prefsKey = 'history_data';
  List<VideoModel> _items = [];
  List<VideoModel> _remoteItems = [];
  bool _useRemote = false;

  List<VideoModel> get items => _useRemote ? List.unmodifiable(_remoteItems) : List.unmodifiable(_items);

  Future<File> _historyFile() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$_fileName');
    if (!await file.exists()) await file.writeAsString('[]');
    return file;
  }

  Future<void> load() async {
    _useRemote = false;
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final txt = prefs.getString(_prefsKey);
        if (txt != null) {
           final data = jsonDecode(txt) as List;
           _items = data.map((e) => VideoModel.fromJson(e as Map<String, dynamic>)).toList();
        } else {
           _items = [];
        }
      } else {
        final file = await _historyFile();
        final txt = await file.readAsString();
        final data = jsonDecode(txt) as List;
        _items = data.map((e) => VideoModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      _items = [];
    }
  }

  Future<void> loadRemote(String token, {int page = 1}) async {
    try {
      final client = ApiClient();
      final resp = await client.getHistory(page: page, token: token);
      final List list = resp['data'] ?? [];
      _remoteItems = list.map((e) {
        final item = HistoryItem.fromJson(e);
        // 尝试从 URL 中提取 ID，保持与本地解析一致
        final extract = AwemeExtractor.parse(item.videoUrl);
        final id = extract.awemeId ?? item.videoUrl;
        
        return VideoModel(
          awemeId: id,
          title: item.title,
          coverUrl: item.coverUrl,
          author: item.author,
          authorAvatar: item.authorAvatar,
          // Fill required fields with defaults
          statistics: VideoStatistics(),
          downloadOptions: [],
        );
      }).toList();
      _useRemote = true;
    } catch (e) {
      print('Load remote history failed: $e');
    }
  }

  Future<void> add(VideoModel model) async {
    if (_useRemote) {
      // 远程模式：后端已处理去重（Upsert），前端仅需更新 UI
      // 移除旧的相同 ID 记录，并将新记录插到最前
      _remoteItems.removeWhere((e) => e.awemeId == model.awemeId);
      _remoteItems.insert(0, model);
    } else {
      _items.removeWhere((e) => e.awemeId == model.awemeId); // 去重
      _items.insert(0, model); // 最近的前排
      await _persist();
    }
  }

  Future<void> clear() async {
    if (_useRemote) {
      // Remote clear not implemented in backend yet?
      // Assuming we just clear local view for now or implement API
      _remoteItems.clear();
    } else {
      _items.clear();
      await _persist();
    }
  }


  Future<void> _persist() async {
    final list = _items.map((e) => e.toJson()).toList();
    final jsonStr = jsonEncode(list);
    
    if (kIsWeb) {
       final prefs = await SharedPreferences.getInstance();
       await prefs.setString(_prefsKey, jsonStr);
    } else {
       final file = await _historyFile();
       await file.writeAsString(jsonStr);
    }
  }
}
