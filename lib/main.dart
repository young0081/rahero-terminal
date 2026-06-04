import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'core/storage/app_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/title_bar.dart';
import 'router/app_router.dart';

/// 当前平台是否为桌面（Windows / Linux / macOS）。无边框窗口仅在桌面生效。
bool get isDesktopPlatform {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 桌面端视频后端初始化（媒体内核），移动端忽略即可。
  MediaKit.ensureInitialized();
  // 本地持久化（设置 / 进度 / 缓存状态）。
  await AppStorage.init();

  // 桌面端：初始化无边框窗口（隐藏系统标题栏，由 app 内置自绘标题条）。
  if (isDesktopPlatform) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1180, 760),
      minimumSize: Size(900, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden, // 无边框：隐藏系统标题栏
      title: '拉海洛终端',
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const ProviderScope(child: RaheroApp()));
}

class RaheroApp extends StatelessWidget {
  const RaheroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '拉海洛终端',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      routerConfig: appRouter,
      // 桌面无边框窗口：在所有页面顶部叠加自绘标题条；移动端不加。
      builder: (context, child) {
        if (!isDesktopPlatform) return child ?? const SizedBox.shrink();
        return Column(
          children: [
            const TitleBar(),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
    );
  }
}
