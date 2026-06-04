# Flutter环境快速配置指南（Windows）

## 方式一：自动安装（推荐）

### 使用 Chocolatey 包管理器

1. **安装Chocolatey**（如果未安装）

以管理员身份打开PowerShell，执行：
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

2. **安装Flutter**

```powershell
choco install flutter
```

3. **验证安装**

重启命令提示符，执行：
```bash
flutter --version
flutter doctor
```

---

## 方式二：手动安装

### 步骤1：下载Flutter SDK

**国内用户（推荐）**：
- 网址：https://flutter.cn/docs/get-started/install/windows
- 直接下载：https://storage.flutter-io.cn/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip

**国际用户**：
- 网址：https://docs.flutter.dev/get-started/install/windows
- 直接下载：https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip

### 步骤2：解压

1. 解压ZIP文件到 `C:\flutter` 或其他位置
2. **不要**放在 `C:\Program Files\` 下（需要管理员权限）

### 步骤3：配置环境变量

**方式A：通过系统设置**

1. 按 `Win + X`，选择"系统"
2. 点击"高级系统设置"
3. 点击"环境变量"
4. 在"用户变量"中找到 `Path`，点击"编辑"
5. 点击"新建"，添加：`C:\flutter\bin`
6. 点击"确定"保存

**方式B：通过命令行**

以管理员身份打开命令提示符：
```cmd
setx PATH "%PATH%;C:\flutter\bin"
```

### 步骤4：配置国内镜像（可选，加速下载）

在命令提示符或PowerShell中执行：
```cmd
setx PUB_HOSTED_URL https://pub.flutter-io.cn
setx FLUTTER_STORAGE_BASE_URL https://storage.flutter-io.cn
```

### 步骤5：验证安装

**重启命令提示符**（重要！），然后执行：
```bash
flutter --version
flutter doctor -v
```

应该看到类似输出：
```
Flutter 3.24.5 • channel stable
Tools • Dart 3.12.0 • DevTools 2.37.3
```

---

## 方式三：使用现有安装

如果你已经安装过Flutter但命令找不到：

1. **查找Flutter位置**

在文件资源管理器中搜索 `flutter.bat`

2. **添加到PATH**

假设找到位置为 `D:\development\flutter\bin`，执行：
```cmd
setx PATH "%PATH%;D:\development\flutter\bin"
```

3. **重启命令提示符并验证**

```bash
flutter --version
```

---

## Android工具链配置

### 选项1：安装Android Studio（推荐）

1. **下载Android Studio**
   - 官网：https://developer.android.com/studio
   - 国内：https://developer.android.google.cn/studio

2. **安装并打开Android Studio**

3. **安装SDK组件**
   - Tools → SDK Manager
   - 勾选：
     - Android SDK Platform 34
     - Android SDK Build-Tools
     - Android SDK Command-line Tools
     - Android Emulator

4. **接受许可协议**

在命令提示符中执行：
```bash
flutter doctor --android-licenses
```

一路输入 `y` 接受所有协议

### 选项2：仅安装SDK命令行工具

1. **下载SDK工具**
   - https://developer.android.com/studio#command-line-tools-only

2. **解压到目录**（如 `C:\Android\cmdline-tools`）

3. **设置环境变量**
   ```cmd
   setx ANDROID_HOME C:\Android
   setx PATH "%PATH%;%ANDROID_HOME%\cmdline-tools\latest\bin;%ANDROID_HOME%\platform-tools"
   ```

4. **安装必要组件**
   ```bash
   sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
   ```

---

## 验证完整环境

执行完整检查：
```bash
flutter doctor -v
```

理想输出：
```
[✓] Flutter (Channel stable, 3.24.5)
[✓] Windows Version (Installed version of Windows is version 10 or higher)
[✓] Android toolchain - develop for Android devices (Android SDK version 34.0.0)
[✓] Android Studio (version 2024.1)
[✓] VS Code (version 1.95.0)
[✓] Connected device (1 available)
[✓] Network resources
```

**注意**：以下项目可以忽略：
- `[!] Chrome` - 本项目不支持Web
- `[!] HTTP Host Availability` - 国内网络可忽略

---

## 常见问题

### 问题1：`flutter` 不是内部或外部命令

**原因**：PATH未配置或未重启命令提示符

**解决**：
1. 确认Flutter已添加到PATH
2. **重启命令提示符**（重要！）
3. 如果仍不行，重启电脑

### 问题2：Android licenses not accepted

**解决**：
```bash
flutter doctor --android-licenses
```
一路输入 `y`

### 问题3：Unable to find bundled Java version

**原因**：Android Studio未正确安装JDK

**解决**：
1. 打开Android Studio
2. File → Project Structure → SDK Location
3. 确认JDK路径已设置

### 问题4：网络连接问题

**症状**：下载Gradle或依赖时卡住

**解决**：
1. 确认已配置国内镜像（见步骤4）
2. 使用VPN或更换网络

### 问题5：Gradle下载慢

**解决**：手动配置Gradle镜像

编辑项目中的 `android/build.gradle`：
```gradle
repositories {
    maven { url 'https://maven.aliyun.com/repository/google' }
    maven { url 'https://maven.aliyun.com/repository/public' }
    google()
    mavenCentral()
}
```

---

## 快速测试

环境配置完成后，快速测试：

```bash
# 进入项目目录
cd "D:\用户\16235\Desktop\文档\Agent-Working\应用程序项目\拉海洛终端"

# 获取依赖
flutter pub get

# 分析代码（应该0错误）
dart analyze

# 运行测试
flutter test

# 如果有Android设备/模拟器
flutter run
```

---

## 下一步：构建Android APK

环境配置完成后，执行项目中的构建脚本：

**方式1：使用自动化脚本**
```bash
.\build_android.bat
```

**方式2：手动构建**
```bash
flutter build apk --release
```

---

## 所需时间估算

- 下载Flutter SDK: 5-10分钟（取决于网速）
- 安装Android Studio: 10-20分钟
- 配置环境变量: 2-3分钟
- 首次运行 flutter doctor: 5-10分钟（下载工具）
- **总计**: 约30-45分钟

---

## 帮助资源

- **Flutter中文网**: https://flutter.cn/
- **官方文档**: https://docs.flutter.dev/
- **Flutter中文社区**: https://flutter.cn/community
- **问题反馈**: https://github.com/flutter/flutter/issues

---

**完成配置后，返回项目目录执行 `build_android.bat` 开始构建！**
