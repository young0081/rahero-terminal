# 拉海洛终端 | Rahero Terminal

<div align="center">

![Version](https://img.shields.io/badge/version-1.3-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20Android-lightgrey)
![License](https://img.shields.io/badge/license-MIT-green)

《鸣潮》星炬学院「拉海洛终端」跨平台复刻

**开源 · 免费 · 非官方同人作品**

[下载 Release](https://github.com/young0081/rahero-terminal/releases) · [报告问题](https://github.com/young0081/rahero-terminal/issues) · [功能建议](https://github.com/young0081/rahero-terminal/issues)

</div>

---

## ✨ 特性

### 核心功能
- 🎮 **图鉴系统**：共鸣者/武器/声骸完整资料，实时同步库街区wiki
- 💬 **飞讯系统**：角色对话剧本，支持UGC创作
- 📚 **势力档案**：13个势力详细资料，数据来自萌娘百科
- 💙 **好感度系统**：6个等级（陌生→挚友），互动增长
- 🏆 **成就系统**：15+个成就，实时追踪
- 🔍 **全局搜索**：跨模块统一搜索
- 👤 **个人信息**：名片、统计、收藏夹
- 🎨 **主题切换**：5套预设主题

### 技术亮点
- ✅ 运行时资源下载（增量同步 + sha256校验）
- ✅ 响应式布局（桌面/移动端自适应）
- ✅ 离线优先（本地缓存 + 占位降级）
- ✅ 多平台支持（Windows/Linux/Android）

---

## 📥 下载

### Windows用户（推荐）

**安装版**（推荐）
- 下载：[拉海洛终端_v1.3_Setup.exe](https://github.com/young0081/rahero-terminal/releases/latest)
- 大小：51 MB
- 特点：完全中文界面，自动创建快捷方式

**便携版**
- 下载：[拉海洛终端_v1.3_便携版.zip](https://github.com/young0081/rahero-terminal/releases/latest)
- 大小：62 MB
- 特点：解压即用，无需安装

### 系统要求
- **Windows**: Windows 10/11 (64位)
- **内存**: 4GB RAM（推荐8GB）
- **存储**: 200MB 可用空间
- **网络**: 首次运行需要下载资源（约50-100MB）

---

## 🚀 快速开始

### 安装版
1. 下载 `拉海洛终端_v1.3_Setup.exe`
2. 双击运行，跟随中文安装向导
3. 完成后从开始菜单或桌面启动

### 便携版
1. 下载 `拉海洛终端_v1.3_便携版.zip`
2. 解压到任意位置
3. 双击 `rahero_terminal.exe` 运行

### 首次运行
首次启动会自动下载必要的图标和视频资源（需要网络连接），下载完成后即可使用。

---

## 🛠️ 开发指南

### 环境准备

**必需**：
- Flutter SDK 3.44+ (Dart 3.12+)
- Android工具链（Android Studio / SDK）
- Windows SDK（Windows构建）

**配置国内镜像**（推荐）：
```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

### 构建项目

```bash
# 克隆仓库
git clone https://github.com/young0081/rahero-terminal.git
cd rahero-terminal

# 安装依赖
flutter pub get

# 运行（开发模式）
flutter run -d windows  # Windows
flutter run -d linux    # Linux
flutter run -d <设备号>  # Android

# 构建（Release）
flutter build windows   # Windows
flutter build linux     # Linux
flutter build apk       # Android
```

### Windows特殊说明

首次构建Windows版本需要下载media_kit的视频库：
```bash
# 国内用户使用预置脚本（推荐）
bash scripts/fetch_windows_libs.sh

# 或首次构建时自动从GitHub下载
flutter build windows
```

详细构建说明请查看：[CLAUDE.md](CLAUDE.md)

---

## 📂 项目结构

```
拉海洛终端/
├── lib/
│   ├── main.dart              # 入口
│   ├── router/                # 路由配置
│   ├── core/                  # 核心层
│   ├── data/                  # 数据模型
│   └── features/              # 功能模块
├── assets/                    # 资源文件
├── windows/                   # Windows平台
├── linux/                     # Linux平台
├── android/                   # Android平台
└── scripts/                   # 构建脚本
```

---

## 🔒 隐私与安全

- ✅ **开源透明**：所有代码公开，欢迎审计
- ✅ **本地存储**：所有用户数据存储在本地
- ✅ **不上传数据**：不会上传任何用户数据
- ✅ **公开数据源**：仅从公开wiki获取游戏资料

**数据存储位置**：
- Windows: `%LOCALAPPDATA%\rahero_terminal\`
- Linux: `~/.local/share/rahero_terminal/`
- Android: `/data/data/com.example.rahero_terminal/`

---

## 🤝 贡献

欢迎贡献代码、报告问题或提出建议！

### 如何贡献

1. Fork本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 提交Pull Request

---

## 📝 更新日志

### v1.3 (2024-06-04)

#### 新功能
- 💙 **好感度系统**：6个等级，互动增长
- ✍️ **UGC剧本系统**：创作、编辑、分享自定义剧本
- 🎨 **声骸GIF优化**：技能演示图放大显示
- 🌐 **势力档案改造**：切换到萌娘百科数据源

#### 移除功能
- ❌ 每日签到/祝福（保持内容真实性）

---

## 📄 许可证

本项目基于 [MIT License](LICENSE) 开源。

### 重要说明

- 本项目为《鸣潮》同人作品，**非官方项目**
- 游戏素材版权归《鸣潮》官方所有
- 仅供学习交流使用，**禁止商业用途**
- 与游戏官方无任何关联

---

## 🙏 致谢

### 数据来源
- [库街区](https://wiki.kurobbs.com/) - 角色/武器/声骸数据
- [萌娘百科](https://zh.moegirl.org.cn/) - 势力档案资料
- 《鸣潮》官方 - 原始游戏内容

### 技术栈
- [Flutter](https://flutter.dev/) - 跨平台UI框架
- [Riverpod](https://riverpod.dev/) - 状态管理
- [Hive](https://hivedb.dev/) - 本地存储
- [media_kit](https://github.com/media-kit/media-kit) - 视频播放

---

## 📞 联系方式

- **问题反馈**：[GitHub Issues](https://github.com/young0081/rahero-terminal/issues)
- **功能建议**：[GitHub Discussions](https://github.com/young0081/rahero-terminal/discussions)

---

<div align="center">

**如果这个项目对你有帮助，请给个⭐️支持一下！**

Made with ❤️ by 星炬学院

</div>
