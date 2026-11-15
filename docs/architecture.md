# Carnation 架构与示例说明

> 详细的剧本字段字典、演出动词用法与美术资产规范请参阅 **[开发与剧本编写指南 (developer-guide.md)](./developer-guide.md)**。

## 模块边界

| 模块 | 入口 | 职责 |
|---|---|---|
| 剧本数据 | `assets/scripts/ch01.yaml` | 场景、台词、选项、CG、BGM 与角色动作声明，不包含运行时代码 |
| 解析器 | `ScriptParser` / `YamlScriptParser` | YAML 到不可变模型的转换、未知字段拦截与引用闭包校验 |
| 播放器 | `NovelPlayer` / `ScriptPlayer` | 基于 `f(scene_id, lineIndex)` 计算舞台快照、多角色同台状态继承、回退、存读档与分支跳转 |
| Flutter UI | `PlayerScreen` / `M3Motion` | Galgame 毛玻璃对话框、角色名牌、立绘演出动画、历史记录、存读档与 DAG 树状流程图 |
| 资源清单 | `assets.yaml`、`characters.yaml` | 资源 ID、路径、角色显示名、主题色与默认表情 |

## 运行与调试模式

```sh
flutter pub get

# 玩家模式运行（默认，隐藏调试信息与流程图跳关）
flutter run -d linux

# 调试模式运行（开启树状流程图、行号/资源状态监视器与选项目标提示）
flutter run -d linux --dart-define=DEBUG=true
```

运行过程中也可按键盘 **`F3`** 或点击右上角模式按钮在「玩家模式」与「调试模式」之间实时切换。
