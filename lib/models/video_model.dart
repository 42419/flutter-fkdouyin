class DownloadOption {
  final String url;
  final String quality;
  final String resolution;
  final int size;
  final int frameRate;
  final String format;

  DownloadOption({
    required this.url,
    required this.quality,
    required this.resolution,
    required this.size,
    required this.frameRate,
    required this.format,
  });
}

class VideoStatistics {
  final int diggCount;
  final int commentCount;
  final int collectCount;
  final int shareCount;

  VideoStatistics({
    this.diggCount = 0,
    this.commentCount = 0,
    this.collectCount = 0,
    this.shareCount = 0,
  });

  factory VideoStatistics.fromJson(Map<String, dynamic> json) {
    return VideoStatistics(
      diggCount: json['digg_count'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
      collectCount: json['collect_count'] ?? 0,
      shareCount: json['share_count'] ?? 0,
    );
  }
}

class VideoModel {
  final String awemeId;
  final String? title;
  final String? author;
  final String? authorAvatar;
  final String? authorSignature;
  final int followerCount;
  final int totalFavorited;
  final String? coverUrl;
  final String? playUrl; // Keep for backward compatibility, use downloadOptions[0].url if available
  final int? durationMs;
  final int? createTime;
  final VideoStatistics statistics;
  final List<DownloadOption> downloadOptions;

  VideoModel({
    required this.awemeId,
    this.title,
    this.author,
    this.authorAvatar,
    this.authorSignature,
    this.followerCount = 0,
    this.totalFavorited = 0,
    this.coverUrl,
    this.playUrl,
    this.durationMs,
    this.createTime,
    required this.statistics,
    required this.downloadOptions,
  });

  factory VideoModel.fromApi(Map<String, dynamic> json) {
    // 1. 验证数据
    if (json['code'] != 0 && json['code'] != 200) {
      throw Exception('API Error: ${json['message'] ?? 'Unknown error'}');
    }

    final data = json['data'] ?? {};
    Map<String, dynamic> videoDetail = {};

    // 2. 提取视频详情 (Logic from video-display.js)
    if (data['aweme_detail'] != null) {
      videoDetail = data['aweme_detail'];
    } else if (data['video'] != null && data['author'] != null) {
      videoDetail = data;
    } else {
      videoDetail = data;
    }

    if (videoDetail.isEmpty) {
      throw Exception('Empty video detail');
    }

    // 3. 提取作者信息
    final authorInfo = videoDetail['author'] ?? {};
    final avatarUrl = (authorInfo['avatar_thumb']?['url_list'] as List?)?.firstOrNull?.toString();
    
    // 4. 提取统计数据
    final stats = VideoStatistics.fromJson(videoDetail['statistics'] ?? {});

    // 5. 生成下载选项
    final options = _generateDownloadOptions(videoDetail);

    // 6. 提取封面
    String? cover;
    final videoObj = videoDetail['video'] ?? {};
    if (videoObj['cover'] != null && videoObj['cover']['url_list'] != null) {
       cover = (videoObj['cover']['url_list'] as List?)?.firstOrNull?.toString();
    } else if (videoObj['origin_cover'] != null && videoObj['origin_cover']['url_list'] != null) {
       cover = (videoObj['origin_cover']['url_list'] as List?)?.firstOrNull?.toString();
    }

    return VideoModel(
      awemeId: (videoDetail['aweme_id'] ?? videoDetail['id'] ?? '').toString(),
      title: videoDetail['desc']?.toString(),
      author: authorInfo['nickname']?.toString(),
      authorAvatar: avatarUrl,
      authorSignature: authorInfo['signature']?.toString(),
      followerCount: authorInfo['follower_count'] ?? 0,
      totalFavorited: authorInfo['total_favorited'] ?? 0,
      coverUrl: cover,
      playUrl: options.isNotEmpty ? options.first.url : null,
      durationMs: videoDetail['duration'] is int ? videoDetail['duration'] : null,
      createTime: videoDetail['create_time'] is int ? videoDetail['create_time'] : null,
      statistics: stats,
      downloadOptions: options,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'aweme_id': awemeId,
      'title': title,
      'author': author,
      'author_avatar': authorAvatar,
      'author_signature': authorSignature,
      'follower_count': followerCount,
      'total_favorited': totalFavorited,
      'cover_url': coverUrl,
      'play_url': playUrl,
      'duration_ms': durationMs,
      'create_time': createTime,
      'statistics': {
        'digg_count': statistics.diggCount,
        'comment_count': statistics.commentCount,
        'collect_count': statistics.collectCount,
        'share_count': statistics.shareCount,
      },
      'download_options': downloadOptions.map((e) => {
        'url': e.url,
        'quality': e.quality,
        'resolution': e.resolution,
        'size': e.size,
        'frame_rate': e.frameRate,
        'format': e.format,
      }).toList(),
    };
  }

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    final statsJson = json['statistics'] as Map<String, dynamic>? ?? {};
    final optionsJson = (json['download_options'] as List?) ?? [];

