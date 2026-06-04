# 拉海洛终端 - 打包说明

## 当前状态
Windows 桌面版与 Android 版发布包已经完成打包并验证可分发。若需要重新构建，当前项目路径包含中文字符（`拉海洛终端`），Flutter 编译器在处理时仍可能遇到路径编码问题，因此建议在纯英文临时路径下重新打包。

## 解决方案

### 方法 1：移动项目到英文路径（推荐）
1. 将项目文件夹从当前位置移动到纯英文路径，例如：
   ```
   D:\dev\rahero_terminal\
   ```

2. 在新位置打开命令行，执行：
   ```bash
   set PUB_HOSTED_URL=https://pub.flutter-io.cn
   set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
   D:\dev\flutter\bin\flutter.bat build windows --release
   ```

3. 构建完成后，产物位于：
   ```
   build\windows\x64\runner\Release\
   ```

4. 将 Release 文件夹下的所有文件复制到桌面的 `拉海洛终端` 文件夹，覆盖原有文件。

### 方法 2：使用批处理脚本自动化

创建 `build_and_deploy.bat` 文件（已生成在项目根目录）：

1. 右键点击 `build_and_deploy.bat`，选择"以管理员身份运行"
2. 脚本会自动：
   - 设置国内镜像
   - 清理旧构建
   - 执行构建
   - 复制文件到桌面

### 方法 3：在 VS Code 中构建

如果你使用 VS Code + Flutter 插件：
1. 按 `Ctrl+Shift+P`
2. 输入 `Flutter: Select Device`，选择 `Windows (desktop)`
3. 按 `Ctrl+Shift+P`，输入 `Flutter: Build Windows`
4. 等待构建完成后，手动复制文件

## 已完成的代码更新

✅ 移除 WWUID 功能
✅ 新增成就系统（15+ 个成就）
✅ 新增全局搜索功能
✅ 新增新手引导系统
✅ 新增主题切换功能（5 套预设主题）
✅ 更新所有文档

当前代码已经完成桌面版与 Android 版打包，可按本文流程重新生成发布文件。

## 桌面版本位置
D:\用户\16235\Desktop\拉海洛终端\

## 注意事项
- 中文路径问题是 Flutter 工具链的已知问题
- 建议使用英文路径存放 Flutter 项目
- 如果遇到其他问题，请查看 flutter_02.log 日志文件
