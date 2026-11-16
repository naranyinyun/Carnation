# Carnation 架构与模块说明

> 详细的剧本字段字典、演出动词用法与美术资产规范请参阅 **[开发与剧本编写指南 (developer-guide.md)](./developer-guide.md)**。

## 模块边界

| 模块 | 入口文件 | 核心职责 |
|---|---|---|
| **资源与角色管理** | `lib/assets/asset_models.dart`<br>`lib/assets/asset_catalog_loader.dart` | 解析 `assets.yaml` 与 `characters.yaml`，提供 `AssetCatalog` 与 `CharacterCatalog` 统一运行时查询，对未知资源引用抛出 `AssetLookupException`（拒绝静默降级） |
| **剧本解析与验证** | `lib/script/script_parser.dart`<br>`lib/script/script_validator.dart` | `YamlScriptParser` 负责 YAML 到不可变 AST 的转换；`ScriptValidator` 负责角色/立绘/背景/CG/音频引用校验、选项 ID 唯一性校验、DAG 无环校验与物理文件存在性校验 |
| **舞台计算与播放器** | `lib/player/stage_computer.dart`<br>`lib/player/novel_player.dart` | `StageComputer` 纯函数推导 `f(scene_id, lineIndex)` 舞台快照；`ScriptPlayer` 管理推进、回退栈、分支跳转并与 `SaveRepository` 协作 |
| **存档持久化** | `lib/player/save_repository.dart` | `SaveRepository` 接口及 `JsonFileSaveRepository` / `InMemorySaveRepository` 实现，支持跨重启恢复、JSON 版本校验及损坏/越界存档自动隔离 |
| **UI 控制器与组件** | `lib/ui/player_screen.dart`<br>`lib/ui/controller/playback_pace_controller.dart`<br>`lib/ui/stage/*` · `lib/ui/hud/*` · `lib/ui/modals/*` | `PlayerScreen` 作为主入口组装各子模块；`PlaybackPaceController` 独立管理打字机/Auto/Skip/Beat 计时；舞台、HUD、弹窗按职责拆分并通过单向数据流与回调通信 |

## 运行与测试

```sh
flutter pub get

# 静态分析与全量测试
flutter analyze
flutter test

# 玩家模式运行（默认，隐藏调试信息与流程图跳关）
flutter run -d linux

# 调试模式运行（开启树状流程图、行号/资源状态监视器与选项目标提示）
flutter run -d linux --dart-define=DEBUG=true
```
