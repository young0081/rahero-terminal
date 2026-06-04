import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_storage.dart';
import '../../core/theme/app_theme.dart';

/// 主题预设
enum ThemePreset {
  coldSilver('冷调银灰', '默认终端配色'),
  xingjuGreen('星炬绿', '星炬学院专属配色'),
  shenkongRed('深空红', '深空联合专属配色'),
  purpleTech('紫色科幻', '科技感紫色主题'),
  amberWarm('琥珀暖调', '温暖的琥珀色调');

  final String label;
  final String description;

  const ThemePreset(this.label, this.description);
}

/// 主题配色方案定义
class ThemeColors {
  final Color primary;
  final Color primaryGlow;
  final Color accent;
  final Color accentGlow;

  const ThemeColors({
    required this.primary,
    required this.primaryGlow,
    required this.accent,
    required this.accentGlow,
  });
}

/// 各主题的配色
const Map<ThemePreset, ThemeColors> kThemeColorMap = {
  ThemePreset.coldSilver: ThemeColors(
    primary: AppColors.coolAccent,
    primaryGlow: AppColors.coolGlow,
    accent: AppColors.steel,
    accentGlow: Color(0x558EA2BB),
  ),
  ThemePreset.xingjuGreen: ThemeColors(
    primary: AppColors.xingjuGreen,
    primaryGlow: AppColors.xingjuGlow,
    accent: Color(0xFF8FD14F),
    accentGlow: Color(0x668FD14F),
  ),
  ThemePreset.shenkongRed: ThemeColors(
    primary: AppColors.shenkongRed,
    primaryGlow: Color(0x66E23C3C),
    accent: Color(0xFFFF6B6B),
    accentGlow: Color(0x66FF6B6B),
  ),
  ThemePreset.purpleTech: ThemeColors(
    primary: Color(0xFFB794F6),
    primaryGlow: Color(0x66B794F6),
    accent: Color(0xFF9F7AEA),
    accentGlow: Color(0x669F7AEA),
  ),
  ThemePreset.amberWarm: ThemeColors(
    primary: Color(0xFFFBBF24),
    primaryGlow: Color(0x66FBBF24),
    accent: Color(0xFFF59E0B),
    accentGlow: Color(0x66F59E0B),
  ),
};

/// 主题状态管理
class ThemeNotifier extends Notifier<ThemePreset> {
  static const _key = 'theme_preset';

  @override
  ThemePreset build() {
    final saved = AppStorage.getSetting<String>(_key, '');
    if (saved.isEmpty) return ThemePreset.coldSilver;
    try {
      return ThemePreset.values.firstWhere(
        (t) => t.name == saved,
        orElse: () => ThemePreset.coldSilver,
      );
    } catch (_) {
      return ThemePreset.coldSilver;
    }
  }

  Future<void> setTheme(ThemePreset preset) async {
    state = preset;
    await AppStorage.setSetting(_key, preset.name);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemePreset>(
  ThemeNotifier.new,
);

/// 获取当前主题的配色
ThemeColors getThemeColors(ThemePreset preset) {
  return kThemeColorMap[preset] ?? kThemeColorMap[ThemePreset.coldSilver]!;
}

/// 主题选择界面
class ThemeSelectorSheet extends ConsumerWidget {
  const ThemeSelectorSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);

    return Container(
      padding: const EdgeInsets.all(AppDimens.gapLg),
      decoration: const BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusLarge)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '选择主题',
            style: TextStyle(
              color: AppColors.silver,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimens.gapXs),
          const Text(
            '选择你喜欢的配色方案',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: AppDimens.gapLg),
          ...ThemePreset.values.map((preset) {
            final colors = getThemeColors(preset);
            final isSelected = currentTheme == preset;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
              child: InkWell(
                onTap: () {
                  ref.read(themeProvider.notifier).setTheme(preset);
                  Navigator.of(context).pop();
                },
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                child: Container(
                  padding: const EdgeInsets.all(AppDimens.gapMd),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                    border: Border.all(
                      color: isSelected ? colors.primary : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // 颜色预览
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colors.primary, colors.accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
                        ),
                      ),
                      const SizedBox(width: AppDimens.gapMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              preset.label,
                              style: TextStyle(
                                color: isSelected ? colors.primary : AppColors.silver,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              preset.description,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: colors.primary,
                          size: 24,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// 显示主题选择器的辅助方法
void showThemeSelector(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const ThemeSelectorSheet(),
  );
}
