## Context

项目界面骨架已成型，但内容是空的：`asset-provisioning` 虽声明"从库街区下载"，实现却假设素材预置在自建 CDN（`baseUrl` 仍是 `REPLACE_WITH_KUROBBS_CDN` 占位符），导致一直走"跳过下载、占位兜底"。`faction-archive` 资料库也只有动态图标占位，没有真实图鉴数据。

本轮已**实测核实**库街区（Kuro 官方社区）wiki 接口可作为数据源（参照 WutheringWavesUID 的同款做法）：

- 接口域名 `https://api.kurobbs.com`，请求头 `source: h5` + 随机 `devCode` + `wiki_type: 9`，body `gameId=3`。
- `wiki/core/catalogue/config/getTree` → 完整图鉴目录树（游戏图鉴下：共鸣者=1105、武器=1106、声骸=1107…）。
- `wiki/core/catalogue/item/getPage`（`catalogueId` + `page` + `limit`）→ 该分类条目列表；每条 `records[]` 含 `name`、`content.contentUrl`（图 URL）、`content.star`（星级）、`content.linkConfig.entryId`（详情 ID）。
- `wiki/core/catalogue/item/getEntryDetail`（`id`=entryId）→ 词条详情（`content`、`name`、`currentVersion` 等）。
- 图片托管在 `prod-alicdn-community.kurobbs.com`，可直接 GET（实测返回 200 + 合法 PNG）。
- 全部接口**匿名可访问，无需游戏账号 / token**；玩家存档类接口（需 cookie）本项目完全不用。

约束：三端（Windows / Linux / Android）一致；不新增第三方依赖（复用 `dio` + `crypto`）；库街区为外部依赖，须超时 / 重试 / 降级；图片 URL 不入库，由终端用户运行时按需获取。

## Goals / Non-Goals

**Goals:**
- 封装库街区 wiki h5 请求协议与三个核心接口（目录树 / 列表 / 详情）的拉取与解析。
- 拉取共鸣者 / 武器 / 声骸三类全图鉴，解析为领域模型（名称、星级、图 URL、所属、简介等）。
- 在 `asset-provisioning` 既有"清单驱动"之外，新增"运行时动态发现"下载模式：URL 由 wiki 接口实时提供，复用既有惰性下载 / 原子写 / 校验 / 缓存 / 降级。
- `faction-archive` 资料库接入真实图鉴数据与图片。

**Non-Goals:**
- 不接入任何玩家存档 / 账号 / token 相关接口。
- 不做战斗数值 / 伤害计算 / 攻略图等 WWUID 的衍生功能。
- 不预置 / 不入库任何图片二进制；不搭建自建 CDN。
- 首批不覆盖共鸣者 / 武器 / 声骸以外的目录（敌人、道具等留待后续）。

## Decisions

### 1. 新增独立的 `KuroWikiClient`，封装库街区 h5 请求协议
单独的客户端类，集中处理：请求头构造（`source: h5` + 随机 `devCode` + `wiki_type: 9`）、`gameId=3` body、三个接口（`getTree` / `getPage` / `getEntryDetail`）、超时与重试。
- **为什么**：库街区协议细节（特殊头、表单编码、code 判定）应收敛到一处，与领域模型 / UI 解耦；未来接口变动只改这一个类。复用既有 `dio` 实例配置。
- **devCode**：每次请求生成随机十六进制串即可（实测无需固定设备指纹）；避免任何账号 / token。
- **接口契约（已实测固化）**：
  - `getTree`：无额外参数 → 目录树，定位分类 `catalogueId`。
  - `getPage`：`catalogueId` + `page` + `limit` → `data.results.records[]`，每条取 `name` / `content.contentUrl` / `content.star` / `content.linkConfig.entryId`。
  - `getEntryDetail`：`id`=entryId → `data.content`（详情富文本 / 模块）。
- **备选**：把请求逻辑塞进 `AssetService`。否决：职责混杂，wiki 协议与通用下载是两件事。

