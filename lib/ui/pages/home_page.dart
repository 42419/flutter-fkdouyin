import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/video_provider.dart';
import '../../services/history_service.dart';
import '../../services/download_service.dart';
import '../../core/rate_limiter.dart';
import '../../models/video_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _controller = TextEditingController();
  final _history = HistoryService();
  late DownloadService _downloadService;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _history.load();
    _downloadService = DownloadService(RateLimiter(maxRequests: 5));
  }

  void _parse() async {
    final provider = context.read<VideoProvider>();
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    await provider.parse(input);
    final video = provider.current;
    if (video != null) {
      await _history.add(video);
      setState(() {}); // 刷新历史列表
    }
  }

  void _download(VideoModel video) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      if (video.playUrl == null) throw Exception('无可下载地址');
      await _downloadService.download(
        video.playUrl!,
        '/storage/emulated/0/Download/fkdouyin',
        filename: '${video.awemeId}.mp4',
        onProgress: (p) => context.read<VideoProvider>().setDownloadProgress(p),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('下载完成并保存到相册')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VideoProvider>();
    final video = provider.current;
    return Scaffold(
      appBar: AppBar(
        title: const Text('抖音解析下载'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: '输入视频链接或ID',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _controller.clear(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: provider.loading ? null : _parse,
                  icon: const Icon(Icons.search),
                  label: const Text('解析'),
                ),
                const SizedBox(width: 16),
                if (video != null && video.playUrl != null)
                  ElevatedButton.icon(
                    onPressed: _downloading ? null : () => _download(video),
                    icon: const Icon(Icons.download),
                    label: Text(_downloading ? '下载中...' : '下载'),
                  ),
              ],
            ),
            if (provider.loading) ...[
              const SizedBox(height: 20),
              const LinearProgressIndicator(),
            ],
            if (provider.error != null) ...[
              const SizedBox(height: 12),
              Text(provider.error!, style: const TextStyle(color: Colors.red)),
            ],
            if (video != null) ...[
              const SizedBox(height: 16),
              _VideoDetail(video: video, progress: provider.progress),
            ],
            const SizedBox(height: 24),
            Text('历史记录', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            for (final h in _history.items.take(20)) _HistoryTile(video: h),
          ],
        ),
      ),
    );
  }
}

class _VideoDetail extends StatelessWidget {
  final VideoModel video;
  final int progress;
  const _VideoDetail({required this.video, required this.progress});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(video.title ?? '无标题', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('作者: ${video.author ?? '未知'}'),
            const SizedBox(height: 4),
            if (video.durationMs != null) Text('时长: ${(video.durationMs! / 1000).round()} 秒'),
            if (progress > 0 && progress < 100) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress / 100),
              Text('下载进度: $progress%'),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final VideoModel video;
  const _HistoryTile({required this.video});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(video.title ?? video.awemeId, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(video.author ?? ''),
      trailing: Text(video.awemeId.substring(video.awemeId.length - 4)),
    );
  }
}
