import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

/// 库街区 wiki 接口调用结果：成功携带 [data]，失败携带 [error]。
/// 失败 SHALL NOT 抛出未捕获异常——由调用方据此降级（用缓存或占位）。
class WikiResult {
  final Map<String, dynamic>? data;
  final bool ok;
  final String? error;

  const WikiResult.success(this.data)
      : ok = true,
        error = null;
  const WikiResult.failure(this.error)
      : ok = false,
        data = null;
}

/// 库街区（Kuro 官方社区）wiki 数据源客户端。
///
/// 以匿名 h5 协议访问公开图鉴接口（不依赖任何账号 / token / cookie）：
/// - 请求头：`source: h5` + 随机 `devCode` + `wiki_type: 9`
/// - 表单：`gameId=3`（鸣潮）
/// 仅访问公开 wiki，不触碰任何需要登录的玩家存档类接口。
class KuroWikiClient {
  static const String _main = 'https://api.kurobbs.com';
  static const String treeUrl = '$_main/wiki/core/catalogue/config/getTree';
  static const String pageUrl = '$_main/wiki/core/catalogue/item/getPage';
  static const String detailUrl =
      '$_main/wiki/core/catalogue/item/getEntryDetail';
  static const String gameId = '3';
  static const String wikiType = '9';

  final Dio _dio;
  final int maxRetries;
  final Duration retryDelay;

  KuroWikiClient({
    Dio? dio,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
  }) : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
            ));
  /// 每次请求生成随机十六进制 devCode（实测无需固定设备指纹）。
  String _devCode() {
    final rand = Random();
    const hex = '0123456789abcdef';
    return List.generate(24, (_) => hex[rand.nextInt(16)]).join();
  }

  Map<String, dynamic> _headers() => {
        'source': 'h5',
        'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
        'devCode': _devCode(),
        'wiki_type': wikiType,
      };

  /// 执行一次 POST 请求，带有限重试。任何异常或非成功业务码都转为
  /// [WikiResult.failure]，不向上抛出未捕获异常。
  Future<WikiResult> _request(
      String url, Map<String, dynamic> form) async {
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final resp = await _dio.post(
          url,
          data: form,
          options: Options(
            headers: _headers(),
            contentType: Headers.formUrlEncodedContentType,
            responseType: ResponseType.json,
          ),
        );
        final body = _asMap(resp.data);
        if (body == null) {
          return const WikiResult.failure('响应非 JSON 对象');
        }
        if (body['code'] == 200) {
          return WikiResult.success(_asMap(body['data']) ?? const {});
        }
        // 业务码非 200：不重试（多为参数/接口变动），直接降级。
        return WikiResult.failure(
            'code=${body['code']} msg=${body['msg'] ?? ''}');
      } catch (e) {
        if (attempt < maxRetries - 1) {
          await Future.delayed(retryDelay);
          continue;
        }
        return WikiResult.failure('请求失败：$e');
      }
    }
    return const WikiResult.failure('请求失败：已达最大重试次数');
  }

  /// 把动态 JSON 安全转成 Map；data 有时是 JSON 字符串，需二次解析。
  Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    if (v is String && v.isNotEmpty) {
      try {
        final decoded = jsonDecode(v);
        if (decoded is Map) {
          return decoded.map((k, val) => MapEntry(k.toString(), val));
        }
      } catch (_) {/* 非 JSON 字符串，忽略 */}
    }
    return null;
  }
  /// 拉取图鉴目录树（用于定位各分类的 catalogueId）。
  Future<WikiResult> getTree() => _request(treeUrl, {'gameId': gameId});

  /// 分页拉取某分类下的条目列表。
  Future<WikiResult> getPage(String catalogueId,
          {int page = 1, int limit = 100}) =>
      _request(pageUrl, {
        'gameId': gameId,
        'catalogueId': catalogueId,
        'page': page,
        'limit': limit,
      });

  /// 按 entryId 拉取单条目详情。
  Future<WikiResult> getEntryDetail(String entryId) =>
      _request(detailUrl, {'id': entryId});
}