### 2. 图鉴领域模型与"分类常量表"
定义 `WikiEntry`（id、name、star、figureUrl、entryId、category）与可选的 `WikiEntryDetail`（简介 / 模块）。分类 ID 用常量表固定首批：共鸣者 1105 / 武器 1106 / 声骸 1107。
- **为什么**：以稳定的领域模型隔离库街区 JSON 的易变结构（`content.*` 字段繁杂且含大量编辑器占位字段）；解析器只挑选需要的字段，对缺字段容错。
- **分类 ID 来源**：优先用 `getTree` 动态解析（按分类名 → id），并以常量表作为兜底，避免目录结构调整时硬编码失效。
- **备选**：直接把原始 JSON 透传给 UI。否决：UI 与外部结构强耦合，库街区一改就崩。

### 3. `asset-provisioning` 扩展"运行时动态发现"下载，而非另起炉灶
新增一个按"显式 URL + 目标缓存路径"下载单个文件的入口，复用既有 `_downloadOne` 的 `.part` 临时文件 → 校验 → 原子改名 → 标记 ready 流程；区别仅在于 URL 来自 wiki 接口而非预置 manifest。
- **为什么**：缓存、原子写、校验、离线降级这些机制已实现且经过设计，动态发现只是"URL 的来源不同"。复用而非重写，降低风险。
- **缓存键**：以稳定标识（如 `wiki/<category>/<entryId>.png`）作为缓存相对路径，保证幂等与可复用；wiki 内容 JSON 索引单独缓存并带版本标记。
- **备选**：动态项也写回静态 manifest。否决：manifest 是随仓库分发的静态契约，不应被运行时数据污染。

### 4. 内容拉取协调器：列表先行、详情与图片惰性
一个 `WikiCodexService` 协调：先拉三类列表（轻量 JSON，建立条目索引并缓存）；图片与详情在进入资料库 / 点开条目时按需拉取，下载结果走 `asset-provisioning` 的动态下载入口缓存。
- **为什么**：列表是进入资料库的最小必要数据，应快；全量图片 / 详情体量大，惰性拉取避免首次进入长时间等待，也契合"按需下载"的合规姿态。
- **并发**：列表三类可并发；图片下载受既有下载器节流，避免一次性打满。
- **备选**：进入即全量下载所有图。否决：首次体验差、流量大、与按需理念不符。

### 5. 内容缓存与刷新：JSON 索引 + 版本标记
wiki 列表 / 详情解析结果以 JSON 缓存（与图片文件分离）。`getTree` / 列表返回里带的版本字段（如 `catalogPageVersion`）作为"内容版本"标记；版本未变则直接用缓存，变了或用户手动刷新才重新拉取。
- **为什么**：库街区内容更新不频繁，缓存 JSON 让二次进入秒开、离线可用；版本标记提供"何时该刷新"的判据，避免每次启动都打接口。
- **降级**：无网络或接口失败时，有缓存就用缓存（标注"可能非最新"），无缓存则空列表 + 提示 + 重试入口。
- **备选**：固定 TTL 过期。否决：版本标记比时间更准，且省请求。

## Risks / Trade-offs

- **库街区为外部依赖，可能改协议 / 限流 / 封禁** → 所有请求超时 + 有限重试 + 失败降级；协议细节收敛在 `KuroWikiClient` 一处，便于快速跟进调整；失败时资料库以缓存或占位呈现，绝不阻塞应用其余功能。
- **wiki JSON 结构繁杂且含大量编辑器占位字段** → 解析器只挑选稳定的少数字段（name / contentUrl / star / entryId），对缺字段 / 类型异常容错，单条解析失败只跳过该条不影响整体。
- **首次进入资料库需要联网拉列表** → 列表轻量、三类并发；拉取期间显示加载态（复用 feixun 那套加载语汇）；之后走 JSON 缓存秒开。
- **图片版权与合规** → 仅匿名访问公开 wiki 与官方 CDN，不入库任何二进制，由终端用户运行时按需获取，与项目"运行时下载资源"的既有声明一致。
- **分类 ID 硬编码可能随目录调整失效** → 优先用 `getTree` 动态解析分类名 → id，常量表仅作兜底。
- **缓存与版本判断出错导致内容陈旧** → 版本标记 + 手动刷新双保险；刷新走与首次拉取相同的路径，幂等可重入。
- **网络层无鉴权但仍是外部出网** → 仅访问 `api.kurobbs.com` 与 `prod-alicdn-community.kurobbs.com` 两个固定域名，不传输任何本地数据 / 用户信息，纯 GET / 表单查询。


