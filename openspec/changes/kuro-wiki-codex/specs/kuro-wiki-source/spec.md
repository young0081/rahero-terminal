## ADDED Requirements

### Requirement: 库街区 wiki 数据源访问

系统 SHALL 提供一个库街区（Kuro 官方社区）wiki 数据源客户端，以匿名方式（不依赖任何游戏账号 / token / cookie）访问库街区公开 wiki 接口，按其 h5 协议构造请求并解析响应。客户端 SHALL 仅访问公开的图鉴 / 百科类接口，SHALL NOT 访问任何需要登录凭据的玩家存档类接口。

#### Scenario: 以 h5 协议匿名请求

- **WHEN** 客户端发起任一 wiki 接口请求
- **THEN** 请求 SHALL 带 `source: h5` 头、随机生成的 `devCode` 头与 `gameId` 表单参数，且 SHALL NOT 携带任何账号 token / cookie

#### Scenario: 接口失败时返回可降级结果

- **WHEN** wiki 接口请求超时、网络不可达或返回非成功业务码
- **THEN** 客户端 SHALL 在有限重试后返回失败结果（而非抛出未捕获异常），由调用方据此降级（用缓存或占位）

### Requirement: 图鉴目录、列表与详情拉取

数据源客户端 SHALL 支持三类拉取：目录树（定位各分类的 catalogueId）、分类条目列表（分页获取某分类下的条目）、词条详情（按 entryId 获取单条目详情）。分类 ID SHALL 优先从目录树按分类名动态解析，并以内置常量表作为兜底。

#### Scenario: 拉取目录树定位分类

- **WHEN** 客户端请求目录树
- **THEN** 系统 SHALL 解析出图鉴各分类及其 catalogueId（至少包含共鸣者 / 武器 / 声骸）

#### Scenario: 分页拉取分类条目列表

- **WHEN** 客户端以某 catalogueId 请求条目列表
- **THEN** 系统 SHALL 返回该分类下的条目集合，每个条目 SHALL 解析出名称、星级、图片 URL 与详情 entryId

#### Scenario: 按 entryId 拉取词条详情

- **WHEN** 客户端以某 entryId 请求词条详情
- **THEN** 系统 SHALL 返回该条目的详情内容（含名称与简介 / 模块文本）
