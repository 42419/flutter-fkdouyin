import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../../providers/video_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/history_service.dart';
import '../../services/download_service.dart';
import '../../services/update_service.dart';
import '../../core/rate_limiter.dart';
import '../../models/video_model.dart';
import 'about_page.dart';
import 'package:web_smooth_scroll/web_smooth_scroll.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/rendering.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _history = HistoryService();
  late DownloadService _downloadService;
  bool _downloading = false;
  final GlobalKey _repaintKey = GlobalKey();
  final GlobalKey _themeButtonKey = GlobalKey();
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    final auth = context.read<AuthProvider>();
    auth.addListener(_handleAuthChange);
    
    // Initial load
    _handleAuthChange();
    
    _downloadService = DownloadService(RateLimiter(maxRequests: 5));
    
    // Check for updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService().checkUpdate(context);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _downloadService.dispose();
    context.read<AuthProvider>().removeListener(_handleAuthChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleAuthChange() {
    final auth = context.read<AuthProvider>();
    if (auth.isAuthed) {
      _history.loadRemote(auth.token!).then((_) {
        if (mounted) setState(() {});
      });
    } else {
      _history.load().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _toggleThemeWithAnimation() async {
    final themeProvider = context.read<ThemeProvider>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 1. 获取按钮位置
    final RenderBox? buttonBox = _themeButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (buttonBox == null) {
      themeProvider.toggleTheme();
      return;
    }
    final Offset buttonPosition = buttonBox.localToGlobal(Offset.zero);
    final Size buttonSize = buttonBox.size;
    final Offset center = buttonPosition + Offset(buttonSize.width / 2, buttonSize.height / 2);

    // 2. 截图当前界面 (旧主题)
    final RenderRepaintBoundary? boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      themeProvider.toggleTheme();
      return;
    }

    try {
      final ui.Image image = await boundary.toImage(pixelRatio: MediaQuery.of(context).devicePixelRatio);
      
      // 3. 切换主题
      themeProvider.toggleTheme();
      
      // 4. 插入 Overlay
      if (!mounted) return;
      final overlayState = Overlay.of(context);
      late OverlayEntry overlayEntry;
      
      overlayEntry = OverlayEntry(
        builder: (context) {
          return _ThemeTransitionOverlay(
            image: image,
            center: center,
            isDarkToLight: isDark,
            onFinished: () {
              overlayEntry.remove();
            },
          );
        },
      );
      
      overlayState.insert(overlayEntry);
      
    } catch (e) {
      // 如果截图失败，直接切换
      themeProvider.toggleTheme();
    }
  }

  void _parse() async {
    final provider = context.read<VideoProvider>();
    final authToken = context.read<AuthProvider>().token;
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    
    // 收起键盘
    _focusNode.unfocus();
    
    await provider.parse(input, token: authToken);
    final video = provider.current;
    if (video != null) {
      await _history.add(video);
      setState(() {}); // 刷新历史列表
    }
  }

  void _download(String url, String filename) async {
    if (_downloading) return;
    
    // 强制收起键盘，防止焦点跳动
    _focusNode.unfocus();
    
    setState(() => _downloading = true);
    final authToken = context.read<AuthProvider>().token;
    try {
      await _downloadService.download(
        url,
        filename: filename,
        token: authToken,
        onProgress: (p) => context.read<VideoProvider>().setDownloadProgress(p),
      );
      if (mounted) {
        Fluttertoast.showToast(
          msg: kIsWeb ? "下载完成" : "下载完成并保存到相册",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
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
        Fluttertoast.showToast(
          msg: msg,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
        context.read<VideoProvider>().setDownloadProgress(0);
      }
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
    _focusNode.unfocus();
    if (video.downloadOptions.isEmpty) {
      if (video.playUrl != null) {
         _download(video.playUrl!, '${video.awemeId}.mp4');
         return;
      }
      Fluttertoast.showToast(msg: "无可用下载链接");
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final primaryColor = Theme.of(context).colorScheme.primary;
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.download_rounded, color: primaryColor),
                      const SizedBox(width: 8),
                      const Text('选择下载清晰度', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text('${video.downloadOptions.length}个资源', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: video.downloadOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final option = video.downloadOptions[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.video_file_rounded, color: primaryColor),
                          ),
                          title: Row(
                            children: [
                              Text(option.quality, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  option.resolution,
                                  style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('${_formatSize(option.size)} • ${option.frameRate}FPS • ${option.format}'),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.download_for_offline_rounded, color: primaryColor, size: 28),
                            onPressed: () {
                              Navigator.pop(context);
                              _download(option.url, '${video.awemeId}_${option.quality}.mp4');
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
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
    if (_history.items.isEmpty) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确定要清空所有解析历史吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _history.clear();
        setState(() {});
      } catch (e) {
        if (mounted) {
          Fluttertoast.showToast(msg: '清空失败: $e');
        }
      }
    }
  }

  void _deleteHistoryItem(VideoModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除这条记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _history.delete(item);
        setState(() {});
      } catch (e) {
        if (mounted) {
          Fluttertoast.showToast(msg: '删除失败: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VideoProvider>();
    final video = provider.current;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final slivers = [
          SliverAppBar(
            automaticallyImplyLeading: false,
            floating: true,
            pinned: true,
            title: const Text('视频下载工具', style: TextStyle(fontWeight: FontWeight.bold)),
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
            actions: [
              IconButton(
                key: _themeButtonKey,
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => _toggleThemeWithAnimation(),
                tooltip: '切换主题',
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.menu),
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                onSelected: (value) async {
                  if (value == 'about') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AboutPage()),
                    );
                  } else if (value == 'change_password') {
                    final oldController = TextEditingController();
                    final newController = TextEditingController();
                    final confirmController = TextEditingController();
                    final formKey = GlobalKey<FormState>();

                    showDialog(
                      context: context,
                      builder: (ctx) {
                        return AlertDialog(
                          title: const Text('修改密码'),
                          content: Form(
                            key: formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextFormField(
                                  controller: oldController,
                                  obscureText: true,
                                  decoration: const InputDecoration(labelText: '原密码'),
                                  validator: (v) => (v == null || v.isEmpty) ? '请输入原密码' : null,
                                ),
                                SizedBox(height: 12),
                                TextFormField(
                                  controller: newController,
                                  obscureText: true,
                                  decoration: const InputDecoration(labelText: '新密码'),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return '请输入新密码';
                                    if (v.length < 6) return '密码至少 6 位';
                                    return null;
                                  },
                                ),
                                SizedBox(height: 12),
                                TextFormField(
                                  controller: confirmController,
                                  obscureText: true,
                                  decoration: const InputDecoration(labelText: '确认新密码'),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return '请再次输入新密码';
                                    if (v != newController.text) return '两次输入不一致';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () async {
                                final form = formKey.currentState;
                                if (form == null || !form.validate()) return;
                                try {
                                  await ctx.read<AuthProvider>().changePassword(
                                        oldController.text,
                                        newController.text,
                                      );
                                  if (ctx.mounted) {
                                    Navigator.of(ctx).pop();
                                    Fluttertoast.showToast(msg: '密码修改成功');
                                  }
                                } catch (e) {
                                  Fluttertoast.showToast(msg: '修改密码失败: $e');
                                }
                              },
                              child: const Text('确认修改'),
                            ),
                          ],
                        );
                      },
                    );
                  } else if (value == 'logout') {
                    await context.read<AuthProvider>().logout();
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                    }
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'change_password',
                    child: Row(
                      children: [
                        Icon(Icons.lock_reset_rounded),
                        SizedBox(width: 12),
                        Text('修改密码'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded),
                        SizedBox(width: 12),
                        Text('退出登录'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'about',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded),
                        SizedBox(width: 12),
                        Text('关于应用'),
                      ],
                    ),
                  ),
                ],
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
                            focusNode: _focusNode,
                            decoration: InputDecoration(
                              hintText: '粘贴抖音视频链接...',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.content_paste_rounded, size: 20),
                                tooltip: '粘贴',
                                onPressed: () async {
                                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                                  if (data?.text != null) {
                                    _controller.text = data!.text!;
                                  }
                                },
                              ),
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
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _featurePill(context, Icons.devices_rounded, '多端支持', Colors.blue),
                      _featurePill(context, Icons.high_quality_rounded, '无水印高清', Colors.purple),
                      _featurePill(context, Icons.bolt_rounded, '极速解析', Colors.orange),
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
            SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1.0,
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: video != null
                    ? Padding(
                        key: ValueKey(video.awemeId),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: _VideoDetailCard(
                          video: video,
                          progress: provider.progress,
                          onDownload: () => _showDownloadOptions(video),
                          isDownloading: _downloading,
                        ),
                      )
                    : const SizedBox.shrink(),
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
                    child: _HistoryCard(
                      video: item,
                      onDelete: () => _deleteHistoryItem(item),
                    ),
                  );
                },
                childCount: _history.items.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
    ];

    return RepaintBoundary(
      key: _repaintKey,
      child: Scaffold(
        body: kIsWeb
            ? WebSmoothScroll(
                controller: _scrollController,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const NeverScrollableScrollPhysics(),
                  slivers: slivers,
                ),
              )
            : CustomScrollView(
                controller: _scrollController,
                slivers: slivers,
              ),
      ),
    );
  }

  Widget _featurePill(BuildContext context, IconData icon, String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerColor = isDark ? color.withOpacity(0.2) : color.withOpacity(0.1);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
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
    final primaryColor = Theme.of(context).colorScheme.primary;

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
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    height: 24,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            '正在下载 $progress%',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: progress / 100),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            builder: (context, value, child) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: value,
                                child: child,
                              );
                            },
                            child: Container(
                              width: constraints.maxWidth,
                              height: 24,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    primaryColor.withOpacity(0.7),
                                    primaryColor,
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '正在下载 $progress%',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
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
  final VoidCallback? onDelete;

  const _HistoryCard({required this.video, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                onPressed: onDelete,
                tooltip: '删除',
              ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
        onTap: () {
          final provider = context.read<VideoProvider>();
          if (provider.loading) {
            Fluttertoast.showToast(msg: "正在解析中，请稍候...");
            return;
          }
          final authToken = context.read<AuthProvider>().token;
          provider.parse(video.awemeId, token: authToken);
        },
      ),
    );
  }
}

