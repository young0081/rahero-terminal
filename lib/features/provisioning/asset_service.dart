import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../../data/asset_manifest.dart';
import '../../core/storage/app_storage.dart';

/// 单个资源的下载/就绪状态。
enum AssetStatus { pending, downloading, ready, failed, skipped }

/// 下载进度回调数据。
class AssetProgress {
  final String id;
  final String name;
  final AssetStatus status;
  final double fraction; // 0..1
  final String? message;

  const AssetProgress({
    required this.id,
    required this.name,
    required this.status,
    this.fraction = 0,
    this.message,
  });
}

/// 资源下载与缓存服务。
///
/// 设计要点（对应 asset-provisioning 能力）：
/// - 受版权保护的图标/视频不入库，首次运行从库街区 CDN 下载并缓存到本地。
/// - 增量下载：已就绪的资源跳过；中断可续传（先下到 .part 再原子改名）。
/// - 校验和：清单中 checksum 非空时校验 sha256，不匹配则丢弃重下。
/// - 离线降级：地址未配置或网络失败时不崩溃、不阻塞，由 UI 用占位图兜底。
/// - 支持清空缓存后重新下载。
class AssetService {
  AssetService._();
  static final AssetService instance = AssetService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(minutes: 5),
  ));

  AssetManifest? _manifest;
  Directory? _cacheRoot;

  // 运行时下载并发上限：一次点开图鉴详情可能触发数十张图，限并发避免请求风暴
  // （打爆 CDN 致大量超时假性失败）与首帧卡顿。超额的下载排队等待空位。
  static const int _maxConcurrentDownloads = 5;
  int _activeDownloads = 0;
  final List<Completer<void>> _downloadWaiters = [];

  Future<void> _acquireSlot() async {
    if (_activeDownloads < _maxConcurrentDownloads) {
      _activeDownloads++;
      return;
    }
    final c = Completer<void>();
    _downloadWaiters.add(c);
    await c.future;
    _activeDownloads++;
  }

  void _releaseSlot() {
    _activeDownloads--;
    if (_downloadWaiters.isNotEmpty) {
      _downloadWaiters.removeAt(0).complete();
    }
  }

  /// 缓存根目录（跨平台）。位于应用支持目录下，不进版本库。
  Future<Directory> _ensureCacheRoot() async {
    if (_cacheRoot != null) return _cacheRoot!;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/rahero_terminal/cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheRoot = dir;
    return dir;
  }

  /// 加载打包进 app 的清单（assets/manifest/asset_manifest.json）。
  Future<AssetManifest> loadManifest() async {
    if (_manifest != null) return _manifest!;
    final raw =
        await rootBundle.loadString('assets/manifest/asset_manifest.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _manifest = AssetManifest.fromJson(json);
    return _manifest!;
  }

  /// 取某资源在本地缓存中的文件路径（不保证已存在）。
  Future<String> localPath(AssetEntry entry) async {
    final root = await _ensureCacheRoot();
    return '${root.path}/${entry.cache}';
  }

  /// 该资源是否已在本地就绪（文件存在且状态标记为 ready）。
  Future<bool> isReady(AssetEntry entry) async {
    if (!AppStorage.isAssetReady(entry.id)) return false;
    final f = File(await localPath(entry));
    return f.exists();
  }

  /// 校验文件 sha256 是否与清单一致（清单 checksum 为空时跳过校验返回 true）。
  Future<bool> _verifyChecksum(File file, AssetEntry entry) async {
    if (!entry.hasChecksum) return true;
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes).toString();
    return digest.toLowerCase() == entry.checksum.trim().toLowerCase();
  }

  /// 下载单个资源：先下到 .part 临时文件，校验通过后原子改名为正式文件。
  Future<bool> _downloadOne(
    AssetManifest manifest,
    AssetEntry entry, {
    void Function(double fraction)? onProgress,
  }) async {
    final dest = File(await localPath(entry));
    await dest.parent.create(recursive: true);
    final tmp = File('${dest.path}.part');
    if (await tmp.exists()) {
      await tmp.delete();
    }

    final url = '${manifest.baseUrl}/${entry.source}';
    try {
      await _dio.download(
        url,
        tmp.path,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );
    } catch (_) {
      if (await tmp.exists()) {
        await tmp.delete();
      }
      return false;
    }

    if (!await _verifyChecksum(tmp, entry)) {
      if (await tmp.exists()) await tmp.delete();
      return false;
    }

    // 覆盖写入：目标可能被占用（Windows errno 32），逐步降级，失败返 false 不抛，
    // 让 syncAll 继续其余资源（与 ensureFileFromUrl 一致，避免单文件占用整体中断）。
    if (await dest.exists()) {
      try {
        await dest.delete();
      } catch (_) {/* 被占用：尝试直接覆盖 */}
    }
    try {
      await tmp.rename(dest.path);
    } catch (_) {
      try {
        await tmp.copy(dest.path);
      } catch (_) {
        if (await tmp.exists()) {
          try {
            await tmp.delete();
          } catch (_) {/* ignore */}
        }
        return false; // 目标被占用且无法覆盖：本条降级占位，下次重下
      }
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {/* 残留 .part 可接受 */}
      }
    }
    await AppStorage.setAssetReady(entry.id, true);
    return true;
  }

  /// 增量同步全部资源。逐个产出进度事件，便于 UI 展示进度。
  ///
  /// 若下载地址尚未配置（上线前占位），则全部标记为 skipped 并立即结束，
  /// 不报错、不阻塞——UI 用占位图兜底。
  Stream<AssetProgress> syncAll({bool force = false}) async* {
    final manifest = await loadManifest();

    if (!manifest.isBaseUrlConfigured) {
      for (final entry in manifest.assets) {
        yield AssetProgress(
          id: entry.id,
          name: entry.name,
          status: AssetStatus.skipped,
          message: '下载地址未配置，使用占位图',
        );
      }
      return;
    }

    if (force) {
      await AppStorage.clearAssetState();
    }

    for (final entry in manifest.assets) {
      if (!force && await isReady(entry)) {
        yield AssetProgress(
          id: entry.id,
          name: entry.name,
          status: AssetStatus.ready,
          fraction: 1,
        );
        continue;
      }

      yield AssetProgress(
        id: entry.id,
        name: entry.name,
        status: AssetStatus.downloading,
      );

      double last = 0;
      final ok = await _downloadOne(
        manifest,
        entry,
        onProgress: (f) => last = f,
      );

      yield AssetProgress(
        id: entry.id,
        name: entry.name,
        status: ok ? AssetStatus.ready : AssetStatus.failed,
        fraction: ok ? 1 : last,
        message: ok ? null : '下载失败，将使用占位图',
      );
    }
  }

  /// 运行时动态下载：按显式 URL + 缓存相对路径下载单个文件。
  ///
  /// 与清单驱动下载共用机制——已缓存则跳过、`.part` 临时文件原子改名、
  /// 失败清理——区别仅在于 URL 来自运行时数据源（库街区 wiki）而非预置清单。
  /// 成功或已缓存返回本地绝对路径；失败返回 null（由调用方占位降级）。
  Future<String?> ensureFileFromUrl(
    String url,
    String cacheRelPath, {
    void Function(double fraction)? onProgress,
  }) async {
    final root = await _ensureCacheRoot();
    final dest = File('${root.path}/$cacheRelPath');

    // 已缓存（标记 ready 且文件存在）→ 跳过，直接返回。
    if (AppStorage.isAssetReady(cacheRelPath) && await dest.exists()) {
      return dest.path;
    }
    if (url.isEmpty) return null;

    await dest.parent.create(recursive: true);
    final tmp = File('${dest.path}.part');
    if (await tmp.exists()) await tmp.delete();

    await _acquireSlot();
    try {
      await _dio.download(
        url,
        tmp.path,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) onProgress(received / total);
        },
      );
    } catch (_) {
      if (await tmp.exists()) await tmp.delete();
      return null;
    } finally {
      _releaseSlot();
    }

    // 覆盖写入：目标可能被占用（Windows errno 32），逐步降级，失败不抛。
    if (await dest.exists()) {
      try {
        await dest.delete();
      } catch (_) {/* 被占用：尝试直接覆盖 */}
    }
    try {
      await tmp.rename(dest.path);
    } catch (_) {
      // rename 失败（dest 被占用）：退化为复制覆盖。copy 成功即视为成功——
      // 此时 dest 已是正确内容；清理 .part 仅最佳努力，失败也不影响结果，
      // 绝不能因 .part 删不掉就把已成功的下载当失败丢弃。
      try {
        await tmp.copy(dest.path);
      } catch (_) {
        if (await tmp.exists()) {
          try {
            await tmp.delete();
          } catch (_) {/* ignore */}
        }
        return null; // 目标被占用且无法覆盖：本次降级占位，下次重试
      }
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {/* 残留 .part 可接受，下次覆盖 */}
      }
    }
    await AppStorage.setAssetReady(cacheRelPath, true);
    return dest.path;
  }

  /// 清空所有缓存文件与状态（用于"重新下载"）。
  ///
  /// Windows 下若缓存里有文件正被占用（errno 32：正在下载的 .part、正在解码/播放
  /// 的图或视频），整目录 delete(recursive) 会抛 PathAccessException。这里改为
  /// 尽力删除：先试整目录，失败则逐文件删、跳过占用项，**绝不抛错**，并始终清空
  /// 就绪标记，使后续 ensureFileFromUrl 一律重新下载（残留的占用文件会被覆盖）。
  Future<void> clearCache() async {
    final root = await _ensureCacheRoot();
    if (await root.exists()) {
      try {
        await root.delete(recursive: true);
      } catch (_) {
        _bestEffortDelete(root);
      }
    }
    _cacheRoot = null;
    await AppStorage.clearAssetState();
  }

  /// 逐文件尽力删除目录内容，跳过被占用的文件，吞掉所有异常。
  void _bestEffortDelete(Directory dir) {
    try {
      final entities = dir.listSync(recursive: true, followLinks: false);
      for (final e in entities.whereType<File>()) {
        try {
          e.deleteSync();
        } catch (_) {/* 被占用：跳过，下载时覆盖 */}
      }
      for (final e in entities.whereType<Directory>().toList().reversed) {
        try {
          e.deleteSync(recursive: false);
        } catch (_) {/* 非空/占用：跳过 */}
      }
    } catch (_) {/* 列举失败也忽略 */}
  }
}

