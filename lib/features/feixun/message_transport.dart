import 'dart:async';

/// 飞讯消息传输抽象。
///
/// 当前无真实飞讯后端，提供 [MockMessageTransport] 占位实现以驱动"发送中 /
/// 已送达 / 失败"的真实状态流转与加载态。未来接入真实网络时，只需替换为
/// 真实实现，UI 与状态机无需改动。
abstract class MessageTransport {
  /// 发送一条消息。成功返回正常完成的 Future；失败抛异常（由调用方转为 failed 态）。
  Future<void> send(String contactId, String messageJson);

  /// 模拟 / 真实接收某条对方消息前的"接收中"等待（用于打字指示加载态）。
  Future<void> awaitIncoming();
}

/// 占位传输实现：可配置延迟与失败率，用于在无后端时演示网络波动下的加载态。
///
/// 注意：这是占位实现，不进行任何真实联网。默认成功、延迟很短，不干扰正常体验。
class MockMessageTransport implements MessageTransport {
  /// 发送延迟（模拟网络往返）。
  final Duration sendDelay;

  /// 接收延迟（模拟对方消息到达前的等待）。
  final Duration receiveDelay;

  /// 失败率 0..1（0 表示从不失败）。判定用注入的 [_roll] 以保持可测/可控。
  final double failureRate;

  /// 返回 0..1 的取值，用于失败判定。默认始终成功（返回 1.0）。
  /// 测试或演示可注入自定义实现（如固定值或伪随机）。
  final double Function() _roll;

  const MockMessageTransport({
    this.sendDelay = const Duration(milliseconds: 350),
    this.receiveDelay = const Duration(milliseconds: 900),
    this.failureRate = 0.0,
    double Function()? roll,
  }) : _roll = roll ?? _alwaysSucceed;

  static double _alwaysSucceed() => 1.0;

  @override
  Future<void> send(String contactId, String messageJson) async {
    await Future<void>.delayed(sendDelay);
    if (failureRate > 0 && _roll() < failureRate) {
      throw const MessageSendException('网络波动，发送失败');
    }
  }

  @override
  Future<void> awaitIncoming() async {
    await Future<void>.delayed(receiveDelay);
  }
}

/// 发送失败异常。
class MessageSendException implements Exception {
  final String message;
  const MessageSendException(this.message);
  @override
  String toString() => 'MessageSendException: $message';
}
