import 'dart:convert';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_model.dart';

class HistoryService {
  static const _fileName = 'history.json';
  static const _prefsKey = 'history_data';
  List<VideoModel> _items = [];
  List<VideoModel> get items => List.unmodifiable(_items);

  Future<File> _historyFile() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$_fileName');
    if (!await file.exists()) await file.writeAsString('[]');
    return file;
  }

  Future<void> load() async {
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

  Future<void> add(VideoModel model) async {
    _items.removeWhere((e) => e.awemeId == model.awemeId); // 去重
    _items.insert(0, model); // 最近的前排
    await _persist();
  }

  Future<void> clear() async {
    _items.clear();
    await _persist();
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
