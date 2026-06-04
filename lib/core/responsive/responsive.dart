import 'package:flutter/widgets.dart';

/// 屏幕尺寸分档。
enum ScreenClass { mobile, tablet, desktop }

/// 响应式断点与设备类型判断。
class Responsive {
  Responsive._();

  static const double mobileMax = 600;
  static const double tabletMax = 1024;

  static ScreenClass classOf(double width) {
    if (width < mobileMax) return ScreenClass.mobile;
    if (width < tabletMax) return ScreenClass.tablet;
    return ScreenClass.desktop;
  }

  static ScreenClass of(BuildContext context) =>
      classOf(MediaQuery.sizeOf(context).width);

  static bool isMobile(BuildContext context) =>
      of(context) == ScreenClass.mobile;

  static bool isDesktop(BuildContext context) =>
      of(context) == ScreenClass.desktop;

  /// 根据档位取值，简化按尺寸切换布局参数。
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    switch (of(context)) {
      case ScreenClass.mobile:
        return mobile;
      case ScreenClass.tablet:
        return tablet ?? desktop;
      case ScreenClass.desktop:
        return desktop;
    }
  }
}
