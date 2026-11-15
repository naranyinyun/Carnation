# Carnation 架构与示例说明

## 模块边界

| 模块 | 入口 | 职责 |
|---|---|---|
| 剧本数据 | `assets/scripts/ch01.yaml` | 场景、台词、选项和舞台引用，不包含运行时代码 |
| 解析器 | `ScriptParser` / `YamlScriptParser` | YAML 到不可变模型的转换、结构与引用校验 |
| 播放器 | `NovelPlayer` / `ScriptPlayer` | 当前行、顺序推进、选项跳转、结束状态 |
| Flutter UI | `PlayerScreen` | 订阅播放器状态，呈现背景、立绘、台词和选项 |
| 资源清单 | `assets.yaml`、`characters.yaml` | 资源 ID、路径、角色显示名与默认表情 |

UI 只依赖 `NovelPlayer`，不读 YAML；播放器依赖脚本模型，不依赖 Flutter；解析器不接触 UI 或播放状态。资源路径集中在 `assets.yaml`，角色表情资源按角色分组。

## 示例内容

`ch01.yaml` 是一个三场景短篇：教室场景在末尾提供两个选项，分别跳到承诺结局和沉默结局。两个结局均标记 `end: true`。默认入口是 `ch01.classroom`。示例引用两张背景、两张角色立绘和一张 CG。

示例美术是项目内原创 SVG，便于直接运行和替换。`after_school` BGM 目前仅在资源表中登记，没有随项目伪造音频文件；播放器暂未接入音频服务。

## 运行

```sh
flutter pub get
flutter run -d linux
```

可将 `linux` 替换为已配置的 `windows`、`macos`、`chrome`、`android` 或 `ios` 目标。Web 构建使用 `flutter run -d chrome`。

## 当前范围

- 已解析：scene 顺序、起始场景、行说话人/文本、sprite ID、`at`、背景变更、选项与结束场景。
- 已呈现：背景 SVG、角色 SVG、说话人名、台词、选项按钮、结束状态。
- 尚未接入：实际 BGM/语音播放、CG 持续叠加、动画播放、存档/回滚、完整 assets 文件存在性检查、流程图生成。

播放器使用场景行号推进；选择选项后进入目标场景，并沿场景列表继续执行。该实现适用于当前示例，不等同于完整规范编译器。
