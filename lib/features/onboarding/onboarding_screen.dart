import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_storage.dart';
import '../../core/theme/app_theme.dart';

/// 引导步骤定义
class GuideStep {
  final String id;
  final String title;
  final String description;
  final IconData icon;

  const GuideStep({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });
}

/// 新手引导步骤列表
const List<GuideStep> kGuideSteps = [
  GuideStep(
    id: 'welcome',
    title: '欢迎使用拉海洛终端',
    description: '这是一个《鸣潮》星炬学院终端的复刻应用，提供飞讯、图鉴、势力档案等功能。',
    icon: Icons.waving_hand,
  ),
  GuideStep(
    id: 'feixun',
    title: '飞讯系统',
    description: '模拟游戏内的聊天界面，查看与各势力的对话。支持文字和表情消息。',
    icon: Icons.forum,
  ),
  GuideStep(
    id: 'codex',
    title: '图鉴（资料库）',
    description: '对接库街区 Wiki，查看共鸣者、武器、声骸的详细资料、语音和立绘。',
    icon: Icons.menu_book,
  ),
  GuideStep(
    id: 'archive',
    title: '势力档案',
    description: '浏览 9 个势力/组织的动态图标和简介，了解鸣潮世界观。',
    icon: Icons.hub,
  ),
  GuideStep(
    id: 'profile',
    title: '个人中心',
    description: '查看使用统计、管理收藏夹、追踪成就进度。',
    icon: Icons.person,
  ),
  GuideStep(
    id: 'search',
    title: '全局搜索',
    description: '点击顶部搜索图标，快速查找角色、武器、飞讯消息等内容。',
    icon: Icons.search,
  ),
  GuideStep(
    id: 'complete',
    title: '开始探索',
    description: '引导已完成！你可以随时在设置中重新查看引导。',
    icon: Icons.rocket_launch,
  ),
];

/// 引导完成状态管理
class GuideStateNotifier extends Notifier<bool> {
  static const _key = 'guide_completed';

  @override
  bool build() {
    return AppStorage.getSetting<bool>(_key, false);
  }

  Future<void> markCompleted() async {
    state = true;
    await AppStorage.setSetting(_key, true);
  }

  Future<void> reset() async {
    state = false;
    await AppStorage.setSetting(_key, false);
  }
}

final guideCompletedProvider = NotifierProvider<GuideStateNotifier, bool>(
  GuideStateNotifier.new,
);

/// 新手引导界面
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部跳过按钮
            if (_currentPage < kGuideSteps.length - 1)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.gapMd),
                  child: TextButton(
                    onPressed: _skip,
                    child: const Text(
                      '跳过',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ),
              ),

            // 页面内容
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: kGuideSteps.length,
                itemBuilder: (context, index) {
                  final step = kGuideSteps[index];
                  return _StepPage(step: step);
                },
              ),
            ),

            // 底部指示器和按钮
            Padding(
              padding: const EdgeInsets.all(AppDimens.gapLg),
              child: Column(
                children: [
                  // 分页指示器
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      kGuideSteps.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppColors.coolAccent
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimens.gapLg),

                  // 按钮
                  Row(
                    children: [
                      if (_currentPage > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _previous,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('上一步'),
                          ),
                        ),
                      if (_currentPage > 0)
                        const SizedBox(width: AppDimens.gapMd),
                      Expanded(
                        child: FilledButton(
                          onPressed: _next,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            _currentPage == kGuideSteps.length - 1
                                ? '开始使用'
                                : '下一步',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _previous() {
    _controller.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _next() {
    if (_currentPage == kGuideSteps.length - 1) {
      _complete();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skip() {
    _controller.jumpToPage(kGuideSteps.length - 1);
  }

  Future<void> _complete() async {
    await ref.read(guideCompletedProvider.notifier).markCompleted();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

/// 单个引导步骤页面
class _StepPage extends StatelessWidget {
  final GuideStep step;

  const _StepPage({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.gapXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 图标
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.coolAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.coolAccent.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(step.icon, size: 64, color: AppColors.coolAccent),
          ),
          const SizedBox(height: AppDimens.gapXl),

          // 标题
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.silver,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimens.gapMd),

          // 描述
          Text(
            step.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// 在首次启动时显示引导的辅助方法
void showOnboardingIfNeeded(BuildContext context, WidgetRef ref) {
  final completed = ref.read(guideCompletedProvider);
  if (!completed) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const OnboardingScreen(),
            fullscreenDialog: true,
          ),
        );
      }
    });
  }
}
