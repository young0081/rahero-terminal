import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glitch_loader.dart';
import '../achievements/achievement_trigger.dart';
import '../profile/collection_data.dart';
import 'voice_player.dart';
import 'wiki_categories.dart';
import 'wiki_models.dart';
import 'wiki_providers.dart';

/// 图鉴视图：共鸣者 / 武器 / 声骸三类，网格展示真实图与名，点开看详情。
/// 数据来自库街区 wiki（实时拉取 + 本地缓存），失败时占位降级。
class WikiCodexView extends ConsumerStatefulWidget {
  const WikiCodexView({super.key});

  @override
  ConsumerState<WikiCodexView> createState() => _WikiCodexViewState();
}

class _WikiCodexViewState extends ConsumerState<WikiCodexView> {
  WikiCategory _category = WikiCategory.resonator;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _selectorBar(),
        Expanded(child: _CategoryGrid(category: _category)),
      ],
    );
  }

  Widget _selectorBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.gapMd,
        AppDimens.gapMd,
        AppDimens.gapMd,
        0,
      ),
      child: Row(
        children: [
          for (final c in WikiCategory.values)
            Padding(
              padding: const EdgeInsets.only(right: AppDimens.gapSm),
              child: ChoiceChip(
                label: Text(c.displayName),
                selected: _category == c,
                onSelected: (_) => setState(() => _category = c),
                selectedColor: AppColors.coolGlow,
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(
                  color: _category == c
                      ? AppColors.coolAccent
                      : AppColors.textMuted,
                ),
              ),
            ),
          const Spacer(),
          IconButton(
            tooltip: '刷新图鉴',
            icon: const Icon(Icons.refresh, color: AppColors.steel),
            onPressed: () async {
              await ref.read(wikiRefreshProvider)();
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends ConsumerWidget {
  final WikiCategory category;
  const _CategoryGrid({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(wikiListProvider(category));
    return async.when(
      loading: () => const Center(child: GlitchLoader(size: 180)),
      error: (e, _) => _ErrorRetry(
        message: '图鉴加载失败',
        onRetry: () => ref.invalidate(wikiListProvider(category)),
      ),
      data: (result) {
        if (result.entries.isEmpty) {
          return _ErrorRetry(
            message: result.error != null ? '加载失败，请检查网络' : '暂无内容',
            onRetry: () => ref.invalidate(wikiListProvider(category)),
          );
        }
        final cols = Responsive.value<int>(
          context,
          mobile: 3,
          tablet: 4,
          desktop: 6,
        );
        return Column(
          children: [
            if (result.stale)
              const Padding(
                padding: EdgeInsets.all(AppDimens.gapXs),
                child: Text(
                  '离线缓存，可能非最新',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(AppDimens.gapMd),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: AppDimens.gapMd,
                  crossAxisSpacing: AppDimens.gapMd,
                  childAspectRatio: 0.72,
                ),
                itemCount: result.entries.length,
                itemBuilder: (context, i) =>
                    _WikiCard(entry: result.entries[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: AppDimens.gapSm),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

class _WikiCard extends ConsumerWidget {
  final WikiEntry entry;
  const _WikiCard({required this.entry});

  void _openDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceHigh,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _WikiDetailSheet(entry: entry),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final figure = ref.watch(wikiImageProvider(entry.figureUrl));
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      onTap: () => _openDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: figure.when(
                loading: () => const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, _) => const _FigurePlaceholder(),
                data: (path) => (path != null && File(path).existsSync())
                    ? Image.file(File(path), fit: BoxFit.contain)
                    : const _FigurePlaceholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: AppDimens.gapXs,
              ),
              child: Column(
                children: [
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.silver,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (entry.star > 0)
                    Text(
                      '★' * entry.star,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: const TextStyle(
                        color: AppColors.coolAccent,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FigurePlaceholder extends StatelessWidget {
  const _FigurePlaceholder();
  @override
  Widget build(BuildContext context) => const Center(
    child: Icon(
      Icons.image_not_supported_outlined,
      color: AppColors.textMuted,
      size: 28,
    ),
  );
}

class _WikiDetailSheet extends ConsumerStatefulWidget {
  final WikiEntry entry;
  const _WikiDetailSheet({required this.entry});

  @override
  ConsumerState<_WikiDetailSheet> createState() => _WikiDetailSheetState();
}

class _WikiDetailSheetState extends ConsumerState<_WikiDetailSheet> {
  @override
  void initState() {
    super.initState();
    // 打开详情即记录为"已浏览"（用于个人页使用统计）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = collectionKey(
        widget.entry.category.name,
        widget.entry.entryId,
      );
      ref.read(collectionProvider.notifier).markViewed(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final figure = ref.watch(wikiImageProvider(entry.figureUrl));
    final detail = ref.watch(wikiDetailProvider(entry));
    final favKey = collectionKey(entry.category.name, entry.entryId);
    final isFav = ref.watch(collectionProvider).isFavorite(favKey);
    return SizedBox(
      width: double.infinity,
      height: MediaQuery.sizeOf(context).height * 0.92,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.gapLg,
          0,
          AppDimens.gapLg,
          AppDimens.gapXl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppDimens.gapMd),
            Center(
              child: SizedBox(
                height: 200,
                child: figure.maybeWhen(
                  data: (path) => (path != null && File(path).existsSync())
                      ? Image.file(File(path), fit: BoxFit.contain)
                      : const _FigurePlaceholder(),
                  orElse: () => const _FigurePlaceholder(),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.gapMd),
            Row(
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(
                    color: AppColors.coolAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppDimens.gapSm),
                if (entry.star > 0)
                  Text(
                    '★' * entry.star,
                    style: const TextStyle(
                      color: AppColors.coolAccent,
                      fontSize: 14,
                    ),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: isFav ? '取消收藏' : '收藏',
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? AppColors.danger : AppColors.steel,
                  ),
                  onPressed: () async {
                    final added = await ref
                        .read(collectionProvider.notifier)
                        .toggleFavorite(
                          favKey,
                          item: CollectionItem(
                            key: favKey,
                            category: entry.category.name,
                            categoryLabel: entry.category.displayName,
                            entryId: entry.entryId,
                            name: entry.name,
                            star: entry.star,
                            figureUrl: entry.figureUrl,
                            addedAt: DateTime.now(),
                          ),
                        );
                    if (added && context.mounted) {
                      await AchievementTrigger(
                        ref,
                        context: context,
                      ).onFavoriteEntry();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: AppDimens.gapSm),
            detail.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimens.gapMd),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (_, _) => const Text(
                '详情加载失败',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              data: (d) {
                if (d == null) {
                  return const Text(
                    '暂无详情',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (d.imageUrls.isNotEmpty) ...[
                      _ImageGallery(urls: d.imageUrls),
                      const SizedBox(height: AppDimens.gapSm),
                    ],
                    for (final line in d.infoLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          line,
                          style: const TextStyle(
                            color: AppColors.steel,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    if (d.story.isNotEmpty) ...[
                      const SizedBox(height: AppDimens.gapSm),
                      Text(
                        d.story,
                        style: const TextStyle(
                          color: AppColors.silver,
                          fontSize: 14,
                          height: 1.7,
                        ),
                      ),
                    ],
                    for (final sec in d.sections) ...[
                      const SizedBox(height: AppDimens.gapMd),
                      if (sec.title.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            sec.title,
                            style: const TextStyle(
                              color: AppColors.coolAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      for (final block in sec.blocks)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: block.isImage
                              ? _BlockImage(url: block.imageUrl)
                              : block.isTable
                              ? _TableBlock(rows: block.rows)
                              : Text(
                                  block.text,
                                  style: const TextStyle(
                                    color: AppColors.silver,
                                    fontSize: 13,
                                    height: 1.6,
                                  ),
                                ),
                        ),
                    ],
                    if (d.voiceTabs.isNotEmpty) ...[
                      const SizedBox(height: AppDimens.gapMd),
                      _VoiceSection(tabs: d.voiceTabs),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 把结构化表格行列渲染成真正的表格。
///
/// - 各行列数对齐到最大列数（不足补空单元格）。
/// - 单元格含图标则在文字上方显示小图（按 URL 去重惰性下载）。
/// - 单元格文本上限宽度，长文本（技能/材料描述）自动换行而非撑爆。
/// - 整表外套横向滚动：列多的宽表（如 Lv1~Lv10）可左右滑动查看，永不溢出报错。
/// - 首行作表头：背景高亮、青柠强调色。
class _TableBlock extends StatelessWidget {
  final List<List<WikiCell>> rows;
  const _TableBlock({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final cols = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    if (cols == 0) return const SizedBox.shrink();

    WikiCell cellAt(int r, int c) =>
        c < rows[r].length ? rows[r][c] : const WikiCell('');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
        ),
        clipBehavior: Clip.antiAlias,
        child: Table(
          border: const TableBorder.symmetric(
            inside: BorderSide(color: AppColors.border, width: 0.5),
          ),
          defaultColumnWidth: const IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (var i = 0; i < rows.length; i++)
              TableRow(
                decoration: BoxDecoration(
                  color: i == 0 ? AppColors.surface : null,
                ),
                children: [
                  for (var c = 0; c < cols; c++)
                    _TableCell(cell: cellAt(i, c), header: i == 0),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 单个表格单元格：图标（若有）在上，文字在下；含链接则可点击跳转浏览器。
class _TableCell extends StatelessWidget {
  final WikiCell cell;
  final bool header;
  const _TableCell({required this.cell, required this.header});

  @override
  Widget build(BuildContext context) {
    final isLink = cell.isLink;
    Widget? textWidget;
    if (cell.text.isNotEmpty) {
      textWidget = Text(
        cell.text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isLink
              ? AppColors.coolAccent
              : (header ? AppColors.coolAccent : AppColors.silver),
          fontSize: 12,
          height: 1.4,
          fontWeight: header ? FontWeight.w600 : FontWeight.w400,
          decoration: isLink ? TextDecoration.underline : null,
          decorationColor: AppColors.coolAccent,
        ),
      );
      if (isLink) {
        textWidget = InkWell(
          onTap: () => openExternalUrl(cell.linkUrl),
          child: textWidget,
        );
      }
    }
    final useLargeImage = _isGifUrl(cell.imageUrl);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: useLargeImage ? 320 : 220),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (cell.imageUrl.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: cell.text.isEmpty ? 0 : 2),
                child: useLargeImage
                    ? _ZoomableCachedImage(
                        url: cell.imageUrl,
                        width: 300,
                        height: 220,
                      )
                    : _CachedImage(url: cell.imageUrl, width: 40, height: 40),
              ),
            ?textWidget,
          ],
        ),
      ),
    );
  }
}

/// 用系统默认浏览器打开外链。失败静默忽略（不崩）。
Future<void> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    /* 打开失败忽略 */
  }
}

/// 详情内嵌的整幅大图（技能演示图 / 剧情插画等）。
/// 铺满可用宽度显示（小图也放大到看得清），点击全屏查看原图。
class _BlockImage extends ConsumerWidget {
  final String url;
  const _BlockImage({required this.url});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(wikiImageProvider(url));
    return async.maybeWhen(
      data: (path) {
        if (path == null || !File(path).existsSync()) {
          return const SizedBox(height: 120, child: _FigurePlaceholder());
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final screen = MediaQuery.sizeOf(context);
            final baseHeight = Responsive.value<double>(
              context,
              mobile: 320,
              tablet: 420,
              desktop: 520,
            );
            final maxHeight = screen.height * 0.72;
            final height = baseHeight.clamp(280.0, maxHeight).toDouble();
            return _ZoomableFileImage(
              path: path,
              width: constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : double.infinity,
              height: height,
              borderRadius: AppDimens.radiusMedium,
            );
          },
        );
      },
      orElse: () => const SizedBox(
        height: 120,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

/// 全屏图片查看器：缩放/拖动，点击关闭。
class _FullScreenImage extends StatelessWidget {
  final String path;
  const _FullScreenImage({required this.path});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Image.file(File(path), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 角色立绘多图：横向滚动画廊。
class _ImageGallery extends ConsumerWidget {
  final List<String> urls;
  const _ImageGallery({required this.urls});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final height = Responsive.value<double>(
      context,
      mobile: 260,
      tablet: 320,
      desktop: 360,
    );
    final width =
        (MediaQuery.sizeOf(context).width -
                AppDimens.gapLg * 2 -
                AppDimens.gapSm)
            .clamp(300.0, 720.0)
            .toDouble();
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppDimens.gapSm),
        itemBuilder: (_, i) => _ZoomableCachedImage(
          url: urls[i],
          width: width,
          height: height,
          borderRadius: AppDimens.radiusSmall,
        ),
      ),
    );
  }
}

class _ZoomableCachedImage extends ConsumerWidget {
  final String url;
  final double? width;
  final double? height;
  final double borderRadius;

  const _ZoomableCachedImage({
    required this.url,
    this.width,
    this.height,
    this.borderRadius = AppDimens.radiusMedium,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(wikiImageProvider(url));
    return async.maybeWhen(
      data: (path) => (path != null && File(path).existsSync())
          ? _ZoomableFileImage(
              path: path,
              width: width,
              height: height,
              borderRadius: borderRadius,
            )
          : SizedBox(
              width: width,
              height: height,
              child: const _FigurePlaceholder(),
            ),
      orElse: () => SizedBox(
        width: width,
        height: height,
        child: const Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

class _ZoomableFileImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final double borderRadius;

  const _ZoomableFileImage({
    required this.path,
    this.width,
    this.height,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullScreenImage(context, path),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          width: width,
          height: height,
          color: Colors.black.withValues(alpha: 0.24),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.file(File(path), fit: BoxFit.contain),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.open_in_full,
                      color: AppColors.silver,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isGifUrl(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  return path.endsWith('.gif');
}

void _openFullScreenImage(BuildContext context, String path) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, _, _) => _FullScreenImage(path: path),
    ),
  );
}

/// 按 URL 惰性下载并缓存后显示的图片；加载中转圈，失败占位。
class _CachedImage extends ConsumerWidget {
  final String url;
  final double? width;
  final double? height;
  const _CachedImage({required this.url, this.width, this.height});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(wikiImageProvider(url));
    return async.maybeWhen(
      data: (path) => (path != null && File(path).existsSync())
          ? Image.file(
              File(path),
              width: width,
              height: height,
              fit: BoxFit.contain,
            )
          : SizedBox(
              width: width,
              height: height,
              child: const _FigurePlaceholder(),
            ),
      orElse: () => SizedBox(
        width: width,
        height: height,
        child: const Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

/// 角色语音区：按分类（台词/战斗等）分组，每条可点击播放，展开看台词文本。
class _VoiceSection extends ConsumerStatefulWidget {
  final List<WikiVoiceTab> tabs;
  const _VoiceSection({required this.tabs});

  @override
  ConsumerState<_VoiceSection> createState() => _VoiceSectionState();
}

class _VoiceSectionState extends ConsumerState<_VoiceSection> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = widget.tabs;
    final cur = tabs[_tab.clamp(0, tabs.length - 1)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.graphic_eq, color: AppColors.coolAccent, size: 18),
            const SizedBox(width: 6),
            const Text(
              '角色语音',
              style: TextStyle(
                color: AppColors.coolAccent,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.gapSm),
        // 分类切换
        if (tabs.length > 1)
          Wrap(
            spacing: AppDimens.gapSm,
            runSpacing: 4,
            children: [
              for (var i = 0; i < tabs.length; i++)
                ChoiceChip(
                  label: Text(tabs[i].title),
                  selected: _tab == i,
                  selectedColor: AppColors.coolGlow,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(
                    color: _tab == i
                        ? AppColors.coolAccent
                        : AppColors.textMuted,
                    fontSize: 12,
                  ),
                  onSelected: (_) => setState(() => _tab = i),
                ),
            ],
          ),
        const SizedBox(height: AppDimens.gapSm),
        for (final v in cur.voices) _VoiceTile(voice: v),
      ],
    );
  }
}

/// 单条语音：播放/停止按钮 + 标题 + 台词文本（可换行）。
class _VoiceTile extends ConsumerWidget {
  final WikiVoice voice;
  const _VoiceTile({required this.voice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(voicePlayerProvider);
    final isPlaying = playerState.playingUrl == voice.url;
    final isLoading = isPlaying && playerState.loading;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.gapSm),
      padding: const EdgeInsets.all(AppDimens.gapSm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        border: Border.all(
          color: isPlaying ? AppColors.coolAccent : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isPlaying ? Icons.stop_circle : Icons.play_circle,
                    color: AppColors.coolAccent,
                    size: 28,
                  ),
            onPressed: () =>
                ref.read(voicePlayerProvider.notifier).toggle(voice.url),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    voice.title,
                    style: const TextStyle(
                      color: AppColors.silver,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (voice.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      voice.text,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
