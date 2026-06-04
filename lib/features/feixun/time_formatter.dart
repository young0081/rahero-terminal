/// 智能时间戳格式化工具。
class TimeFormatter {
  /// 格式化消息时间戳为智能显示：
  /// - 今天：显示时:分（如 14:32）
  /// - 昨天：显示"昨天"
  /// - 更早：显示月-日（如 06-01）
  static String format(String timeStr) {
    try {
      // 尝试解析现有时间字符串，支持多种格式
      DateTime? msgTime;

      // 格式1: HH:mm
      if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(timeStr)) {
        final parts = timeStr.split(':');
        final now = DateTime.now();
        msgTime = DateTime(now.year, now.month, now.day,
            int.parse(parts[0]), int.parse(parts[1]));
      }
      // 格式2: yyyy-MM-dd HH:mm 或 ISO8601
      else if (timeStr.contains('-') || timeStr.contains('T')) {
        msgTime = DateTime.tryParse(timeStr);
      }

      // 如果解析失败，返回原字符串
      if (msgTime == null) return timeStr;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final msgDay = DateTime(msgTime.year, msgTime.month, msgTime.day);

      if (msgDay == today) {
        // 今天：显示时:分
        return '${msgTime.hour.toString().padLeft(2, '0')}:${msgTime.minute.toString().padLeft(2, '0')}';
      } else if (msgDay == yesterday) {
        // 昨天
        return '昨天';
      } else {
        // 更早：月-日
        return '${msgTime.month.toString().padLeft(2, '0')}-${msgTime.day.toString().padLeft(2, '0')}';
      }
    } catch (_) {
      // 任何异常都返回原字符串
      return timeStr;
    }
  }
}
