## 1. 库街区 wiki 客户端（kuro-wiki-source）

- [x] 1.1 新增 `KuroWikiClient`：封装 h5 请求头（`source: h5` + 随机 `devCode` + `wiki_type: 9`）与 `gameId=3` 表单
- [x] 1.2 实现 `getTree`（目录树）、`getPage`（分类列表，含 catalogueId/page/limit）、`getEntryDetail`（详情，含 id）三个接口
- [x] 1.3 统一的请求执行：超时、有限重试、code!=200 与网络异常转为可降级的失败结果（不抛未捕获异常）
- [x] 1.4 分类 ID 解析：优先从 `getTree` 按分类名动态解析，内置常量表（共鸣者 1105 / 武器 1106 / 声骸 1107）兜底
- [x] 1.5 客户端单测：用本地固定 JSON 夹具验证三个接口的解析与失败降级（不打真实网络）

## 2. 图鉴领域模型与解析

- [x] 2.1 定义 `WikiEntry`（id、name、star、figureUrl、entryId、category）与 `WikiEntryDetail`（name、info行、story、sections、图片）
- [x] 2.2 列表解析器：从 `data.results.records[]` 容错提取 name / content.contentUrl / content.star / content.linkConfig.entryId
- [x] 2.3 详情解析器：兼容两种模块形态——角色 `role.{info,figures}` 与武器/声骸 `basic-component`（标题 + 去 HTML 正文 → sections）；修复 story 为 `{}` 时误渲染为 "{}" 的 bug；单条失败只跳过
- [x] 2.4 模型与解析单测：覆盖正常 / 缺字段 / 空列表 / basic-component 四类夹具

## 3. asset-provisioning 运行时动态下载

- [x] 3.1 `AssetService.ensureFileFromUrl`：按"显式 URL + 目标缓存相对路径"下载，复用 `.part` 原子写 / 标记 ready
- [x] 3.2 稳定缓存键：动态素材按 `wiki/<category>/<id>.<ext>` 组织，幂等可复用
- [x] 3.3 惰性与降级：已缓存则跳过返回本地路径；失败清理 .part、返回 null 供占位与重试
- [x] 3.4 动态内容索引（codex Hive box）与静态 manifest 分离存储，运行时数据不写回 manifest

## 4. 内容协调与缓存刷新

- [x] 4.1 `WikiCodexService`：协调三类列表并发拉取、图片与详情惰性拉取（经 asset-provisioning 动态下载入口缓存）
- [x] 4.2 列表 / 详情 JSON 本地缓存（codex box，与图片文件分离存储）
- [x] 4.3 内容版本标记：AppStorage 预留 get/setCodexVersion；当前以缓存存在性 + 手动刷新为主
- [x] 4.4 刷新流程幂等可重入（refreshAll 清内存树 + force 重拉）；无网络 / 失败时保留原缓存并标注"可能非最新"

## 5. faction-archive 资料库接入真实数据

- [x] 5.1 列表接入真实图鉴条目（名称 / 星级 / 缩略图），按分类组织（资料库新增「图鉴」标签，共鸣者/武器/声骸 ChoiceChip 切换）
- [x] 5.2 详情视图接入真实图片与 info行/story/sections（角色与武器/声骸两种形态均呈现）
- [x] 5.3 数据未就绪 / 失败时的加载态与占位 + 重试入口
- [x] 5.4 资料库内提供"刷新图鉴"入口（刷新按钮）

## 6. 集成与验证

- [x] 6.1 dart analyze 零问题（全量）
- [x] 6.2 flutter test 全绿（19 个：11 新增 codex + 8 既有）
- [x] 6.3 联网集成验证：用真实 KuroWikiClient+WikiParser 打库街区，三类全通——共鸣者 53 / 武器 115 / 声骸 180 条，详情区块正确解析（达妮娅 12 区块、赝作的矮星 5 区块、声骸 3 区块）；debug 构建启动正常
- [ ] 6.4 离线 / 接口失败降级：已写代码（stale 标记 + 占位 + 重试），单测覆盖失败降级；运行态断网实测未做
- [ ] 6.5 二次进入走缓存秒开 + 手动刷新：已写代码（codex box JSON 缓存 + refreshAll）；运行态实测未做
- [ ] 6.6 三端一致性：仅 Windows 实测，Linux/Android 待对应环境
- [ ] 6.7 打包发布版 exe 并更新到桌面（进行中）

