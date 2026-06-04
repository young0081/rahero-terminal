# Android构建 - 执行清单（已完成）

## 当前状态

Android Release APK 已成功构建并产出，本文保留为复现构建步骤与排障清单。

## ⚠️ 前提条件检查

### 选项1：安装Flutter（如果未安装）

1. 下载Flutter SDK
   - 官方：https://docs.flutter.dev/get-started/install/windows
   - 国内镜像：https://flutter.cn/

2. 解压到目录（例如 `C:\flutter`）

3. 添加到PATH环境变量：
   ```
   C:\flutter\bin
   ```

4. 配置国内镜像（可选）：
   ```bash
   # 在命令行中执行
   setx PUB_HOSTED_URL https://pub.flutter-io.cn
   setx FLUTTER_STORAGE_BASE_URL https://storage.flutter-io.cn
   ```

5. 验证安装：
   ```bash
   flutter doctor -v
   ```

### 选项2：使用已有Flutter（如果已安装）

1. 找到Flutter安装目录
2. 将 `<Flutter目录>\bin` 添加到PATH
3. 重启终端/命令提示符
4. 验证：`flutter --version`

---

## ✅ 已完成的配置

### 1. Android权限配置
文件：`android/app/src/main/AndroidManifest.xml`

已添加：
- ✅ `INTERNET` 权限（资源下载）
- ✅ `WRITE_EXTERNAL_STORAGE` 权限（缓存存储）
- ✅ `READ_EXTERNAL_STORAGE` 权限（读取缓存）
- ✅ 应用名称改为"拉海洛终端"

### 2. 项目配置验证
- ✅ `pubspec.yaml` 依赖完整
- ✅ Android平台代码已生成
- ✅ 包名：`com.starforge.rahero_terminal`
- ✅ 所有必需插件已配置

---

## 🚀 复现构建步骤

### 步骤1：确认环境

打开命令提示符或PowerShell，执行：

```bash
# 检查Flutter
flutter --version

# 检查Android工具链
flutter doctor -v

# 应该看到：
# [✓] Flutter (Channel stable, 3.x.x)
# [✓] Android toolchain
```

### 步骤2：进入项目目录

```bash
cd "D:\用户\16235\Desktop\文档\Agent-Working\应用程序项目\拉海洛终端"
```

### 步骤3：获取依赖

```bash
flutter pub get
```

### 步骤4：构建APK

**Debug版本**（快速测试）：
```bash
flutter build apk --debug
```

**Release版本**（正式发布）：
```bash
flutter build apk --release
```

**App Bundle**（Google Play）：
```bash
flutter build appbundle --release
```

### 步骤5：找到输出文件

构建完成后，文件位置：

- **Debug APK**: 
  `build\app\outputs\flutter-apk\app-debug.apk`

- **Release APK**: 
  `build\app\outputs\flutter-apk\app-release.apk`

- **Release AAB**: 
  `build\app\outputs\bundle\release\app-release.aab`

---

## 📱 安装测试

### 在真机上安装

1. **启用开发者选项**：
   - 设置 → 关于手机 → 连续点击"版本号" 7次

2. **启用USB调试**：
   - 设置 → 开发者选项 → USB调试（开启）

3. **连接手机并安装**：
   ```bash
   flutter install
   # 或直接拖拽APK到手机安装
   ```

### 在模拟器上测试

1. **启动Android模拟器**（通过Android Studio）

2. **运行应用**：
   ```bash
   flutter run
   ```

---

## 🧪 测试清单

安装后验证以下功能：

- [ ] 应用正常启动
- [ ] 开机动画播放
- [ ] 新手引导显示
- [ ] 资源自动下载（需联网）
- [ ] 图鉴数据加载和显示
- [ ] 飞讯系统正常工作
- [ ] 势力档案查看
- [ ] 成就解锁提示
- [ ] 全局搜索
- [ ] 主题切换
- [ ] UGC剧本创作
- [ ] 横竖屏切换
- [ ] 应用退出后数据保持
- [ ] 离线模式（断网后仍可使用已缓存内容）

---

## 🔧 常见问题解决

### 问题1：Gradle下载慢

**解决**：在 `android/build.gradle` 中添加国内镜像：

```gradle
repositories {
    maven { url 'https://maven.aliyun.com/repository/google' }
    maven { url 'https://maven.aliyun.com/repository/jcenter' }
    maven { url 'https://maven.aliyun.com/repository/public' }
    google()
    mavenCentral()
}
```

### 问题2：编译内存不足

**解决**：编辑 `android/gradle.properties`：

```properties
org.gradle.jvmargs=-Xmx4096m
```

### 问题3：SDK版本不匹配

**错误信息**：`Minimum SDK version mismatch`

**解决**：确保 `android/app/build.gradle.kts` 中的 SDK 版本正确

### 问题4：签名错误（Release构建）

**临时解决**：使用 debug 签名（已配置）

**正式解决**：参考 ANDROID_BUILD.md 中的签名配置章节

---

## 📦 优化构建

### 减小APK体积

1. **启用代码混淆**

编辑 `android/app/build.gradle.kts`：

```kotlin
buildTypes {
    release {
        minifyEnabled = true
        shrinkResources = true
    }
}
```

2. **拆分APK**（按架构）

```bash
flutter build apk --split-per-abi
```

输出：
- `app-armeabi-v7a-release.apk` (~20MB，32位ARM）
- `app-arm64-v8a-release.apk` (~25MB，64位ARM，推荐）
- `app-x86_64-release.apk` (~30MB，模拟器）

### 生成应用图标

推荐工具：
- https://icon.kitchen/ （在线生成）
- Android Studio Image Asset Studio

图标尺寸：
- `mipmap-mdpi`: 48x48
- `mipmap-hdpi`: 72x72
- `mipmap-xhdpi`: 96x96
- `mipmap-xxhdpi`: 144x144
- `mipmap-xxxhdpi`: 192x192

---

## ✅ 完成标志

当以下条件满足时，Android构建即为完成：

1. ✅ 成功生成 APK 文件
2. ✅ APK 可在真机/模拟器上安装
3. ✅ 应用正常启动和运行
4. ✅ 所有核心功能正常工作
5. ✅ 无崩溃或严重错误

---

## 📤 发布准备

### GitHub Release

将生成的APK上传到GitHub Release：

1. 文件命名：`拉海洛终端_v1.3_Android.apk`
2. 计算SHA256：
   ```bash
   certutil -hashfile app-release.apk SHA256
   ```
3. 在Release说明中注明：
   - 支持的Android版本（Android 7.0+ / API 24+）
   - APK体积
   - SHA256校验和

### Google Play（可选）

使用 App Bundle 格式：
```bash
flutter build appbundle --release
```

上传 `app-release.aab` 到 Google Play Console

---

## 🎯 当前状态

- ✅ Android配置已完成
- ✅ 权限已添加
- ✅ 应用名称已修改
- ✅ Release APK 已成功生成

**下一步**：按需上传 GitHub Release，或在修复 `file_picker` 后补发恢复 UGC 文件导入/导出的 APK
