import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/asset_manifest.dart';
import 'asset_service.dart';

/// 资源服务单例 provider。
final assetServiceProvider = Provider<AssetService>((ref) {
  return AssetService.instance;
});

/// 资源清单 provider（异步加载打包的 manifest）。
final assetManifestProvider = FutureProvider<AssetManifest>((ref) async {
  final service = ref.watch(assetServiceProvider);
  return service.loadManifest();
});

/// 全部资源同步进度流 provider。
/// 监听它即触发一次增量下载；UI 据此显示进度并在完成后进入主界面。
final assetSyncProvider = StreamProvider<AssetProgress>((ref) {
  final service = ref.watch(assetServiceProvider);
  return service.syncAll();
});
