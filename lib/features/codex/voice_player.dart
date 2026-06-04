import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../provisioning/asset_service.dart';

/// 当前播放状态：正在播放的语音 URL（null = 未播放）。
class VoicePlayerState {
  final String? playingUrl;
  final bool loading; // 正在下载/缓冲
  const VoicePlayerState({this.playingUrl, this.loading = false});
}

/// 角色语音播放器：单实例 Player，按需下载缓存 .wav 后播放。
///
/// 复用 media_kit（已用于桌面视频）。同一时刻只播一条；再次点同一条则停止。
/// 音频按 URL 的 sha1 命名缓存到本地，离线也能播放。
class VoicePlayerNotifier extends Notifier<VoicePlayerState> {
  Player? _player;
  StreamSubscription<bool>? _completedSub; // 仅订阅一次，dispose 时取消
  final AssetService _assets = AssetService.instance;
  int _gen = 0; // 播放代号：每次新播放自增，旧的下载回调据此作废

  @override
  VoicePlayerState build() {
    ref.onDispose(() {
      _completedSub?.cancel();
      _player?.dispose();
      _player = null;
    });
    return const VoicePlayerState();
  }

  Player _ensurePlayer() {
    if (_player != null) return _player!;
    final p = Player();
    // 只订阅一次播放结束事件，避免每次 toggle 重复 listen 导致监听器泄漏。
    _completedSub = p.stream.completed.listen((done) {
      if (done && state.playingUrl != null && !state.loading) {
        state = const VoicePlayerState();
      }
    });
    _player = p;
    return p;
  }

  /// 播放 / 停止某条语音（点正在播的则停）。
  Future<void> toggle(String url) async {
    if (url.isEmpty) return;
    final player = _ensurePlayer();

    // 点正在播放的 → 停止。
    if (state.playingUrl == url) {
      await player.stop();
      state = const VoicePlayerState();
      return;
    }

    final gen = ++_gen;
    state = VoicePlayerState(playingUrl: url, loading: true);
    try {
      // 先下载缓存（离线可复用），失败则直接用网络 URL 播放。
      final ext = url.toLowerCase().contains('.mp3') ? '.mp3' : '.wav';
      final h = sha1.convert(utf8.encode(url)).toString();
      final localPath = await _assets.ensureFileFromUrl(url, 'voice/$h$ext');
      // 下载期间用户又点了别的（gen 变化）→ 放弃本次，避免竞态错播。
      if (gen != _gen) return;
      final media = Media(localPath ?? url);
      await player.open(media);
      await player.play();
      if (gen == _gen) {
        state = VoicePlayerState(playingUrl: url);
      }
    } catch (_) {
      if (gen == _gen) state = const VoicePlayerState();
    }
  }

  /// 停止播放。
  Future<void> stop() async {
    _gen++;
    await _player?.stop();
    state = const VoicePlayerState();
  }
}

final voicePlayerProvider =
    NotifierProvider<VoicePlayerNotifier, VoicePlayerState>(
        VoicePlayerNotifier.new);