class _ThemeTransitionOverlay extends StatefulWidget {
  final ui.Image image;
  final Offset center;
  final bool isDarkToLight;
  final VoidCallback onFinished;

  const _ThemeTransitionOverlay({
    required this.image,
    required this.center,
    required this.isDarkToLight,
    required this.onFinished,
  });

  @override
  State<_ThemeTransitionOverlay> createState() => _ThemeTransitionOverlayState();
}

class _ThemeTransitionOverlayState extends State<_ThemeTransitionOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    
    _controller.forward().then((_) {
      widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ClipPath(
          clipper: _CircularRevealClipper(
            fraction: _animation.value,
            center: widget.center,
            isDarkToLight: widget.isDarkToLight,
          ),
          child: RawImage(
            image: widget.image,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}

class _CircularRevealClipper extends CustomClipper<Path> {
  final double fraction;
  final Offset center;
  final bool isDarkToLight;

  _CircularRevealClipper({
    required this.fraction,
    required this.center,
    required this.isDarkToLight,
  });

  @override
  Path getClip(Size size) {
    final Path path = Path();
    final double maxRadius = size.longestSide * 1.5;
    
    if (isDarkToLight) {
      // Dark -> Light: Shrink Old (Overlay) to center
      final double radius = maxRadius * (1.0 - fraction);
      path.addOval(Rect.fromCircle(center: center, radius: radius));
    } else {
      // Light -> Dark: Expand New (Underlying) from center (Hole in Overlay)
      final double radius = maxRadius * fraction;
      path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      path.addOval(Rect.fromCircle(center: center, radius: radius));
      path.fillType = PathFillType.evenOdd;
    }
    
    return path;
  }

  @override
  bool shouldReclip(_CircularRevealClipper oldClipper) {
    return oldClipper.fraction != fraction || oldClipper.isDarkToLight != isDarkToLight;
  }
}
