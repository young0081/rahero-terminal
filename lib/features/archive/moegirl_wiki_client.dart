import 'dart:convert';

import 'package:dio/dio.dart';

/// 萌娘百科API客户端
class MoegirlWikiClient {
  static const String baseUrl = 'https://mzh.moegirl.org.cn';
  static const String apiPath = '/api.php';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// 搜索页面
  Future<List<String>> searchPages(String keyword) async {
    try {
      final response = await _dio.get(apiPath, queryParameters: {
        'action': 'opensearch',
        'search': keyword,
        'limit': '10',
        'namespace': '0',
        'format': 'json',
      });

      final data = response.data as List;
      if (data.length < 2) return [];

      final titles = data[1] as List;
      return titles.map((e) => e.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  /// 获取页面内容（解析后的HTML）
  Future<String?> getPageContent(String title) async {
    try {
      final response = await _dio.get(apiPath, queryParameters: {
        'action': 'parse',
        'page': title,
        'prop': 'text',
        'format': 'json',
      });

      final data = response.data as Map<String, dynamic>;
      final parse = data['parse'] as Map<String, dynamic>?;
      if (parse == null) return null;

      final text = parse['text'] as Map<String, dynamic>?;
      if (text == null) return null;

      return text['*'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// 获取页面Wikitext（原始格式）
  Future<String?> getPageWikitext(String title) async {
    try {
      final response = await _dio.get(apiPath, queryParameters: {
        'action': 'query',
        'titles': title,
        'prop': 'revisions',
        'rvprop': 'content',
        'format': 'json',
      });

      final data = response.data as Map<String, dynamic>;
      final query = data['query'] as Map<String, dynamic>?;
      if (query == null) return null;

      final pages = query['pages'] as Map<String, dynamic>?;
      if (pages == null) return null;

      // 取第一个页面
      final pageId = pages.keys.first;
      final page = pages[pageId] as Map<String, dynamic>?;
      if (page == null) return null;

      final revisions = page['revisions'] as List?;
      if (revisions == null || revisions.isEmpty) return null;

      final revision = revisions[0] as Map<String, dynamic>;
      return revision['*'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// 获取页面摘要
  Future<String?> getPageExtract(String title) async {
    try {
      final response = await _dio.get(apiPath, queryParameters: {
        'action': 'query',
        'titles': title,
        'prop': 'extracts',
        'exintro': 'true',
        'explaintext': 'true',
        'format': 'json',
      });

      final data = response.data as Map<String, dynamic>;
      final query = data['query'] as Map<String, dynamic>?;
      if (query == null) return null;

      final pages = query['pages'] as Map<String, dynamic>?;
      if (pages == null) return null;

      final pageId = pages.keys.first;
      if (pageId == '-1') return null; // 页面不存在

      final page = pages[pageId] as Map<String, dynamic>?;
      if (page == null) return null;

      return page['extract'] as String?;
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _dio.close();
  }
}
