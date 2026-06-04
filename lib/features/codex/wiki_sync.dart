import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_storage.dart';
import '../archive/faction_service.dart';
import 'wiki_codex_service.dart';
import 'wiki_providers.dart';

/// 图鉴自动更新频率模式。全部包含"启动时检查一次"，区别在周期任务间隔。
enum WikiSyncMode {
  dawn('dawn', '启动时 + 每天凌晨4点', null), // 特殊：定时到次日04:00，错过则启动补
  daily('daily', '启动时 + 每天', Duration(hours: 24)),
  hourly('hourly', '启动时 + 每小时', Duration(hours: 1)),
  minute('minute', '启动时 + 每分钟', Duration(minutes: 1)),
  startup('startup', '仅启动时', null);

  final String id;
  final String label;
  final Duration? interval; // null = 无固定周期（dawn 用每日定点；startup 仅启动）
  const WikiSyncMode(this.id, this.label, this.interval);

  static WikiSyncMode fromId(String? id) => WikiSyncMode.values
      .firstWhere((m) => m.id == id, orElse: () => WikiSyncMode.dawn);
}

/// 自动更新的运行状态（供设置页展示）。
class WikiSyncState {
  final WikiSyncMode mode;
  final bool checking; // 正在检查
  final DateTime? lastSync; // 上次检查完成时间
  final WikiSyncResult? lastResult; // 上次检查结果

  const WikiSyncState({
    required this.mode,
    this.checking = false,
    this.lastSync,
    this.lastResult,
  });

  WikiSyncState copyWith({
    WikiSyncMode? mode,
    bool? checking,
    DateTime? lastSync,
    WikiSyncResult? lastResult,
  }) =>
      WikiSyncState(
        mode: mode ?? this.mode,
        checking: checking ?? this.checking,
        lastSync: lastSync ?? this.lastSync,
        lastResult: lastResult ?? this.lastResult,
      );
}

/// 图鉴自动更新调度器：启动检查 + 按模式周期检查 + 手动立即检查。
///
/// 桌面程序仅在运行期间检查；关闭期间的更新于下次启动补上。检查为轻量列表
/// 指纹比对，发现变化才刷新缓存并失效列表/详情 provider，素材按需惰性下载。
class WikiSyncNotifier extends Notifier<WikiSyncState> {
  Timer? _timer;

  @override
  WikiSyncState build() {
    ref.onDispose(() => _timer?.cancel());
    final mode = WikiSyncMode.fromId(
        AppStorage.getSetting<String>('wiki_sync_mode', WikiSyncMode.dawn.id));
    final lastMs = AppStorage.getSetting<int>('wiki_last_sync', 0);
    return WikiSyncState(
      mode: mode,
      lastSync:
          lastMs > 0 ? DateTime.fromMillisecondsSinceEpoch(lastMs) : null,
    );
  }

  /// app 启动时调用：安排周期任务并立即检查一次（含 dawn 模式的"错过补检查"）。
  Future<void> startup() async {
    _reschedule();
    await checkNow();
  }

  /// 立即检查一次更新。检查中重复调用直接返回，避免并发。
  /// 含图鉴（共鸣者/武器/声骸）与势力档案两类内容的检测刷新。
  Future<void> checkNow() async {
    if (state.checking) return;
    state = state.copyWith(checking: true);
    WikiSyncResult result;
    try {
      result = await WikiCodexService.instance.checkForUpdates();
    } catch (e) {
      result = WikiSyncResult(ok: false, error: '$e');
    }
    // 势力档案随同检测：独立 try，其失败（网络/写盘）不抹掉图鉴检测结果。
    // 用指纹比对，仅在真有变化时返回 true → 失效 provider，避免无谓重拉。
    var factionChanged = false;
    try {
      factionChanged = await FactionService.instance.checkForUpdates();
    } catch (_) {/* 势力刷新失败忽略，不影响图鉴 */}

    final now = DateTime.now();
    await AppStorage.setSetting('wiki_last_sync', now.millisecondsSinceEpoch);
    // 联网失败不覆盖上次成功结果（copyWith 省略 lastResult 即保留旧值），
    // 避免周期任务把"已是最新/已同步"无故刷成"联网失败"。
    state = result.ok
        ? state.copyWith(checking: false, lastSync: now, lastResult: result)
        : state.copyWith(checking: false, lastSync: now);
    if (result.hasChanges) {
      ref.invalidate(wikiListProvider);
      ref.invalidate(wikiDetailProvider);
    }
    // 仅当势力列表真有变化时才失效，避免每次检查都触发档案页重拉。
    if (factionChanged) ref.invalidate(factionListProvider);
  }

  /// 切换更新频率：持久化并重排周期任务。
  Future<void> setMode(WikiSyncMode mode) async {
    await AppStorage.setSetting('wiki_sync_mode', mode.id);
    state = state.copyWith(mode: mode);
    _reschedule();
  }

  void _reschedule() {
    _timer?.cancel();
    final mode = state.mode;
    if (mode == WikiSyncMode.dawn) {
      // 每天凌晨 4 点：用一次性定时器对准下一个 04:00，触发后检查并重排。
      // 桌面程序仅运行期生效；关闭期错过的检查由启动时的 checkNow 补上。
      final next = _nextDawn();
      final delay = next.difference(DateTime.now());
      _timer = Timer(delay.isNegative ? Duration.zero : delay, () {
        checkNow();
        _reschedule();
      });
      return;
    }
    final interval = mode.interval;
    if (interval != null) {
      _timer = Timer.periodic(interval, (_) => checkNow());
    }
  }

  /// 计算下一个凌晨 4:00 的时刻。
  DateTime _nextDawn() {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, 4);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next;
  }
}

final wikiSyncProvider =
    NotifierProvider<WikiSyncNotifier, WikiSyncState>(WikiSyncNotifier.new);
