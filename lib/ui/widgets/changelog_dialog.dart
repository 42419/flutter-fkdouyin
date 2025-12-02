import 'package:flutter/material.dart';
import '../../services/update_service.dart';

class ChangelogDialog extends StatefulWidget {
  const ChangelogDialog({super.key});

  @override
  State<ChangelogDialog> createState() => _ChangelogDialogState();
}

class _ChangelogDialogState extends State<ChangelogDialog> {
  List<Map<String, dynamic>> _changelogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReleases();
  }

  Future<void> _loadReleases() async {
    try {
      final releases = await UpdateService().getReleases();
      final parsedReleases = releases.map((release) {
        final body = release['body'] as String? ?? '';
        final changes = <Map<String, String>>[];
        
        // Simple parsing logic
        final lines = body.split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          
          // Check for bullet points
          if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
            final content = trimmed.substring(2).trim();
            String type = 'other';
            
            if (content.toLowerCase().contains('feat') || content.contains('新增')) {
              type = 'feat';
            } else if (content.toLowerCase().contains('fix') || content.contains('修复')) {
              type = 'fix';
            } else if (content.toLowerCase().contains('optimize') || content.toLowerCase().contains('perf') || content.contains('优化')) {
              type = 'optimize';
            }
            
            changes.add({
              'type': type,
              'content': content,
            });
          }
        }

        // If no structured changes found, just add the whole body as one item if not empty
        if (changes.isEmpty && body.isNotEmpty) {
           changes.add({
             'type': 'other',
             'content': body,
           });
        }

        return {
          'version': release['tag_name'] ?? 'Unknown',
          'date': (release['published_at'] as String?)?.split('T')[0] ?? '',
          'expanded': false,
          'changes': changes,
        };
      }).toList();

      if (parsedReleases.isNotEmpty) {
        parsedReleases[0]['expanded'] = true;
      }

      if (mounted) {
        setState(() {
          _changelogs = parsedReleases;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '更新日志',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : _changelogs.isEmpty 
                      ? Center(child: Text('暂无更新日志', style: TextStyle(color: theme.textTheme.bodyMedium?.color)))
                      : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _changelogs.length,
                itemBuilder: (context, index) {
                  final item = _changelogs[index];
                  final isExpanded = item['expanded'] as bool;
                  
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isExpanded 
                          ? theme.colorScheme.primary.withOpacity(0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isExpanded 
                            ? theme.colorScheme.primary.withOpacity(0.1)
                            : theme.dividerColor.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              item['expanded'] = !isExpanded;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Text(
                                  item['version'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isExpanded 
                                        ? theme.colorScheme.primary 
                                        : theme.textTheme.bodyLarge?.color?.withOpacity(0.8),
                                  ),
                                ),
                                const Spacer(),
                                AnimatedRotation(
                                  turns: isExpanded ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 300),
                                  child: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: isExpanded 
                                        ? theme.colorScheme.primary 
                                        : theme.iconTheme.color?.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: isExpanded
                              ? Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Column(
                                    children: (item['changes'] as List).map<Widget>((change) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: _buildChangeIcon(change['type'], theme),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                change['content'],
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  height: 1.5,
                                                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(24),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  '关闭',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangeIcon(String type, ThemeData theme) {
    IconData icon;
    Color color;

    switch (type) {
      case 'feat':
        icon = Icons.add_circle_rounded;
        color = theme.colorScheme.primary;
        break;
      case 'fix':
        icon = Icons.handyman_rounded;
        color = theme.colorScheme.error;
        break;
      case 'optimize':
        icon = Icons.auto_fix_high_rounded;
        color = theme.colorScheme.secondary;
        break;
      default:
        icon = Icons.circle_outlined;
        color = theme.disabledColor;
    }

    return Icon(
      icon,
      size: 16,
      color: color,
    );
  }
}
