# Android 构建完整指南

## 当前状态

- ✅ Android Release APK 已成功构建
- 发布文件名：`拉海洛终端_v1.3_Android.apk`
- 桌面分发路径：`D:\用户\16235\Desktop\拉海洛终端_v1.3_Android.apk`
- SHA256：`DB391A61720C02038B8614C4C59D51814FF2C95871E3CA81461F2E8C6632A061`
- 当前限制：受 `file_picker` 兼容性影响，头像上传与 UGC 导入/导出暂不可用

---

## 前提条件

### 1. Flutter SDK
- 版本：Flutter 3.44+ (Dart 3.12+)
- 下载：https://docs.flutter.dev/get-started/install/windows
- 国内镜像设置：
```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

### 2. Android 工具链
- Android Studio 或 Android SDK
- Java JDK 17+
- Android SDK Platform 34+
- Android Build Tools

---

## 已完成的配置

### ✅ AndroidManifest.xml 权限配置
已添加必要权限：
- `INTERNET` - 资源下载、图鉴数据同步
- `WRITE_EXTERNAL_STORAGE` - 缓存下载的资源文件（Android 12及以下）
- `READ_EXTERNAL_STORAGE` - 读取缓存资源（Android 12及以下）

### ✅ 应用基本信息
- **应用名称**: 拉海洛终端
- **包名**: `com.starforge.rahero_terminal`
- **最小SDK**: 由Flutter配置决定（通常为API 21）
- **目标SDK**: 由Flutter配置决定（通常为最新稳定版）

### ✅ 依赖配置
- video_player: 视频播放（Android原生支持）
- path_provider: 本地存储
- dio: 网络请求
- url_launcher: 外部链接跳转
- file_picker: 已临时禁用，等待兼容性修复后恢复

---

## 构建步骤

> Windows 中文路径下构建可能失败。建议先复制到 `D:\temp_build\rahero_terminal` 这类纯英文路径，再执行下述命令。

### 方式1：直接构建APK（推荐）

```bash
# 进入项目目录
cd "D:/用户/16235/Desktop/文档/Agent-Working/应用程序项目/拉海洛终端"

# 设置国内镜像（可选，加速下载）
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# 获取依赖
flutter pub get

# 构建APK（debug版本，快速测试）
flutter build apk --debug

# 构建APK（release版本，正式发布）
flutter build apk --release

# 构建App Bundle（Google Play发布格式）
flutter build appbundle --release
```

### 方式2：连接设备运行

```bash
# 查看连接的设备
flutter devices

# 在连接的Android设备上运行
flutter run -d <设备ID>

# 或直接运行（如果只有一个设备）
flutter run
```

---

## 输出文件位置

### APK文件
- **Debug版本**: `build/app/outputs/flutter-apk/app-debug.apk`
- **Release版本**: `build/app/outputs/flutter-apk/app-release.apk`

### App Bundle
- **Release版本**: `build/app/outputs/bundle/release/app-release.aab`

---

## 签名配置（正式发布需要）

### 1. 创建密钥库

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

### 2. 创建 key.properties

在 `android/key.properties` 文件中：
```properties
storePassword=<密钥库密码>
keyPassword=<密钥密码>
keyAlias=upload
storeFile=<密钥库文件路径>
```

### 3. 修改 build.gradle.kts

在 `android/app/build.gradle.kts` 中添加签名配置：

```kotlin
// 在 android { 之前添加
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ...
    
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

---

## 常见问题

### 1. Gradle下载慢
**解决方案**：使用国内镜像

编辑 `android/build.gradle`：
```gradle
repositories {
    maven { url 'https://maven.aliyun.com/repository/google' }
    maven { url 'https://maven.aliyun.com/repository/jcenter' }
    maven { url 'https://maven.aliyun.com/repository/public' }
    google()
    mavenCentral()
}
```

### 2. 编译内存不足
**解决方案**：增加Gradle内存

编辑 `android/gradle.properties`：
```properties
org.gradle.jvmargs=-Xmx4096m
```

### 3. minSdkVersion错误
**原因**：某些插件需要较高的最低SDK版本

**解决方案**：检查 `android/app/build.gradle.kts` 确保 minSdk 合适

### 4. 网络权限缺失
**已解决**：AndroidManifest.xml 已添加 INTERNET 权限

---

## 测试清单

构建完成后，在真机/模拟器上测试：

- [ ] 应用正常安装和启动
- [ ] 开机动画播放
- [ ] 资源自动下载（需要网络）
- [ ] 图鉴数据加载
- [ ] 飞讯系统交互
- [ ] 势力档案查看
- [ ] 成就系统解锁
- [ ] 主题切换
- [ ] 横竖屏切换
- [ ] UGC剧本创作、导出、导入
- [ ] 应用退出和重新打开（状态保持）

---

## Android特定优化

### 启用Proguard混淆（减小APK体积）

编辑 `android/app/build.gradle.kts`：
```kotlin
buildTypes {
    release {
        minifyEnabled true
        shrinkResources true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

### 配置应用图标

替换以下文件中的图标：
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`

---

## 下一步

1. **按需复现构建**：重新运行 `flutter build apk --release`
2. **继续功能收尾**：修复 `file_picker` 兼容性，恢复头像上传与UGC导入导出
3. **生成图标**：制作《鸣潮》风格的应用图标
4. **优化体积**：启用代码混淆和资源压缩
5. **发布准备**：配置签名、生成App Bundle

---

**当前状态**：Android Release APK 已完成构建，可直接分发或按本文流程复现 ✅
