import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/video_model.dart';

class HistoryService {
  static const _fileName = 'history.json';
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
      final file = await _historyFile();
      final txt = await file.readAsString();
      final data = jsonDecode(txt) as List;
      _items = data.map((e) => VideoModel.fromJson(e as Map<String, dynamic>)).toList();
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
    final file = await _historyFile();
    final list = _items.map((e) => e.toJson()).toList();
    await file.writeAsString(jsonEncode(list));
  }
}
