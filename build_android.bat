@echo off
chcp 65001 >nul
echo ========================================
echo 拉海洛终端 - Android 构建脚本
echo ========================================
echo.

REM 检查Flutter是否可用
echo [1/6] 检查Flutter环境...
flutter --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ 错误: Flutter未找到或未添加到PATH
    echo.
    echo 请先安装Flutter并添加到PATH:
    echo 1. 下载: https://flutter.cn/
    echo 2. 解压到目录 (如 C:\flutter)
    echo 3. 添加到PATH: C:\flutter\bin
    echo 4. 重启命令提示符
    echo.
    pause
    exit /b 1
)
echo ✅ Flutter环境正常
echo.

REM 检查Android工具链
echo [2/6] 检查Android工具链...
flutter doctor --android-licenses >nul 2>&1
echo ✅ Android工具链检查完成
echo.

REM 获取依赖
echo [3/6] 获取Flutter依赖...
flutter pub get
if %errorlevel% neq 0 (
    echo ❌ 依赖获取失败
    pause
    exit /b 1
)
echo ✅ 依赖获取完成
echo.

REM 清理旧构建
echo [4/6] 清理旧构建文件...
if exist build\app\outputs\flutter-apk\*.apk (
    del /q build\app\outputs\flutter-apk\*.apk
)
echo ✅ 清理完成
echo.

REM 构建APK
echo [5/6] 构建Android APK...
echo 请选择构建类型:
echo 1. Debug (快速测试，体积较大)
echo 2. Release (正式发布，体积优化)
echo 3. Release + 分架构 (最小体积)
echo.
set /p BUILD_TYPE="请输入选项 (1-3): "

if "%BUILD_TYPE%"=="1" (
    echo 构建Debug版本...
    flutter build apk --debug
    set OUTPUT_FILE=app-debug.apk
) else if "%BUILD_TYPE%"=="2" (
    echo 构建Release版本...
    flutter build apk --release
    set OUTPUT_FILE=app-release.apk
) else if "%BUILD_TYPE%"=="3" (
    echo 构建Release版本 (分架构)...
    flutter build apk --release --split-per-abi
    set OUTPUT_FILE=app-arm64-v8a-release.apk
) else (
    echo ❌ 无效选项
    pause
    exit /b 1
)

if %errorlevel% neq 0 (
    echo ❌ 构建失败
    pause
    exit /b 1
)
echo ✅ 构建完成
echo.

REM 显示结果
echo [6/6] 构建完成!
echo.
echo ========================================
echo 输出文件位置:
echo ========================================
if "%BUILD_TYPE%"=="3" (
    echo 📦 ARM64 (64位，推荐): build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
    echo 📦 ARMv7 (32位): build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk
    echo 📦 x86_64 (模拟器): build\app\outputs\flutter-apk\app-x86_64-release.apk
) else (
    echo 📦 APK文件: build\app\outputs\flutter-apk\%OUTPUT_FILE%
)
echo.

REM 计算文件大小
for %%F in (build\app\outputs\flutter-apk\*.apk) do (
    set SIZE=%%~zF
    set /a SIZE_MB=!SIZE! / 1048576
    echo 📊 %%~nxF: !SIZE_MB! MB
)
echo.

REM 提示安装
echo ========================================
echo 下一步:
echo ========================================
echo 1. 在Android设备上启用USB调试
echo 2. 连接设备到电脑
echo 3. 运行: flutter install
echo 4. 或直接将APK拖到设备上安装
echo.
echo 按任意键打开输出目录...
pause >nul
explorer build\app\outputs\flutter-apk
