# Android构建任务文档

## 任务目标
完成拉海洛终端的Android平台APK构建，使其可以在Android设备上运行。

---

## 当前状态

### ✅ 已完成的工作

#### 1. Android配置更新
**文件**: `android/app/src/main/AndroidManifest.xml`

**已添加权限**:
```xml
<!-- 网络权限：资源下载、图鉴数据同步 -->
<uses-permission android:name="android.permission.INTERNET" />
<!-- 外部存储权限：缓存下载的资源文件 -->
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
```

**应用名称**: 从 `rahero_terminal` 改为 `拉海洛终端`

**包名**: `com.starforge.rahero_terminal`

#### 2. 文档创建
- ✅ `ANDROID_BUILD.md` - 完整的Android构建指南
- ✅ `ANDROID_BUILD_CHECKLIST.md` - 详细的执行清单
- ✅ `FLUTTER_SETUP_WINDOWS.md` - Flutter环境配置指南
- ✅ `build_android.bat` - 自动化构建脚本

#### 3. Git提交
- ✅ 所有配置已提交到本地仓库
- ⏳ 正在推送到GitHub远程仓库

---

## 阻碍因素

### 主要问题：Flutter SDK未在PATH中

**现象**: 
- 执行 `flutter --version` 返回 "command not found"
- 无法直接执行构建命令

**原因**:
- Flutter SDK未安装，或
- Flutter SDK已安装但未添加到系统PATH环境变量

**影响**:
- 无法自动执行 `flutter build apk` 命令
- 需要用户手动配置环境后才能继续

---

## 解决方案

### 方案A：用户配置Flutter环境（推荐）

**步骤**:
1. 参考 `FLUTTER_SETUP_WINDOWS.md` 配置Flutter环境
2. 验证安装: `flutter --version`
3. 执行构建脚本: `build_android.bat`
4. 或手动构建: `flutter build apk --release`

**所需时间**: 约30-45分钟（首次安装）

**优点**:
- 一次配置，长期使用
- 支持后续开发和调试
- 可构建多种格式（APK、AAB）

### 方案B：使用已有Flutter环境

如果系统中已安装Flutter：

1. 找到Flutter安装目录（如 `C:\flutter`）
2. 添加到PATH: `C:\flutter\bin`
3. 重启命令提示符
4. 执行构建脚本

**所需时间**: 2-3分钟

---

## 构建命令参考

### 快速构建（自动化）
```bash
# 在项目根目录执行
.\build_android.bat
```

### 手动构建

```bash
# 进入项目目录
cd "D:\用户\16235\Desktop\文档\Agent-Working\应用程序项目\拉海洛终端"

# 获取依赖
flutter pub get

# 构建Debug版本（快速测试）
flutter build apk --debug

# 构建Release版本（正式发布）
flutter build apk --release

# 构建并按架构分包（最小体积）
flutter build apk --release --split-per-abi
```

### 输出文件位置

**Debug APK**: 
```
build/app/outputs/flutter-apk/app-debug.apk
```

**Release APK**:
```
build/app/outputs/flutter-apk/app-release.apk
```

**分包APK**:
```
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk  (推荐，64位)
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk  (32位)
build/app/outputs/flutter-apk/app-x86_64-release.apk  (模拟器)
```

---

## 项目技术栈

### 核心框架
- **Flutter**: 3.44+
- **Dart**: 3.12+

### 关键依赖
- `video_player`: Android视频播放（需要INTERNET权限）
- `path_provider`: 本地存储路径
- `dio`: 网络请求（资源下载）
- `hive`: 本地数据库
- `file_picker`: 文件选择（UGC剧本）
- `url_launcher`: 外部链接

### Android特定配置
- **minSdk**: 由Flutter决定（通常API 21，Android 5.0）
- **targetSdk**: 由Flutter决定（通常最新稳定版）
- **Java版本**: 17
- **Kotlin**: 支持

---

## 验证测试清单

