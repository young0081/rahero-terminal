import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../codex/wiki_categories.dart';
import '../codex/wiki_codex_service.dart';
import '../feixun/feixun_data.dart';

/// 搜索结果类型
enum SearchResultType {
  resonator, // 共鸣者
  weapon, // 武器
  echo, // 声骸
  message, // 飞讯消息
  faction, // 势力
}

/// 搜索结果项
class SearchResult {
  final SearchResultType type;
  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;

  const SearchResult({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle = '',
    this.imageUrl,
  });
}

/// 全局搜索服务
class GlobalSearchService {
  GlobalSearchService._();
  static final GlobalSearchService instance = GlobalSearchService._();

  /// 执行搜索，返回匹配的结果列表
  Future<List<SearchResult>> search(String query, WidgetRef ref) async {
    if (query.trim().isEmpty) return [];

    final results = <SearchResult>[];
    final lowerQuery = query.toLowerCase();

    // 搜索图鉴（共鸣者）
    try {
      final resonators = await WikiCodexService.instance.fetchList(WikiCategory.resonator);
      for (final entry in resonators.entries) {
        if (_matches(entry.name, lowerQuery)) {
          results.add(SearchResult(
            type: SearchResultType.resonator,
            id: entry.id,
            title: entry.name,
            subtitle: '共鸣者',
            imageUrl: entry.figureUrl,
          ));
        }
      }
    } catch (_) {
      // 图鉴未就绪，跳过
    }

    // 搜索图鉴（武器）
    try {
      final weapons = await WikiCodexService.instance.fetchList(WikiCategory.weapon);
      for (final entry in weapons.entries) {
        if (_matches(entry.name, lowerQuery)) {
          results.add(SearchResult(
            type: SearchResultType.weapon,
            id: entry.id,
            title: entry.name,
            subtitle: '武器',
            imageUrl: entry.figureUrl,
          ));
        }
      }
    } catch (_) {
      // 跳过
    }

    // 搜索图鉴（声骸）
    try {
      final echoes = await WikiCodexService.instance.fetchList(WikiCategory.echo);
      for (final entry in echoes.entries) {
        if (_matches(entry.name, lowerQuery)) {
          results.add(SearchResult(
            type: SearchResultType.echo,
            id: entry.id,
            title: entry.name,
            subtitle: '声骸',
            imageUrl: entry.figureUrl,
          ));
        }
      }
    } catch (_) {
      // 跳过
    }

    // 搜索飞讯消息
    try {
      final contacts = await ref.read(feixunContactsProvider.future);
      for (final contact in contacts) {
        for (final msg in contact.messages) {
          if (msg.type == 'text' && _matches(msg.content, lowerQuery)) {
            results.add(SearchResult(
              type: SearchResultType.message,
              id: '${contact.id}_${msg.id}',
              title: msg.content.length > 30
                  ? '${msg.content.substring(0, 30)}...'
                  : msg.content,
              subtitle: '来自 ${contact.name} - ${msg.time}',
            ));
            if (results.where((r) => r.type == SearchResultType.message).length >= 10) {
              break; // 限制飞讯搜索结果数量
            }
          }
        }
      }
    } catch (_) {
      // 飞讯数据加载失败，跳过
    }

    return results;
  }

  bool _matches(String text, String query) {
    return text.toLowerCase().contains(query);
  }
}

/// 全局搜索界面
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _controller = TextEditingController();
  List<SearchResult> _results = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final results = await GlobalSearchService.instance.search(query, ref);

    if (mounted) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.silver, fontSize: 16),
          decoration: const InputDecoration(
            hintText: '搜索角色、武器、声骸、飞讯消息...',
            hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (value) {
            // 防抖：延迟搜索
            Future.delayed(const Duration(milliseconds: 300), () {
              if (_controller.text == value) {
                _performSearch(value);
              }
            });
          },
          onSubmitted: _performSearch,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                setState(() {
                  _results = [];
                });
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.coolAccent),
      );
    }

    if (_controller.text.trim().isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: AppColors.border),
            SizedBox(height: AppDimens.gapMd),
            Text(
              '输入关键词开始搜索',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.border),
            SizedBox(height: AppDimens.gapMd),
            Text(
              '没有找到相关结果',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimens.gapMd),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(
        color: AppColors.border,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final result = _results[index];
        return _SearchResultTile(result: result);
      },
    );
  }
}

/// 搜索结果条目
class _SearchResultTile extends StatelessWidget {
  final SearchResult result;

  const _SearchResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimens.gapMd,
        vertical: AppDimens.gapSm,
      ),
      leading: _buildLeading(),
      title: Text(
        result.title,
        style: const TextStyle(
          color: AppColors.silver,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: result.subtitle.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                result.subtitle,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            )
          : null,
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: AppColors.steel,
        size: 16,
      ),
      onTap: () => _handleTap(context),
    );
  }

  Widget _buildLeading() {
    if (result.imageUrl != null && result.imageUrl!.isNotEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
          child: Image.network(
            result.imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildTypeIcon(),
          ),
        ),
      );
    }
    return _buildTypeIcon();
  }

  Widget _buildTypeIcon() {
    IconData icon;
    Color color;

    switch (result.type) {
      case SearchResultType.resonator:
        icon = Icons.person;
        color = AppColors.coolAccent;
        break;
      case SearchResultType.weapon:
        icon = Icons.flash_on;
        color = AppColors.steel;
        break;
      case SearchResultType.echo:
        icon = Icons.pets;
        color = AppColors.xingjuGreen;
        break;
      case SearchResultType.message:
        icon = Icons.message;
        color = AppColors.blue;
        break;
      case SearchResultType.faction:
        icon = Icons.shield;
        color = AppColors.shenkongRed;
        break;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  void _handleTap(BuildContext context) {
    // TODO: 根据类型跳转到对应详情页
    // 这里需要集成导航逻辑，暂时只关闭搜索
    Navigator.of(context).pop();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('即将打开：${result.title}'),
        backgroundColor: AppColors.surfaceHigh,
      ),
    );
  }
}