    List<DownloadOption> options = [];
    for (var o in optionsJson) {
      options.add(DownloadOption(
        url: o['url'],
        quality: o['quality'],
        resolution: o['resolution'],
        size: o['size'],
        frameRate: o['frame_rate'],
        format: o['format'],
      ));
    }
    
    if (options.isEmpty && json['play_url'] != null) {
        options.add(DownloadOption(
            url: json['play_url'],
            quality: 'Unknown',
            resolution: 'Unknown',
            size: 0,
            frameRate: 30,
            format: 'mp4'
        ));
    }

    return VideoModel(
      awemeId: json['aweme_id'] ?? '',
      title: json['title'],
      author: json['author'],
      authorAvatar: json['author_avatar'],
      authorSignature: json['author_signature'],
      followerCount: json['follower_count'] ?? 0,
      totalFavorited: json['total_favorited'] ?? 0,
      coverUrl: json['cover_url'],
      playUrl: json['play_url'],
      durationMs: json['duration_ms'],
      createTime: json['create_time'],
      statistics: VideoStatistics(
        diggCount: statsJson['digg_count'] ?? 0,
        commentCount: statsJson['comment_count'] ?? 0,
        collectCount: statsJson['collect_count'] ?? 0,
        shareCount: statsJson['share_count'] ?? 0,
      ),
      downloadOptions: options,
    );
  }

  static List<DownloadOption> _generateDownloadOptions(Map<String, dynamic> videoDetail) {
    List<DownloadOption> options = [];
    List<dynamic> bitRates = [];
    Map<String, dynamic> videoInfo = videoDetail;
    int videoFPS = 30;

    // Extract bit_rate and video info
    if (videoDetail['video'] != null && videoDetail['video']['bit_rate'] is List) {
      bitRates = videoDetail['video']['bit_rate'];
      videoInfo = videoDetail['video'];
      videoFPS = videoInfo['fps'] ?? 30;
    } else if (videoDetail['bit_rate'] is List) {
      bitRates = videoDetail['bit_rate'];
      videoFPS = videoDetail['fps'] ?? 30;
    }

    // Check video_list
    if (bitRates.isEmpty && videoDetail['video_list'] is List) {
      for (var v in videoDetail['video_list']) {
        if (v['bit_rate'] is List) {
          bitRates.addAll(v['bit_rate']);
        }
      }
    }

    // Extract video_id
    String? videoId;
    if (videoDetail['video'] != null) {
      videoId = videoDetail['video']['video_id']?.toString();
      if (videoId == null && videoDetail['video']['play_addr'] != null) {
        videoId = videoDetail['video']['play_addr']['uri']?.toString();
      }
    }
    if (videoId == null) {
      videoId = videoDetail['video_id']?.toString();
      if (videoId == null && videoDetail['play_addr'] != null) {
        videoId = videoDetail['play_addr']['uri']?.toString();
      }
    }

    // 1. Process bit_rates
    if (bitRates.isNotEmpty) {
      for (var bitRate in bitRates) {
        final playAddr = bitRate['play_addr'];
        if (playAddr != null && playAddr['url_list'] is List) {
          final urlList = playAddr['url_list'] as List;
          final height = playAddr['height'] ?? 0;
          final width = playAddr['width'] ?? 0;
          final fps = bitRate['FPS'] ?? bitRate['fps'] ?? videoFPS;

          String? priorityUrl;
          // Find douyin url
          try {
            priorityUrl = urlList.firstWhere((url) => url.toString().startsWith("https://www.douyin.com"));
          } catch (_) {}

          if (priorityUrl == null && urlList.isNotEmpty) {
            priorityUrl = _convertToDouyinUrl(urlList.first.toString(), videoId);
          }

          if (priorityUrl != null) {
            options.add(DownloadOption(
              url: priorityUrl,
              quality: _getResolutionTag(height, width),
              resolution: '${width}x$height',
              size: playAddr['data_size'] ?? bitRate['size'] ?? 0,
              frameRate: fps,
              format: bitRate['format'] ?? 'mp4',
            ));
          }
        }
      }
    }

    // 2. Fallback
    if (options.isEmpty) {
      bool tryAdd(Map<String, dynamic>? source, String qualityLabel) {
        if (source == null || source['url_list'] is! List || (source['url_list'] as List).isEmpty) return false;
        
        final urlList = source['url_list'] as List;
        final priorityUrl = _convertToDouyinUrl(urlList.first.toString(), videoId);
        
        final width = source['width'] ?? videoDetail['width'] ?? videoDetail['video']?['width'] ?? 0;
        final height = source['height'] ?? videoDetail['height'] ?? videoDetail['video']?['height'] ?? 0;
        
        options.add(DownloadOption(
          url: priorityUrl,
          quality: qualityLabel,
          resolution: '${width}x$height',
          size: source['data_size'] ?? 0,
          frameRate: _extractFrameRate(videoDetail) ?? 30,
          format: 'mp4',
        ));
        return true;
      }

      if (videoDetail['video'] != null) {
        if (tryAdd(videoDetail['video']['download_addr'], '无水印')) return options;
      }
      if (tryAdd(videoDetail['download_addr'], '无水印')) return options;
      if (videoDetail['video'] != null) {
        if (tryAdd(videoDetail['video']['play_addr'], '原画')) return options;
      }
      tryAdd(videoDetail['play_addr'], '原画');
    }

    // Sort and deduplicate
    options.sort((a, b) {
      final aH = int.tryParse(a.resolution.split('x').last) ?? 0;
      final bH = int.tryParse(b.resolution.split('x').last) ?? 0;
      if (aH != bH) return bH - aH;
      return b.frameRate - a.frameRate;
    });

    final uniqueOptions = <DownloadOption>[];
    final urls = <String>{};
    for (var opt in options) {
      if (!urls.contains(opt.url)) {
        urls.add(opt.url);
        uniqueOptions.add(opt);
      }
    }

    return uniqueOptions;
  }

