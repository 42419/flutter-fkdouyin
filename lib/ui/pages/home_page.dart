import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/video_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/history_service.dart';
import '../../services/download_service.dart';
import '../../core/rate_limiter.dart';
import '../../models/video_model.dart';

import 'package:permission_handler/permission_handler.dart';

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
    
    // 收起键盘
    FocusScope.of(context).unfocus();
    
    await provider.parse(input);
    final video = provider.current;
    if (video != null) {
      await _history.add(video);
      setState(() {}); // 刷新历史列表
    }
  }

  void _download(String url, String filename) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      await _downloadService.download(
        url,
        filename: filename,
        onProgress: (p) => context.read<VideoProvider>().setDownloadProgress(p),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('下载完成并保存到相册')),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = '下载失败: $e';
        if (e.toString().contains('permission_permanently_denied')) {
          msg = '请在设置中开启相册/存储权限';
          _showPermissionDialog();
        } else if (e.toString().contains('未授予')) {
          msg = '需要权限才能保存视频';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('权限申请'),
        content: const Text('保存视频需要访问相册权限，当前权限已被永久拒绝，请前往设置开启。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  void _showDownloadOptions(VideoModel video) {
    if (video.downloadOptions.isEmpty) {
      if (video.playUrl != null) {
         _download(video.playUrl!, '${video.awemeId}.mp4');
         return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('无可用下载链接')));
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('选择下载清晰度', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: video.downloadOptions.map((option) => ListTile(
                    leading: const Icon(Icons.video_file_outlined),
                    title: Text('${option.quality} (${option.resolution})'),
                    subtitle: Text('${_formatSize(option.size)} • ${option.frameRate}FPS • ${option.format}'),
                    trailing: const Icon(Icons.download),
                    onTap: () {
                      Navigator.pop(context);
                      _download(option.url, '${video.awemeId}_${option.quality}.mp4');
                    },
                  )).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '未知大小';
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    double size = bytes.toDouble();
    while (size > 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  void _clearHistory() async {
    await _history.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VideoProvider>();
    final video = provider.current;
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            title: const Text('视频下载工具', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => themeProvider.toggleTheme(),
                tooltip: '切换主题',
              ),
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  // TODO: Show menu
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: Column(
                children: [
                  Text(
                    '抖音视频下载',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '支持抖音视频解析与下载，无水印高清视频',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: const InputDecoration(
                              hintText: '粘贴抖音视频链接...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onSubmitted: (_) => _parse(),
                          ),
                        ),
                        FilledButton(
                          onPressed: provider.loading ? null : _parse,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: provider.loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('解析'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTip(context, '📱', '支持手机/网页'),
                      _buildTip(context, '🎯', '无水印高清'),
                      _buildTip(context, '⚡', '快速解析'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (provider.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      provider.error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            if (video != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _VideoDetailCard(
                  video: video,
                  progress: provider.progress,
                  onDownload: () => _showDownloadOptions(video),
                  isDownloading: _downloading,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '📜 解析历史',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: _clearHistory,
                    child: const Text('清空历史'),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = _history.items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _HistoryCard(video: item),
                  );
                },
                childCount: _history.items.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildTip(BuildContext context, String icon, String text) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
        ),
      ],
    );
  }
}

class _VideoDetailCard extends StatelessWidget {
  final VideoModel video;
  final int progress;
  final VoidCallback onDownload;
  final bool isDownloading;

  const _VideoDetailCard({
    required this.video,
    required this.progress,
    required this.onDownload,
    required this.isDownloading,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author Info
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: video.authorAvatar != null ? NetworkImage(video.authorAvatar!) : null,
                  child: video.authorAvatar == null ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.author ?? '未知作者',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (video.authorSignature != null && video.authorSignature!.isNotEmpty)
                        Text(
                          video.authorSignature!,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Video Content
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (video.coverUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      video.coverUrl!,
                      width: 100,
                      height: 130,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 100,
                        height: 130,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title ?? '无标题',
                        style: Theme.of(context).textTheme.bodyLarge,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _buildStat(Icons.favorite, video.statistics.diggCount),
                          _buildStat(Icons.comment, video.statistics.commentCount),
                          _buildStat(Icons.star, video.statistics.collectCount),
                          _buildStat(Icons.share, video.statistics.shareCount),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (progress > 0 && progress < 100) ...[
              LinearProgressIndicator(value: progress / 100),
              const SizedBox(height: 8),
              Text('下载进度: $progress%', style: Theme.of(context).textTheme.bodySmall),
            ] else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isDownloading ? null : onDownload,
                  icon: const Icon(Icons.download),
                  label: Text(isDownloading ? '下载中...' : '下载视频 (${video.downloadOptions.length}个源)'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          _formatCount(count),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count > 10000) {
      return '${(count / 10000).toStringAsFixed(1)}w';
    }
    return count.toString();
  }
}

class _HistoryCard extends StatelessWidget {
  final VideoModel video;
  const _HistoryCard({required this.video});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: video.coverUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  video.coverUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.movie),
                ),
              )
            : const Icon(Icons.movie),
        title: Text(
          video.title ?? video.awemeId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(video.author ?? '未知作者'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // TODO: 点击历史记录重新加载或播放
          context.read<VideoProvider>().parse(video.playUrl ?? video.awemeId);
        },
      ),
    );
  }
}
