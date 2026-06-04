import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rahero_terminal/features/codex/kuro_wiki_client.dart';

/// 可编程的假适配器：按调用序号返回预设响应或抛异常，不触真实网络。
class _FakeAdapter implements HttpClientAdapter {
  final List<Object> responses; // 每项：Map(JSON体) 或 Exception
  final List<RequestOptions> calls = [];
  int _i = 0;

  _FakeAdapter(this.responses);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls.add(options);
    final r = responses[_i < responses.length ? _i : responses.length - 1];
    _i++;
    if (r is Exception) throw r;
    final body = jsonEncode(r);
    return ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

KuroWikiClient _clientWith(_FakeAdapter adapter) {
  final dio = Dio();
  dio.httpClientAdapter = adapter;
  return KuroWikiClient(
      dio: dio, maxRetries: 3, retryDelay: const Duration(milliseconds: 1));
}

void main() {
  test('getPage 成功：返回 data，请求带 h5 头与 gameId', () async {
    final adapter = _FakeAdapter([
      {
        'code': 200,
        'msg': '操作成功',
        'data': {
          'results': {'records': []}
        }
      }
    ]);
    final client = _clientWith(adapter);
    final res = await client.getPage('1105', page: 1, limit: 5);
    expect(res.ok, true);
    expect(res.data!.containsKey('results'), true);

    final req = adapter.calls.single;
    expect(req.headers['source'], 'h5');
    expect(req.headers['wiki_type'], '9');
    expect((req.headers['devCode'] as String).length, 24);
    expect(req.data, containsPair('gameId', '3'));
    expect(req.data, containsPair('catalogueId', '1105'));
  });

  test('业务码非 200：降级为失败且不重试', () async {
    final adapter = _FakeAdapter([
      {'code': 102, 'msg': '服务器外部错误', 'data': null}
    ]);
    final client = _clientWith(adapter);
    final res = await client.getTree();
    expect(res.ok, false);
    expect(res.error, contains('102'));
    expect(adapter.calls.length, 1); // 业务码失败不重试
  });

  test('网络异常：重试到上限后返回失败', () async {
    final adapter = _FakeAdapter([
      Exception('boom1'),
      Exception('boom2'),
      Exception('boom3'),
    ]);
    final client = _clientWith(adapter);
    final res = await client.getEntryDetail('14888');
    expect(res.ok, false);
    expect(adapter.calls.length, 3); // maxRetries=3
  });

  test('前两次异常、第三次成功：重试后成功', () async {
    final adapter = _FakeAdapter([
      Exception('boom1'),
      Exception('boom2'),
      {'code': 200, 'data': {'content': {}}},
    ]);
    final client = _clientWith(adapter);
    final res = await client.getEntryDetail('14888');
    expect(res.ok, true);
    expect(adapter.calls.length, 3);
  });
}