  static String _getResolutionTag(int height, int width) {
    if (width == 0) return '${height}p';
    final longSide = height > width ? height : width;
    if (longSide >= 3840) return "4K";
    if (longSide >= 2560) return "2K";
    if (longSide >= 1920) return "1080p";
    if (longSide >= 1280) return "720p";
    if (longSide >= 854) return "480p";
    return '${longSide}p';
  }

  static int? _extractFrameRate(Map<String, dynamic> metadata) {
    if (metadata['fps'] != null) return metadata['fps'];
    if (metadata['frame_rate'] != null) return metadata['frame_rate'];
    if (metadata['video'] != null) {
      if (metadata['video']['fps'] != null) return metadata['video']['fps'];
      if (metadata['video']['frame_rate'] != null) return metadata['video']['frame_rate'];
    }
    if (metadata['duration'] != null && metadata['total_frames'] != null) {
      return (metadata['total_frames'] / (metadata['duration'] / 1000)).round();
    }
    return null;
  }

  static String _convertToDouyinUrl(String url, String? videoId) {
    try {
      final uri = Uri.parse(url);
      String? videoIdParam = uri.queryParameters['video_id'];

      if (videoIdParam == null && videoId != null) {
        videoIdParam = videoId;
      } else if (videoIdParam == null) {
        // Try to extract from path
        final pathParts = uri.pathSegments;
        for (final part in pathParts) {
          if (RegExp(r'^\d{18,19}$').hasMatch(part)) {
            videoIdParam = part;
            break;
          }
        }
      }

      final fileId = uri.queryParameters['file_id'];
      final sign = uri.queryParameters['sign'];
      final ts = uri.queryParameters['ts'] ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

      if (videoIdParam != null) {
        final newUri = Uri.parse('https://www.douyin.com/aweme/v1/play/').replace(queryParameters: {
          'video_id': videoIdParam,
          if (fileId != null) 'file_id': fileId,
          if (sign != null) 'sign': sign,
          'ts': ts,
          'is_play_url': '1',
          'source': 'PackSourceEnum_AWEME_DETAIL',
        });
        return newUri.toString();
      }
      
      return 'https://www.douyin.com/aweme/v1/play/?video_id=default&ts=${DateTime.now().millisecondsSinceEpoch ~/ 1000}&is_play_url=1&source=PackSourceEnum_AWEME_DETAIL';

    } catch (e) {
       return 'https://www.douyin.com/aweme/v1/play/?video_id=error&ts=${DateTime.now().millisecondsSinceEpoch ~/ 1000}&is_play_url=1&source=PackSourceEnum_AWEME_DETAIL';
    }
  }
}

