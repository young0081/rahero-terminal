## Why

项目当前的界面骨架已成型，但「内容」基本是空的——势力 / 角色资料库还没有真实的图鉴数据，素材下载机制（`asset-provisioning`）虽已写明"从库街区下载"，实现却假设素材预先托管在我们自建的 CDN 上（`baseUrl` 仍是占位符 `REPLACE_WITH_KUROBBS_CDN`），等于一直空着、靠占位图兜底。

参照 WutheringWavesUID 的做法（已核实其源码：调 `api.kurobbs.com` 的 wiki 接口拿 JSON，再惰性下载图片 URL 并本地缓存），我们可以让 app 运行时**直接从库街区官方 wiki 现拉**所需内容，无需我们自托管任何素材。本轮已实测确认：库街区 wiki 系列接口（`getTree` / `getPage` / `getEntryDetail`）**匿名可访问、无需游戏账号登录**，图片托管在 `prod-alicdn-community.kurobbs.com` 官方 CDN 且可直接下载。这条路同时更合规——连图片 URL 都不入库，全部由终端用户运行时按需从官方获取。

## What Changes

- 新增「库街区 wiki 数据源」客户端：按库街区 h5 协议（`source: h5` + 随机 `devCode` + `wiki_type` 头 + `gameId=3`）请求 wiki 接口，覆盖目录树（`getTree`）、分类列表（`getPage`）、词条详情（`getEntryDetail`）。
- 新增「图鉴内容拉取」：首批覆盖共鸣者（目录 1105）、武器（1106）、声骸（1107）三类全图鉴，解析出名称、星级、图片 URL、所属与简介等字段。
- 扩展 `asset-provisioning`：在既有"清单驱动下载"之外，新增"**运行时动态发现**"模式——素材 URL 由 wiki 接口返回实时提供，而非预置 manifest；沿用既有的惰性下载、本地缓存、校验与离线降级机制。
- 角色 / 势力资料库（`faction-archive`）接入真实图鉴数据：列表与详情展示从库街区拉取并缓存的图与文。
- 全程容错：wiki 接口或图片下载失败时不崩溃，以占位与提示降级，可重试。

## Capabilities

### New Capabilities
- `kuro-wiki-source`: 库街区 wiki 数据源客户端能力——封装库街区 h5 请求协议、目录树 / 列表 / 详情接口的拉取与解析、以及图鉴领域模型（共鸣者 / 武器 / 声骸条目）。

### Modified Capabilities
- `asset-provisioning`: 在"清单驱动下载"之外新增"运行时动态发现"下载模式——素材 URL 由 wiki 接口实时返回，而非预置 manifest，仍沿用既有惰性下载、本地缓存、校验与离线降级。
- `faction-archive`: 资料库列表与详情接入从库街区拉取并缓存的真实图鉴数据（图与文），替代纯占位内容。

## Impact

- **受影响能力规格**：新增 `kuro-wiki-source`；修订 `asset-provisioning`、`faction-archive`。
- **新增代码**：库街区 wiki 客户端（请求头构造 `source: h5` + 随机 `devCode` + `wiki_type` + `gameId=3`、`getTree` / `getPage` / `getEntryDetail` 封装）、图鉴领域模型与解析器、内容拉取协调器（列表 + 详情 + 图片）。
- **受影响代码**：`asset_service.dart`（新增按 URL 动态下载的入口，复用 `_downloadOne` 的 .part 原子写 / 校验 / 缓存逻辑）、`asset_manifest.dart`（区分静态清单项与动态发现项）、资料库 UI（`faction-archive` 相关组件接入真实数据）。
- **依赖**：复用既有 `dio`（HTTP）与 `crypto`（校验）；无需新增第三方依赖。
- **数据 / 持久化**：新增 wiki 内容的本地缓存（JSON 索引 + 图片文件）与"内容版本"标记，用于判断是否需要刷新；缓存缺失或解析失败时按需重新拉取。
- **网络与合规**：仅匿名访问库街区公开 wiki 接口与官方 CDN（`api.kurobbs.com` / `prod-alicdn-community.kurobbs.com`），不涉及任何游戏账号、token 或玩家存档数据；图片 URL 不入库，由终端用户运行时按需获取。
- **健壮性**：库街区接口为外部依赖，可能改协议 / 限流 / 不可达——所有请求需超时、重试与降级，失败时资料库以占位与提示呈现，不阻塞应用其他功能。
- **平台**：Windows / Linux / Android 三端一致。
- **破坏性**：无 BREAKING 变更；`asset-provisioning` 为增量扩展，既有清单驱动路径保持可用。

