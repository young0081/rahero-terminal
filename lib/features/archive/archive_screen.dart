import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/dynamic_icon_view.dart';
import '../../core/widgets/logo_animation_view.dart';
import '../codex/wiki_codex_view.dart';
import 'faction_service.dart';

/// 档案页：顶部切换「势力」与「图鉴」。
class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  int _tab = 0; // 0=势力 1=图鉴

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppDimens.gapMd, AppDimens.gapMd, AppDimens.gapMd, 0),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('势力'), icon: Icon(Icons.hub)),
              ButtonSegment(
                  value: 1, label: Text('图鉴'), icon: Icon(Icons.menu_book)),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        Expanded(
          child: _tab == 0 ? const _FactionArchive() : const WikiCodexView(),
        ),
      ],
    );
  }
}

/// 势力档案：本地 + 在线自动发现的势力。
class _FactionArchive extends ConsumerWidget {
  const _FactionArchive();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(factionListProvider);
    
    return resultAsync.when(
      data: (result) {
        if (result.entries.isEmpty) {
          return const Center(
            child: Text(
              '暂无势力数据',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }
        
        final cols = Responsive.value<int>(
          context,
          mobile: 2,
          tablet: 3,
          desktop: 4,
        );
        
        return Column(
          children: [
            if (result.error != null)
              Container(
                margin: const EdgeInsets.all(AppDimens.gapMd),
                padding: const EdgeInsets.all(AppDimens.gapSm),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.steel,
                      size: 16,
                    ),
                    const SizedBox(width: AppDimens.gapSm),
                    Expanded(
                      child: Text(
                        result.error!,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(AppDimens.gapMd),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: AppDimens.gapMd,
                  crossAxisSpacing: AppDimens.gapMd,
                  childAspectRatio: 0.82,
                ),
                itemCount: result.entries.length,
                itemBuilder: (context, i) => _FactionCard(
                  entry: result.entries[i],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.coolAccent),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.gapLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.danger,
                size: 48,
              ),
              const SizedBox(height: AppDimens.gapMd),
              Text(
                '加载失败：$err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 势力卡片。
class _FactionCard extends StatelessWidget {
  final FactionEntry entry;
  const _FactionCard({required this.entry});

  void _openDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FactionDetailSheet(entry: entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openDetail(context),
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            // 图标区域：固定比例，避免裁剪
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimens.gapMd),
                child: entry.hasLocalAsset
                    ? Center(
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: DynamicIconView(
                            assetId: entry.assetId,
                            label: entry.name,
                            size: 96,
                            preferStill: true,
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.shield_outlined,
                          size: 64,
                          color: AppColors.steel.withValues(alpha: 0.5),
                        ),
                      ),
              ),
            ),
            // 名称标签
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.gapSm,
                vertical: AppDimens.gapSm,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppDimens.radiusMedium),
                ),
              ),
              child: Text(
                entry.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.silver,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 势力详情弹窗。
class _FactionDetailSheet extends ConsumerWidget {
  final FactionEntry entry;
  const _FactionDetailSheet({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(factionDetailProvider(entry.name));
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
      decoration: const BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusLarge)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖动指示器
          Container(
            margin: const EdgeInsets.symmetric(vertical: AppDimens.gapMd),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // LOGO 动画
          if (entry.hasLocalAsset)
            SizedBox(
              height: 180,
              child: LogoAnimationView(
                assetId: entry.assetId,
                label: entry.name,
                size: 180,
              ),
            )
          else
            Container(
              height: 120,
              alignment: Alignment.center,
              child: Icon(
                Icons.shield,
                size: 80,
                color: AppColors.steel.withValues(alpha: 0.3),
              ),
            ),

          const SizedBox(height: AppDimens.gapMd),

          // 名称
          Text(
            entry.name,
            style: const TextStyle(
              color: AppColors.silver,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimens.gapLg),

          // 简介内容
          Expanded(
            child: detailAsync.when(
              data: (detail) {
                if (detail == null) {
                  return const Padding(
                    padding: EdgeInsets.all(AppDimens.gapLg),
                    child: Center(
                      child: Text(
                        '暂无官方简介\n\n该势力的详细资料正在整理中',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.gapLg,
                    0,
                    AppDimens.gapLg,
                    AppDimens.gapLg,
                  ),
                  children: [
                    if (detail.story.isNotEmpty) ...[
                      Text(
                        detail.story,
                        style: const TextStyle(
                          color: AppColors.silver,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: AppDimens.gapLg),
                    ],
                    if (detail.infoLines.isNotEmpty) ...[
                      for (final line in detail.infoLines)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppDimens.gapSm),
                          child: Text(
                            line,
                            style: const TextStyle(
                              color: AppColors.steel,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      const SizedBox(height: AppDimens.gapLg),
                    ],
                    if (detail.sections.isNotEmpty)
                      for (final section in detail.sections) ...[
                        if (section.title.isNotEmpty) ...[
                          Text(
                            section.title,
                            style: const TextStyle(
                              color: AppColors.coolAccent,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppDimens.gapSm),
                        ],
                        // 势力简介为文本块；遍历 blocks 取文本（跳过表格/图片）。
                        for (final block in section.blocks)
                          if (!block.isTable && !block.isImage)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppDimens.gapSm,
                              ),
                              child: Text(
                                block.text,
                                style: const TextStyle(
                                  color: AppColors.silver,
                                  fontSize: 14,
                                  height: 1.6,
                                ),
                              ),
                            ),
                        const SizedBox(height: AppDimens.gapMd),
                      ],
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.coolAccent),
              ),
              error: (err, stack) => Padding(
                padding: const EdgeInsets.all(AppDimens.gapLg),
                child: Center(
                  child: Text(
                    '加载简介失败\n\n$err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
