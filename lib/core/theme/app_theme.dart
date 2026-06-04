import 'package:flutter/material.dart';

/// 拉海洛终端配色与主题 token。
///
/// 视觉定位（来自实机参考）：
/// - **终端本体**：以银灰、冷色调为主（深空联合是终端的归属方，整体冷峻科技感）。
/// - **绿色**：是「星炬学院」这一势力的专属代表色（DNA 双螺旋 logo 为青柠绿+蓝），
///   不作为终端通用强调色，仅在展示星炬学院相关内容时出现。
/// - **红色**：深空联合 logo 的点缀色，作为终端的稀疏强调/警示色。
class AppColors {
  AppColors._();

  // ---- 终端本体（银灰冷色调）----
  /// 背景：冷调近黑
  static const Color background = Color(0xFF070A0E);

  /// 面板背景
  static const Color surface = Color(0xFF0F151C);

  /// 悬浮层 / 更亮面板
  static const Color surfaceHigh = Color(0xFF1A2330);

  /// 主文字 / 终端主色：银白（冷）
  static const Color silver = Color(0xFFE6ECF2);

  /// 钢蓝灰：次要文字、图标、描边高亮
  static const Color steel = Color(0xFF8EA2BB);

  /// 冷调强调色（选中、进度、辉光）：银蓝
  static const Color coolAccent = Color(0xFFAFC6E0);

  /// 冷调辉光
  static const Color coolGlow = Color(0x55AFC6E0);

  /// 蓝（深空/科技点缀，谨慎使用）
  static const Color blue = Color(0xFF6078D8);
  static const Color glowBlue = Color(0x556078D8);

  /// 次要文字（冷灰）
  static const Color textMuted = Color(0xFF7E8896);

  /// 分割线 / 边框
  static const Color border = Color(0xFF26313E);

  /// 警示红（同时也是深空联合 logo 的点缀色）
  static const Color danger = Color(0xFFE2473C);

  /// 成功/就绪：沿用冷调强调色，保持整体冷感
  static const Color success = coolAccent;

  // ---- 势力专属色 ----
  /// 星炬学院 专属：青柠绿
  static const Color xingjuGreen = Color(0xFFB4F064);
  static const Color xingjuGlow = Color(0x66B4F064);

  /// 深空联合 专属：红
  static const Color shenkongRed = Color(0xFFE23C3C);

  /// 按势力 id 取专属强调色；未知势力回落到终端冷调强调色。
  static Color factionAccent(String id) {
    switch (id) {
      case 'faction_xingju':
        return xingjuGreen;
      case 'faction_shenkong':
      case 'boot_shenkong_text':
      case 'logo_shenkong':
        return shenkongRed;
      default:
        return coolAccent;
    }
  }
}

/// 字号/间距等尺寸 token。
class AppDimens {
  AppDimens._();

  static const double radiusSmall = 4;
  static const double radiusMedium = 8;
  static const double radiusLarge = 14;

  static const double gapXs = 4;
  static const double gapSm = 8;
  static const double gapMd = 16;
  static const double gapLg = 24;
  static const double gapXl = 40;

  /// 触摸目标最小尺寸（移动端可达性）
  static const double minTouchTarget = 48;
}

/// 全局主题构建。
class AppTheme {
  AppTheme._();

  static ThemeData build() {
    const base = ColorScheme.dark(
      primary: AppColors.coolAccent,
      secondary: AppColors.steel,
      surface: AppColors.surface,
      onPrimary: AppColors.background,
      onSecondary: AppColors.silver,
      onSurface: AppColors.silver,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: AppColors.background,
      // 字体：后续在 assets/fonts 加入终端等宽字体后，于此处与 pubspec 同步启用 fontFamily。
      textTheme: const TextTheme(
        displayLarge:
            TextStyle(color: AppColors.silver, fontWeight: FontWeight.w600),
        titleLarge:
            TextStyle(color: AppColors.silver, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: AppColors.silver),
        bodyLarge: TextStyle(color: AppColors.silver),
        bodyMedium: TextStyle(color: AppColors.silver),
        bodySmall: TextStyle(color: AppColors.textMuted),
        labelLarge:
            TextStyle(color: AppColors.coolAccent, letterSpacing: 1.2),
      ),
      dividerColor: AppColors.border,
      iconTheme: const IconThemeData(color: AppColors.steel),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.coolAccent,
        linearTrackColor: AppColors.border,
      ),
    );
  }
}
