import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/effects/glitch_transition.dart';
import '../../core/effects/scanline_overlay.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shenkong_backdrop.dart';
import '../achievements/achievement_trigger.dart';
import '../archive/archive_screen.dart';
import '../codex/wiki_sync.dart';
import '../feixun/feixun_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../profile/profile_screen.dart';
import '../search/global_search.dart';
import 'settings_screen.dart';

/// 主壳：终端主界面。桌面用侧边导航栏，移动端用底部导航。
class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // 启动后触发图鉴自动更新（按用户设置的频率，含本次启动检查）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(wikiSyncProvider.notifier).startup();
        // 触发首次启动成就
        AchievementTrigger(ref).onFirstLaunch();
        // 显示新手引导（如果是首次启动）
        showOnboardingIfNeeded(context, ref);
      }
    });
  }

  static const _titles = ['飞讯', '势力档案', '我的', '设置'];

  Widget _page(int i) {
    switch (i) {
      case 0:
        return const FeixunScreen();
      case 1:
        return const ArchiveScreen();
      case 2:
        return const ProfileScreen();
      default:
        return const SettingsScreen();
    }
  }

  static const _destinations = [
    (icon: Icons.forum_outlined, selected: Icons.forum, label: '飞讯'),
    (icon: Icons.hub_outlined, selected: Icons.hub, label: '势力档案'),
    (icon: Icons.person_outline, selected: Icons.person, label: '我的'),
    (icon: Icons.settings_outlined, selected: Icons.settings, label: '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        Responsive.isDesktop(context) ||
        Responsive.of(context) == ScreenClass.tablet;

    final body = ScanlineOverlay(
      animate: true,
      intensity: 0.4,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 主界面背景：深空联合 LOGO 水印（很淡，位于内容之下，不拦截交互）
          const ShenkongBackdrop(),
          // 板块切换用故障风切入：切 tab 时新板块"信号重连"般闪现。
          SafeArea(
            child: GlitchSwitcher(
              childKey: ValueKey(_index),
              child: _page(_index),
            ),
          ),
        ],
      ),
    );

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: AppColors.surface,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              indicatorColor: AppColors.coolGlow,
              leading: Padding(
                padding: const EdgeInsets.only(top: AppDimens.gapMd, bottom: AppDimens.gapMd),
                child: IconButton(
                  icon: const Icon(Icons.search, color: AppColors.coolAccent),
                  tooltip: '全局搜索',
                  onPressed: _openSearch,
                ),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected, color: AppColors.coolAccent),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, color: AppColors.border),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.coolAccent),
            tooltip: '全局搜索',
            onPressed: _openSearch,
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: AppColors.coolGlow,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selected, color: AppColors.coolAccent),
              label: d.label,
            ),
        ],
      ),
    );
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GlobalSearchScreen(),
      ),
    );
  }
}
