import 'package:flutter_test/flutter_test.dart';

import 'package:rahero_terminal/features/codex/wiki_categories.dart';
import 'package:rahero_terminal/features/codex/wiki_models.dart';
import 'package:rahero_terminal/features/codex/wiki_parser.dart';

/// 取表格块每格的文本（测试用，忽略单元格图标）。
List<List<String>> rowTexts(WikiBlock b) =>
    b.rows.map((r) => r.map((c) => c.text).toList()).toList();

void main() {
  group('WikiParser.parseList', () {
    test('正常记录：提取名称/星级/图URL/entryId', () {
      final data = {
        'results': {
          'records': [
            {
              'id': 20985,
              'name': '达妮娅',
              'content': {
                'contentUrl': 'https://cdn.kurobbs.com/a.png',
                'star': '5',
                'linkConfig': {'entryId': '14888', 'linkType': 1},
                'title': '达妮娅',
              },
            },
          ],
        },
      };
      final list = WikiParser.parseList(data, WikiCategory.resonator);
      expect(list.length, 1);
      expect(list.first.name, '达妮娅');
      expect(list.first.star, 5);
      expect(list.first.figureUrl, 'https://cdn.kurobbs.com/a.png');
      expect(list.first.entryId, '14888');
      expect(list.first.hasDetail, true);
      expect(list.first.category, WikiCategory.resonator);
    });

    test('缺字段：无 star/linkConfig 容错，无名条目跳过', () {
      final data = {
        'results': {
          'records': [
            {
              'id': 1,
              'content': {'title': '无名武器', 'contentUrl': ''},
            },
            {
              'id': 2,
              'content': {'contentUrl': 'x'}, // 既无 name 也无 title → 跳过
            },
          ],
        },
      };
      final list = WikiParser.parseList(data, WikiCategory.weapon);
      expect(list.length, 1);
      expect(list.first.name, '无名武器');
      expect(list.first.star, 0);
      expect(list.first.entryId, '');
      expect(list.first.hasDetail, false);
    });

    test('空列表 / 结构异常返回空', () {
      expect(WikiParser.parseList(null, WikiCategory.echo), isEmpty);
      expect(WikiParser.parseList({}, WikiCategory.echo), isEmpty);
      expect(
          WikiParser.parseList(
              {'results': {'records': 'oops'}}, WikiCategory.echo),
          isEmpty);
    });

    test('linkType 2：无 entryId 时从 linkUrl 末段提取（修声骸"暂无详情"）', () {
      final data = {
        'results': {
          'records': [
            {
              'id': 19915,
              'name': '混沌之赋',
              'content': {
                'title': '混沌之赋',
                'contentUrl': 'https://cdn/e.png',
                'linkConfig': {
                  'linkUrl':
                      'https://wiki.kurobbs.com/mc/item/1467229559221452800',
                  'linkType': 2,
                },
              },
            },
          ],
        },
      };
      final list = WikiParser.parseList(data, WikiCategory.echo);
      expect(list.length, 1);
      expect(list.first.entryId, '1467229559221452800');
      expect(list.first.hasDetail, true);
    });
  });
  group('WikiParser.parseDetail', () {
    test('正常详情：提取 info 行与图片 URL', () {
      final data = {
        'content': {
          'title': '达妮娅',
          'story': '一段角色故事',
          'modules': [
            {
              'title': '基础资料',
              'components': [
                {
                  'role': {
                    'info': [
                      {'text': '性别：女'},
                      {'text': '武器：音感仪'},
                      {'text': '  '}, // 空白行应被过滤
                    ],
                    'figures': [
                      {'url': 'https://cdn.kurobbs.com/d.png', 'name': '基础信息'},
                      {'url': ''}, // 空 URL 应被过滤
                    ],
                  },
                },
              ],
            },
          ],
        },
      };
      final d = WikiParser.parseDetail(data);
      expect(d.name, '达妮娅');
      expect(d.story, '一段角色故事');
      expect(d.infoLines, ['性别：女', '武器：音感仪']);
      expect(d.imageUrls, ['https://cdn.kurobbs.com/d.png']);
    });

    test('缺 content / 结构异常容错为空', () {
      final d = WikiParser.parseDetail(null);
      expect(d.name, '');
      expect(d.infoLines, isEmpty);
      expect(d.imageUrls, isEmpty);

      final d2 = WikiParser.parseDetail({'content': {'modules': 'oops'}});
      expect(d2.infoLines, isEmpty);
    });

    test('武器/声骸 basic-component：解析标题与去 HTML 正文', () {
      final data = {
        'content': {
          'title': '赝作的矮星',
          'story': <String, dynamic>{}, // 武器 story 是空对象，不应渲染成 "{}"
          'modules': [
            {
              'title': '武器信息',
              'components': [
                {
                  'type': 'basic-component',
                  'title': '基础信息',
                  'content':
                      '<table><tbody><tr><td>名称</td><td>赝作的矮星</td></tr>'
                          '<tr><td>武器类型</td><td>音感仪</td></tr></tbody></table>',
                },
                {
                  'type': 'basic-component',
                  'title': '空内容',
                  'content': '<p>&nbsp;</p>', // 去 HTML 后为空 → 跳过
                },
              ],
            },
          ],
        },
      };
      final d = WikiParser.parseDetail(data);
      expect(d.story, ''); // {} 不渲染成 "{}"
      expect(d.infoLines, isEmpty); // 无 role 组件
      expect(d.sections.length, 1); // 空内容区块被跳过
      expect(d.sections.first.title, '基础信息');
      // 表格被解析为结构化行列（保留行列，不拍平）。
      final blocks = d.sections.first.blocks;
      final tables = blocks.where((b) => b.isTable).toList();
      expect(tables.length, 1);
      expect(rowTexts(tables.first), [
        ['名称', '赝作的矮星'],
        ['武器类型', '音感仪'],
      ]);
    });

    test('tabs-component：tabs[].content 的表格不丢失，带 tab 标题', () {
      final data = {
        'content': {
          'title': '达妮娅',
          'modules': [
            {
              'title': '基础资料',
              'components': [
                {
                  'type': 'tabs-component',
                  'title': '角色统计',
                  'content': '', // tabs 组件正文在 tabs[] 里，content 常为空
                  'tabs': [
                    {
                      'title': '1',
                      'active': true,
                      'content':
                          '<table><tbody><tr><td>生命</td><td>882</td></tr></tbody></table>',
                    },
                    {
                      'title': '满级',
                      'content':
                          '<table><tbody><tr><td>生命</td><td>9999</td></tr></tbody></table>',
                    },
                  ],
                },
              ],
            },
          ],
        },
      };
      final d = WikiParser.parseDetail(data);
      expect(d.sections.length, 1);
      expect(d.sections.first.title, '角色统计');
      final blocks = d.sections.first.blocks;
      // 顺序：【1】文本 → 表格(生命 882) → 【满级】文本 → 表格(生命 9999)
      expect(blocks.length, 4);
      expect(blocks[0].isTable, false);
      expect(blocks[0].text, '【1】');
      expect(blocks[1].isTable, true);
      expect(rowTexts(blocks[1]), [
        ['生命', '882'],
      ]);
      expect(blocks[2].text, '【满级】');
      expect(rowTexts(blocks[3]), [
        ['生命', '9999'],
      ]);
    });

    test('HTML 实体解码：命名实体与数字实体都还原（修乱码）', () {
      final data = {
        'content': {
          'title': 'x',
          'modules': [
            {
              'components': [
                {
                  'type': 'basic-component',
                  'title': '实体',
                  'content':
                      '<p>说&hellip;&ldquo;引&rdquo;&mdash;甲&middot;乙&#39;&#x4e2d;</p>',
                },
              ],
            },
          ],
        },
      };
      final d = WikiParser.parseDetail(data);
      // 无表格 → 单个文本块
      final textBlock =
          d.sections.first.blocks.firstWhere((b) => !b.isTable);
      final t = textBlock.text;
      expect(t, contains('…'));
      expect(t, contains('“引”'));
      expect(t, contains('—'));
      expect(t, contains('·'));
      expect(t, contains("'"));
      expect(t, contains('中')); // &#x4e2d; → 中
      expect(t, isNot(contains('&'))); // 不应残留任何 &xxx; 字面
    });

    test('表格 colspan 补空对齐 + 单元格内嵌标签去除', () {
      final data = {
        'content': {
          'title': 'x',
          'modules': [
            {
              'components': [
                {
                  'type': 'basic-component',
                  'title': '统计',
                  'content': '<table><tbody>'
                      '<tr><td>无突破</td><td colspan="2"><strong>属性</strong></td><td>攻击</td></tr>'
                      '<tr><td>生命</td><td colspan="2">882</td><td>防御</td></tr>'
                      '</tbody></table>',
                },
              ],
            },
          ],
        },
      };
      final d = WikiParser.parseDetail(data);
      final table = d.sections.first.blocks.firstWhere((b) => b.isTable);
      // colspan="2" → 单元格后补 1 个空格，两行都补齐到 4 列。
      expect(rowTexts(table), [
        ['无突破', '属性', '', '攻击'], // <strong> 标签被去除
        ['生命', '882', '', '防御'],
      ]);
    });

    test('表格与文本混排：按出现顺序切块', () {
      final data = {
        'content': {
          'title': 'x',
          'modules': [
            {
              'components': [
                {
                  'type': 'basic-component',
                  'title': '混排',
                  'content': '<p>前言段落</p>'
                      '<table><tbody><tr><td>键</td><td>值</td></tr></tbody></table>'
                      '<p>表后说明</p>',
                },
              ],
            },
          ],
        },
      };
      final d = WikiParser.parseDetail(data);
      final blocks = d.sections.first.blocks;
      expect(blocks.length, 3);
      expect(blocks[0].isTable, false);
      expect(blocks[0].text, '前言段落');
      expect(blocks[1].isTable, true);
      expect(rowTexts(blocks[1]), [
        ['键', '值'],
      ]);
      expect(blocks[2].isTable, false);
      expect(blocks[2].text, '表后说明');
    });

    test('图片提取：正文内嵌大图 → 图片块，表格内图标 → 单元格图标', () {
      final data = {
        'content': {
          'title': 'x',
          'modules': [
            {
              'components': [
                {
                  'type': 'basic-component',
                  'title': '技能',
                  'content': '<p>技能说明</p>'
                      '<img src="https://cdn.kurobbs.com/skill.png">'
                      '<p>结束</p>',
                },
                {
                  'type': 'basic-component',
                  'title': '材料',
                  'content': '<table><tbody><tr>'
                      '<td><img src="https://cdn.kurobbs.com/mat.png">低频声核</td>'
                      '<td>x4</td>'
                      '</tr></tbody></table>',
                },
              ],
            },
          ],
        },
      };
      final d = WikiParser.parseDetail(data);
      // 第一区块：文本 + 图片块 + 文本
      final skill = d.sections[0].blocks;
      expect(skill.length, 3);
      expect(skill[0].text, '技能说明');
      expect(skill[1].isImage, true);
      expect(skill[1].imageUrl, 'https://cdn.kurobbs.com/skill.png');
      expect(skill[2].text, '结束');
      // 第二区块：表格，单元格带图标 URL，文字去掉 <img> 仅留文本
      final matTable = d.sections[1].blocks.firstWhere((b) => b.isTable);
      expect(matTable.rows.first.first.text, '低频声核');
      expect(matTable.rows.first.first.imageUrl,
          'https://cdn.kurobbs.com/mat.png');
      expect(matTable.rows.first[1].text, 'x4');
      expect(matTable.rows.first[1].imageUrl, '');
    });

    test('图片提取边界：data-src 不误命中，单元格只采 <img> 的 src', () {
      final data = {
        'content': {
          'title': 'x',
          'modules': [
            {
              'components': [
                {
                  'type': 'basic-component',
                  'title': '懒加载',
                  // data-src 是 1px 占位，src 才是真实图：应取真实 src
                  'content':
                      '<img data-src="https://cdn/ph.png" src="https://cdn/real.png">',
                },
                {
                  'type': 'basic-component',
                  'title': '混标签单元格',
                  // 单元格内有非 img 的 source 标签在前，不应被当成图标
                  'content': '<table><tbody><tr>'
                      '<td><source src="https://cdn/v.mp4">'
                      '<img src="https://cdn/icon.png">材料</td>'
                      '</tr></tbody></table>',
                },
              ],
            },
          ],
        },
      };
      final d = WikiParser.parseDetail(data);
      final lazy = d.sections[0].blocks.firstWhere((b) => b.isImage);
      expect(lazy.imageUrl, 'https://cdn/real.png'); // 不是占位 ph.png
      final cell = d.sections[1].blocks
          .firstWhere((b) => b.isTable)
          .rows
          .first
          .first;
      expect(cell.text, '材料');
      expect(cell.imageUrl, 'https://cdn/icon.png'); // 不是 v.mp4
    });

    test('相邻同列数表格合并：突破素材回到同一张表，不同列数不合并', () {
      final data = {
        'content': {
          'title': 'x',
          'modules': [
            {
              'components': [
                {
                  'type': 'basic-component',
                  'title': '突破',
                  // 两个相邻 2 列表（等级要求 + 无边框素材表）应合并为一张
                  'content':
                      '<table><tbody><tr><td>所需等级</td><td>20</td></tr>'
                          '<tr><td colspan="2">突破素材</td></tr></tbody></table>'
                          '<table style="border-style: hidden;"><tbody>'
                          '<tr><td>低频声核x4</td><td>贝币x5000</td></tr>'
                          '</tbody></table>',
                },
                {
                  'type': 'basic-component',
                  'title': '不合并',
                  // 2 列表紧跟 3 列表，列数不同不应合并
                  'content': '<table><tbody><tr><td>A</td><td>B</td></tr></tbody></table>'
                      '<table><tbody><tr><td>C</td><td>D</td><td>E</td></tr></tbody></table>',
                },
              ],
            },
          ],
        },
      };
      final d = WikiParser.parseDetail(data);
      // 第一区块：两表合并为一张（3 行：所需等级 / 突破素材 / 素材）
      final merged = d.sections[0].blocks.where((b) => b.isTable).toList();
      expect(merged.length, 1);
      expect(rowTexts(merged.first), [
        ['所需等级', '20'],
        ['突破素材', ''], // colspan 补空对齐为 2 列
        ['低频声核x4', '贝币x5000'],
      ]);
      // 第二区块：列数不同，保持两张独立表
      final notMerged = d.sections[1].blocks.where((b) => b.isTable).toList();
      expect(notMerged.length, 2);
    });

    test('单元格 <a href> 链接保留 + 垃圾默认标题回退模块名', () {
      final data = {
        'content': {
          'title': 'x',
          'modules': [
            {
              'title': '角色攻略', // 模块名（有意义）
              'components': [
                {
                  'type': 'text-component',
                  'title': '纯文本组件', // 编辑器默认名（以"组件"结尾）→ 应被模块名替换
                  'content': '<table><tbody><tr>'
                      '<td>角色攻略</td>'
                      '<td><a href="https://wiki.kurobbs.com/mc/item/123" target="_blank">点击查看专题页</a></td>'
                      '</tr></tbody></table>',
                },
              ],
            },
          ],
        },
      };
      final d = WikiParser.parseDetail(data);
      expect(d.sections.length, 1);
      // 标题回退为模块名，而非"纯文本组件"
      expect(d.sections.first.title, '角色攻略');
      final table = d.sections.first.blocks.firstWhere((b) => b.isTable);
      final linkCell = table.rows.first[1];
      expect(linkCell.text, '点击查看专题页');
      expect(linkCell.linkUrl, 'https://wiki.kurobbs.com/mc/item/123');
      expect(linkCell.isLink, true);
      // 非链接单元格 linkUrl 为空
      expect(table.rows.first[0].isLink, false);
    });

    test('audio-component：解析角色语音分类与播放地址', () {
      final data = {
        'content': {
          'title': '达妮娅',
          'modules': [
            {
              'title': '角色语音',
              'components': [
                {
                  'type': 'audio-component',
                  'title': '角色台词',
                  'mediaTabs': [
                    {
                      'title': '中文',
                      'mediaList': [
                        {
                          'audioTitle': '自我介绍',
                          'playUrl': 'https://web-static.kurobbs.com/a.wav',
                          'content': '<p>你好，我是达妮娅</p>',
                        },
                        {
                          'audioTitle': '无地址', // 无 playUrl → 跳过
                          'content': '空',
                        },
                      ],
                    },
                    {
                      'title': '日文',
                      'mediaList': [
                        {
                          'audioTitle': '战斗1',
                          'playUrl': 'https://web-static.kurobbs.com/b.wav',
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        },
      };
      final d = WikiParser.parseDetail(data);
      expect(d.voiceTabs.length, 2);
      expect(d.voiceTabs.first.title, '中文');
      expect(d.voiceTabs.first.voices.length, 1); // 无地址的被跳过
      expect(d.voiceTabs.first.voices.first.title, '自我介绍');
      expect(d.voiceTabs.first.voices.first.url,
          'https://web-static.kurobbs.com/a.wav');
      expect(d.voiceTabs.first.voices.first.text, contains('你好'));
      expect(d.voiceTabs[1].title, '日文');
      expect(d.voiceTabs[1].voices.first.title, '战斗1');
    });
  });

  group('resolveCategoryId', () {
    test('从目录树按分类名解析 id', () {
      final tree = {
        'name': '全部',
        'id': 9,
        'children': [
          {
            'name': '游戏图鉴',
            'id': 1099,
            'children': [
              {'name': '共鸣者', 'id': 1105},
              {'name': '武器', 'key': 1106},
            ],
          },
        ],
      };
      expect(resolveCategoryId(tree, WikiCategory.resonator), '1105');
      expect(resolveCategoryId(tree, WikiCategory.weapon), '1106');
    });

    test('树为空或找不到时回退到内置常量', () {
      expect(resolveCategoryId(null, WikiCategory.echo),
          WikiCategory.echo.fallbackId);
      expect(resolveCategoryId({'name': '别的'}, WikiCategory.echo), '1107');
    });
  });
}