APK构建完成后，需要在真机或模拟器上验证：

### 基础功能
- [ ] 应用正常安装
- [ ] 启动无崩溃
- [ ] 开机动画播放
- [ ] 新手引导显示

### 网络功能（需联网）
- [ ] 资源自动下载
- [ ] 图鉴数据同步
- [ ] 势力档案加载
- [ ] 图片缓存

### 核心功能
- [ ] 飞讯系统交互
- [ ] 图鉴浏览（共鸣者/武器/声骸）
- [ ] 成就系统
- [ ] 全局搜索
- [ ] 主题切换
- [ ] 个人信息

### UGC功能
- [ ] 剧本创作
- [ ] 剧本导出（文件选择器）
- [ ] 剧本导入

### 稳定性
- [ ] 横竖屏切换正常
- [ ] 应用退出后数据保持
- [ ] 离线模式（断网后仍可用已缓存内容）
- [ ] 多次启动无异常

---

## 已知限制

### 平台支持
- ✅ **Windows**: 已构建并测试
- ⏳ **Android**: 配置已完成，等待构建
- ⏳ **Linux**: 代码已准备，需Linux环境

### 内容限制
- 飞讯剧本：占位内容，非游戏真实剧情
- 好感度系统：代码已实现，但无实际使用场景
- 资源文件：首次运行需联网下载（约50-100MB）

### 构建工具
- 需要Flutter SDK 3.44+
- 需要Android SDK Platform 34+
- 首次构建需下载Gradle和依赖（可能较慢）

---

## 发布准备

### GitHub Release

当APK构建完成后：

1. **文件命名**: `拉海洛终端_v1.3_Android.apk`

2. **计算校验和**:
```bash
certutil -hashfile app-release.apk SHA256
```

3. **上传到Release**:
   - 访问: https://github.com/young0081/rahero-terminal/releases
   - 创建新Release或编辑v1.3.0
   - 上传APK文件
   - 在说明中添加SHA256

4. **Release说明添加**:
```markdown
### Android版本 (新增)

- 文件: 拉海洛终端_v1.3_Android.apk
- 大小: ~XX MB
- 支持: Android 5.0+ (API 21+)
- SHA256: [校验和]

**安装说明**:
1. 下载APK文件
2. 在Android设备上启用"未知来源"安装
3. 打开APK文件安装
4. 首次运行需联网下载资源（约50-100MB）
```

---

## 下一步行动

### 立即执行（需用户操作）

1. **确认Flutter环境**
   ```bash
   flutter --version
   ```
   
   如果失败，参考 `FLUTTER_SETUP_WINDOWS.md` 配置

2. **执行构建**
   ```bash
   .\build_android.bat
   ```
   
   或
   
   ```bash
   flutter build apk --release
   ```

3. **测试APK**
   - 在Android设备上安装测试
   - 验证核心功能

4. **发布到GitHub**
   - 上传APK到Release
   - 更新README.md添加Android下载链接

### 后续优化（可选）

1. **应用图标**
   - 设计《鸣潮》风格图标
   - 生成多分辨率版本
   - 替换默认ic_launcher

2. **代码混淆**
   - 启用Proguard
   - 减小APK体积

3. **启动优化**
   - 优化启动画面
   - 减少首屏加载时间

4. **Google Play发布**（可选）
   - 配置签名
   - 构建App Bundle
   - 准备商店listing

---

## 完成标准

**Android构建任务完成的标志**:

1. ✅ 成功生成APK文件
2. ✅ APK可在Android设备上安装
3. ✅ 应用正常启动运行
4. ✅ 核心功能测试通过
5. ✅ 发布到GitHub Release

---

## 联系信息

- **GitHub仓库**: https://github.com/young0081/rahero-terminal
- **项目文档**: 见仓库中的CLAUDE.md
- **问题反馈**: GitHub Issues

---

**任务状态**: 配置已完成，等待用户配置Flutter环境后执行构建

**最后更新**: 2024-06-04
