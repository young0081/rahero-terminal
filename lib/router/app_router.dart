import 'package:go_router/go_router.dart';

import '../core/effects/glitch_transition.dart';
import '../features/boot/boot_screen.dart';
import '../features/provisioning/provisioning_screen.dart';
import '../features/shell/shell_screen.dart';

/// 应用路由：开机 → 资源下载 → 主壳。
/// 页面切换统一用故障风（Glitch）过渡——与终端/扫描线科技风一致：
/// 旧页抖动淡出、新页像"信号重连"般闪烁切入（约 380ms）。
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) =>
          glitchTransitionPage(key: state.pageKey, child: const BootScreen()),
    ),
    GoRoute(
      path: '/provisioning',
      pageBuilder: (context, state) => glitchTransitionPage(
        key: state.pageKey,
        child: const ProvisioningScreen(),
      ),
    ),
    GoRoute(
      path: '/shell',
      pageBuilder: (context, state) =>
          glitchTransitionPage(key: state.pageKey, child: const ShellScreen()),
    ),
  ],
);
