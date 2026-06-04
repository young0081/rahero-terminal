# 贡献指南

感谢你对拉海洛终端项目的关注！我们欢迎任何形式的贡献。

---

## 🤝 如何贡献

### 报告问题
发现bug或有功能建议？请通过以下方式告诉我们：

1. 访问 [Issues](https://github.com/young0081/rahero-terminal/issues)
2. 点击 "New Issue"
3. 选择合适的模板（Bug Report / Feature Request）
4. 填写详细信息
5. 提交

**好的问题报告应该包含**：
- 清晰的标题
- 详细的描述
- 复现步骤（如果是bug）
- 预期行为 vs 实际行为
- 系统环境（Windows版本、Flutter版本等）
- 截图或日志（如果有）

---

### 提交代码

#### 准备工作

1. **Fork仓库**
   - 点击右上角的 "Fork" 按钮
   - 将仓库fork到你的账号下

2. **克隆到本地**
   ```bash
   git clone https://github.com/你的用户名/rahero-terminal.git
   cd rahero-terminal
   ```

3. **安装依赖**
   ```bash
   flutter pub get
   ```

4. **创建分支**
   ```bash
   git checkout -b feature/你的功能名称
   # 或
   git checkout -b fix/你修复的问题
   ```

#### 开发流程

1. **编写代码**
   - 遵循Dart代码规范
   - 保持代码清晰易读
   - 添加必要的注释

2. **测试**
   ```bash
   # 运行测试
   flutter test
   
   # 静态分析
   dart analyze
   
   # 运行应用验证
   flutter run -d windows
   ```

3. **提交更改**
   ```bash
   git add .
   git commit -m "feat: 添加XXX功能"
   ```

4. **推送到GitHub**
   ```bash
   git push origin feature/你的功能名称
   ```

5. **创建Pull Request**
   - 访问你fork的仓库页面
   - 点击 "Pull Request"
   - 填写PR描述
   - 提交

---

## 📝 代码规范

### 提交信息格式

使用 [Conventional Commits](https://www.conventionalcommits.org/) 规范：

```
<类型>: <描述>

[可选的正文]

[可选的脚注]
```

**类型**：
- `feat`: 新功能
- `fix`: 修复bug
- `docs`: 文档更新
- `style`: 代码格式（不影响功能）
- `refactor`: 代码重构
- `perf`: 性能优化
- `test`: 测试相关
- `chore`: 构建/工具相关

**示例**：
```
feat: 添加角色语音播放功能

- 解析audio-component
- 支持按分类列出语音
- 点击播放.wav文件
- 添加台词文本显示

Closes #123
```

### Dart代码风格

遵循 [Dart官方风格指南](https://dart.dev/guides/language/effective-dart)：

```dart
// ✅ 好的
class CodexService {
  Future<List<Character>> fetchCharacters() async {
    // 实现
  }
}

// ❌ 不好的
class codex_service {
  Future<List<Character>> FetchCharacters() async {
    // 实现
  }
}
```

**关键点**：
- 类名使用大驼峰 `UpperCamelCase`
- 变量/函数使用小驼峰 `lowerCamelCase`
- 常量使用小驼峰 `lowerCamelCase`
- 私有成员使用下划线前缀 `_privateMethod`
- 文件名使用蛇形命名 `file_name.dart`

### 项目结构约定

```
lib/
├── features/           # 按功能模块组织
│   └── codex/         # 每个模块独立
│       ├── data/      # 数据层（模型、数据源）
│       ├── providers/ # 状态管理
│       └── screens/   # 界面
├── core/              # 核心通用代码
│   ├── theme/         # 主题
│   ├── storage/       # 存储
│   └── widgets/       # 通用组件
└── router/            # 路由配置
```

---

## 🧪 测试

### 单元测试

```dart
// test/features/codex/codex_service_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CodexService', () {
    test('应该正确获取角色列表', () async {
      // 测试代码
    });
  });
}
```

### Widget测试

```dart
testWidgets('角色卡片应该显示名称', (WidgetTester tester) async {
  await tester.pumpWidget(CharacterCard(character: testCharacter));
  expect(find.text('漂泊者'), findsOneWidget);
});
```

---

## 📋 Pull Request检查清单

提交PR前请确认：

- [ ] 代码遵循项目规范
- [ ] 通过 `dart analyze`（无错误）
- [ ] 通过 `flutter test`（所有测试）
- [ ] 在Windows上测试过（如果改动涉及UI）
- [ ] 更新了相关文档
- [ ] 提交信息遵循规范
- [ ] PR描述清晰，说明了改动内容

---

## 🎯 开发建议

### 第一次贡献

推荐从简单的任务开始：

- 修复文档中的错误
- 添加单元测试
- 修复标记为 `good first issue` 的问题
- 优化现有代码

### 大功能开发

如果你想开发大功能，建议：

1. 先创建Issue讨论方案
2. 等待维护者反馈
3. 达成一致后再开始编码
4. 开发过程中保持沟通

### 代码审查

- 所有PR都需要代码审查
- 维护者可能会提出修改建议
- 请耐心回复并修改
- 审查通过后会合并

---

## 📞 联系方式

- **GitHub Issues**: [提问题](https://github.com/young0081/rahero-terminal/issues)
- **GitHub Discussions**: [讨论功能](https://github.com/young0081/rahero-terminal/discussions)

---

## 🙏 致谢

感谢每一位贡献者！你们的参与让这个项目变得更好。

<div align="center">

**Happy Coding! 🎉**

</div>
