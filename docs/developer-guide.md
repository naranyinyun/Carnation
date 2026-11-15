# Carnation 视觉小说引擎开发与剧本编写指南

本文档面向剧本作者、美术与引擎开发者，详细说明 **Carnation** 当前已实现的全部剧本字段用法、演出语义、资产形式规范以及播放器运行机制（基于根目录 [vn-script-spec.md](../vn-script-spec.md) 规范落地实现）。

---

## 1. 目录结构与模块划分

```text
Carnation/
├── assets.yaml                  # 全局资产登记表（资源 ID → 文件路径）
├── characters.yaml              # 全局角色定义表（角色 ID、显示名、主题色、默认表情）
├── vn-script-spec.md            # 视觉小说脚本格式规范原始设计文档
├── assets/
│   ├── scripts/
│   │   └── ch01.yaml            # 章节剧本文件（含场景、台词、演出与分支）
│   ├── backgrounds/             # 场景背景图资源（1600×900）
│   ├── characters/              # 角色立绘资源（500×1000，按 <角色>_<表情>.svg 命名）
│   └── cg/                      # 全屏事件插图 CG（1600×900）
└── lib/
    ├── main.dart                # 应用入口、启动参数解析（玩家版 / 调试版）
    ├── script/
    │   ├── script_models.dart   # 不可变剧本 AST 与舞台演出模型
    │   └── script_parser.dart   # YAML 解析器与编译期结构/引用校验
    ├── player/
    │   └── novel_player.dart    # 状态机播放器（f(scene_id, lineIndex) 确定性重放）
    └── ui/
        ├── motion.dart          # Material Design 3 缓动曲线与过渡构建器
        └── player_screen.dart   # Galgame 舞台、毛玻璃对话框、存读档与树状流程图
```

---

## 2. 资产形式与美术规范 (`assets.yaml`)

剧本中**绝不直接出现文件路径**，所有背景、立绘、CG、音乐和语音均通过资源 ID 引用，并在根目录 `assets.yaml` 中集中登记。

### 2.1 `assets.yaml` 结构示例

```yaml
background:
  classroom_noon: assets/backgrounds/classroom_noon.svg
  classroom_dusk: assets/backgrounds/classroom_dusk.svg
  classroom_dusk_rain: assets/backgrounds/classroom_dusk_rain.svg
  rooftop_night: assets/backgrounds/rooftop_night.svg
  rooftop_night_rain: assets/backgrounds/rooftop_night_rain.svg
  hallway_night: assets/backgrounds/hallway_night.svg
  gate_night: assets/backgrounds/gate_night.svg

sprite:
  lin:
    neutral: assets/characters/lin_neutral.svg
    smile: assets/characters/lin_smile.svg
    away: assets/characters/lin_away.svg
    surprised: assets/characters/lin_surprised.svg
  zhou:
    neutral: assets/characters/zhou_neutral.svg
    laugh: assets/characters/zhou_laugh.svg
    serious: assets/characters/zhou_serious.svg
    surprised: assets/characters/zhou_surprised.svg

cg:
  after_rain: assets/cg/after_rain.svg

bgm:
  after_school: audio/bgm/after_school.ogg
  rain_light: audio/bgm/rain_light.ogg
  rain_loop: audio/bgm/rain_loop.ogg
  hallway_quiet: audio/bgm/hallway_quiet.ogg

voice:
  lin_001: audio/voice/lin_001.ogg
  zhou_001: audio/voice/zhou_001.ogg
```

### 2.2 五类资产形式与画布约定

| 资产类型 | 命名空间 | 画布尺寸 / 比例约定 | 渲染与对齐规则 |
| :--- | :--- | :--- | :--- |
| **`background`**（背景） | 全局唯一 | 推荐 `1600×900`（16:9） | 永远铺满全屏（`BoxFit.cover`），无锚点偏移。 |
| **`sprite`**（角色立绘） | 按角色分组（`sprite.<角色ID>.<表情ID>`） | 推荐 `500×1000`（1:2 竖向全身画布） | **1. 同角色所有表情必须共用同一画布尺寸；**<br>**2. 人物脚底贴画布下边缘，水平居中；**<br>**3. 同一 DPI 导出**（身高差直接体现在画布留白上）。默认锚点 `{x: 0.5, y: 1.0}`。 |
| **`cg`**（事件插图） | 全局唯一 | 推荐 `1600×900`（16:9） | 全屏叠加在背景与角色立绘之上（`BoxFit.cover`），出现后持续保持，直至显式声明 `cg: null` 收回。 |
| **`bgm`**（背景音乐） | 全局唯一 | 统一使用 `.ogg`（Ogg Vorbis） | 场景级或行内 `stage` 触发切换；设为 `null` 时停止播放。 |
| **`voice`**（角色语音） | 全局唯一 | 统一使用 `.ogg`（Ogg Vorbis） | 仅非旁白行可用，随台词行触发。 |

> **当前工程资源格式说明**：示例工程使用轻量级原生矢量 `.svg`（通过 `flutter_svg` 渲染）存放于 `assets/backgrounds/`、`assets/characters/` 与 `assets/cg/` 下，文件命名遵循 `<characterId>_<spriteId>.svg`（如 `lin_smile.svg`）。生产环境也可按规范扩展为透明通道 `.webp` / `.avif`。

---

## 3. 角色定义规范 (`characters.yaml`)

`characters.yaml` 用于定义角色的显示名称、UI 主题色与初始默认表情：

```yaml
characters:
  lin:
    name: 林
    color: "#7bb0ff"
    default_sprite: neutral
  zhou:
    name: 周
    color: "#ffb86c"
    default_sprite: neutral
```

| 字段 | 必填 | 类型 | 说明 |
| :--- | :---: | :---: | :--- |
| `<角色ID>` | 是 | `string` | 全局唯一短名（如 `lin`、`zhou`）。不可使用保留字 `narrator` 或 `options`。 |
| `name` | 是 | `string` | 对话框名牌与历史记录中展示的角色名称（如 `林`）。 |
| `color` | 否 | `string` | 十六进制颜色值（如 `"#7bb0ff"`），用于角色名牌圆点、边框高光与光标着色。 |
| `default_sprite` | 是 | `string` | 角色在场景中首次出场且未显式指定 `sprite` 时使用的默认表情 ID。 |

- **保留角色 `narrator`**：代表旁白，无需在 `characters.yaml` 中声明，名牌显示为“旁白”，不可配置 `sprite`、`at`、`voice` 或角色 `animation`。

---

## 4. 剧本字段完整参考 (`assets/scripts/*.yaml`)

每个剧本文件顶层仅包含一个键：`scenes`（有序场景列表）。未知字段在解析期会直接抛出 `FormatException` 报错，防止拼写错误静默失效。

### 4.1 场景级字段 (`scene`)

```yaml
scenes:
  - id: ch01.classroom
    backgrounds: [classroom_noon, classroom_dusk, classroom_dusk_rain]
    initial: classroom_noon
    bgm: after_school
    enter: fade
    start: true
    end: false
    dialog:
      d001:
        ...
```

| 字段 | 必填 | 类型 | 缺省值 | 用法与约束说明 |
| :--- | :---: | :---: | :---: | :--- |
| **`id`** | 是 | `string` | — | 场景全局唯一标识（推荐 `<章节>.<场景名>`，如 `ch01.classroom`）。 |
| **`backgrounds`** | 是 | `list<string>` | — | **本场景允许使用的背景 ID 白名单**。本场景内所有 `stage.background` 必须属于此列表，否则解析报错。 |
| **`initial`** | 是 | `string` | — | 进入本场景时的初始背景 ID，必须包含在 `backgrounds` 列表中。 |
| **`bgm`** | 否 | `string \| null` | `null` | 进入本场景时的初始背景音乐 ID；写 `null` 表示静音。 |
| **`enter`** | 否 | `enum` | `cut` | 进入本场景时的画面转场方式，可选：`cut`（直切）、`fade`（黑场淡入）、`crossfade`（交叉叠化）。 |
| **`start`** | 否 | `bool` | `false` | 标记整部作品的唯一入口场景。**全剧本必须且只能有一个场景声明 `start: true`**。 |
| **`end`** | 否 | `bool` | `false` | 标记是否为结局终止场景。若 `end: false` 且最后一行无 `options`，播放完后自动顺序进入 `scenes` 列表中的下一个场景。 |
| **`dialog`** | 是 | `map` | — | 有序台词行字典，按 YAML 书写顺序从上到下依次执行。 |

---

### 4.2 台词行字段 (`dialog.<行ID>`)

每一行台词由**行 ID**（如 `d001`，场景内唯一）索引，内部包含**唯一一个说话人选择器**（角色 ID 或 `narrator`）以及可选的同级分支字段 `options`：

```yaml
      d002:
        zhou:
          sprite: laugh
          at: {x: 0.76, y: 1.0}
          animation:
            - enter: {from: right}
          say: "喂，值日早就做完了，你还没走啊？"
          voice: zhou_001
```

#### 说话人行内字段表

| 字段 | 必填 | 类型 | 适用对象 | 用法与说明 |
| :--- | :---: | :---: | :---: | :--- |
| **`say`** | 是 | `string` | 全部 | 台词正文。支持双引号内 `\n` 换行或 YAML `\|` 多行块标量。若设为空字符串 `""` 且配合 `pause`，则作为**无文本演出节拍**。 |
| **`sprite`** | 否 | `string` | 仅角色 | 角色表情 ID（如 `neutral`、`smile`、`away`、`surprised`、`laugh`、`serious`）。**省略时自动沿用该角色在本场景上一行的表情**。 |
| **`at`** | 否 | `{x, y}` | 仅角色 | 角色立绘锚点在屏幕中的归一化坐标（`0.0 ~ 1.0`）。`x: 0` 为最左、`x: 1` 为最右、`y: 1` 为贴底。**省略时沿用该角色在本场景上一行的位置**；首次出场缺省为 `{x: 0.5, y: 1.0}`。 |
| **`voice`** | 否 | `string` | 仅角色 | 语音资源 ID（如 `lin_001`）。 |
| **`pause`** | 否 | `number` | 全部 | 停顿秒数（如 `0.9`）。当 `say: ""` 时生效：自动隐藏对话框，执行完本行舞台/角色动画后等待 `pause` 秒自动进入下一行。 |
| **`stage`** | 否 | `object` | 全部 | 舞台环境变更（换背景、弹 CG、换 BGM、设转场），详见 4.3。 |
| **`animation`** | 否 | `list` | 仅角色 | 作用于当前说话角色的动作列表，详见 4.4。 |

---

### 4.3 舞台控制字段 (`stage`)

`stage` 先于本行文本生效，用于切换背景、显示/收回全屏 CG 或切换 BGM：

```yaml
      d006:
        narrator:
          say: "第一滴雨敲在玻璃上，紧接着连成一片细密的声响。"
          stage:
            background: classroom_dusk_rain
            bgm: rain_light
            cg: null
            transition: crossfade
```

| 字段 | 必填 | 类型 | 用法与说明 |
| :--- | :---: | :---: | :--- |
| **`background`** | 否 | `string` | 切换当前背景，目标 ID **必须已在本场景 `backgrounds` 列表中声明**。 |
| **`cg`** | 否 | `string \| null` | 传入 CG ID（如 `after_rain`）时全屏弹出事件插图并持续保持；传入 `null`（`stage: {cg: null}`）时收回 CG，恢复显示底层场景背景与立绘。 |
| **`bgm`** | 否 | `string \| null` | 传入音乐 ID 时切换 BGM；显式传入 `null`（`stage: {bgm: null}`）时停止当前 BGM。 |
| **`transition`** | 否 | `enum` | 背景切换转场风格：`cut`（120ms 快切，默认）、`crossfade`（520ms 交叉淡化）、`fade`（620ms 渐隐渐显）。 |

---

### 4.4 角色演出动画动词表 (`animation`)

`animation` 是一个有序列表，只作用于当前行的说话角色。引擎内置 6 个标准动词：

```yaml
      # 示例 1：从右侧进场并惊跳
      animation:
        - enter: {from: right}
        - jump: {}

      # 示例 2：场内移动至新坐标
      animation:
        - move: {to: {x: 0.56, y: 1.0}}

      # 示例 3：慢速向左离场
      animation:
        - exit: {to: left, style: slow}
```

| 类别 | 动词 | 参数 | 视觉效果与状态影响 |
| :--- | :--- | :--- | :--- |
| **位移类** | **`enter`** | `from`: `left` \| `right` \| `front`<br>`style`: `fast` \| `slow`（可选） | 角色从左侧、右侧滑入或从前景浮现进场，终点为本行的 `at` 坐标。 |
| **位移类** | **`move`** | `to`: `{x: <0..1>, y: <0..1>}`<br>`style`: `fast` \| `slow`（可选） | 角色在场内平滑移动至目标归一化坐标，并**同步更新该角色的在场位置状态**。 |
| **位移类** | **`exit`** | `to`: `left` \| `right` \| `back`<br>`style`: `fast` \| `slow`（可选） | 角色向指定方向滑出并淡出退场。**本行结束后，该角色从舞台移除**（不再显示在后续行中，直至再次发言出场）。 |
| **表演类** | **`nod`** | `style`: `fast` \| `slow`（可选） | 角色纵向轻轻点头一次，不改变坐标。 |
| **表演类** | **`shake`** | `style`: `fast` \| `slow`（可选） | 角色水平摇头/颤动，不改变坐标。 |
| **表演类** | **`jump`** | `style`: `fast` \| `slow`（可选） | 角色向上惊吓跳起后落回原位，不改变坐标。 |

- **时长修饰符 `style`**：不写数值毫秒，默认标准时长 `500ms`；`style: fast` 为 `320ms`，`style: slow` 为 `760ms`。

---

### 4.5 分支选项字段 (`options`)

`options` 与说话人选择器同级，用于跳转到不同目标场景：

```yaml
      d005:
        zhou:
          sprite: laugh
          say: "那，明天见？"
        options:
          - id: call
            say: "「等一下——我们一起走吧。」"
            to: ch01.gate_call
          - id: quiet
            say: "「嗯，明天教室见。」（目送他离开）"
            to: ch01.gate_quiet
```

**编译期强约束**：
1. 带 `options` 的行**必须是所在场景的最后一行**（否则其后的行永远无法到达，解析器直接报错）。
2. 每个选项必须包含 `id`（场景内唯一）、`say`（按钮显示文本）和 `to`（目标 `scene.id`，必须存在于剧本中）。
3. 选择选项后进入目标场景，**原场景的所有角色在场状态、表情与位置自动清空（R7）**。

---

## 5. 运行时机制与 UI 功能说明

### 5.1 确定性状态模型 `f(scene_id, lineIndex)`
引擎遵循纯声明式无状态设计：任意时刻的舞台画面（当前背景、当前 BGM、当前叠加 CG、场上所有角色的表情/坐标/发言聚光状态）完全由 `(sceneIndex, lineIndex)` 唯一决定：
- **多角色同台与聚光**：同一场景中已出场且未 `exit` 的角色会同时保留在舞台上；当前行发言角色以 `100%` 亮度、`1.02x` 比例置顶显示，非发言角色自动压暗至 `72%` 透明度并退至 `0.96x`。
- **回退（Rollback）与历史记录跳转**：点击底部 `回退` 或在 `历史记录` 中点击任意历史台词，播放器直接重算目标 `(sceneIndex, lineIndex)` 的完整舞台快照，不会出现“文字退回了但背景/立绘没退回”的状态撕裂。
- **存取档（Save / Load）**：每个存档位仅需记录 `(sceneIndex, lineIndex)` 与预览摘要，读取时即可 100% 还原当时画面。

### 5.2 玩家版与调试版切换

由于调试功能（流程图自由跳关、行号/资源 ID 检视、选项目标剧透）不应直接暴露给普通玩家，应用支持通过**启动参数**或**快捷键**切换模式：

| 方式 | 命令 / 操作 | 说明 |
| :--- | :--- | :--- |
| **默认启动（玩家版）** | `flutter run` | 纯净 Galgame 界面：隐藏所有内部 ID、动作标签、选项目标剧透与流程图入口。 |
| **编译期参数启动（调试版）** | `flutter run --dart-define=DEBUG=true` | 启动即默认进入调试模式。 |
| **命令行参数启动（调试版）** | `flutter run -a --debug`（或 `-d`） | 通过可执行文件参数开启调试模式。 |
| **运行时热切换** | 按键盘 `F3` 或点击右上角 `玩家 / 调试` 按钮 | 开发测试期间可随时在两种模式间切换对比。 |

### 5.3 快捷键一览

| 按键 | 功能 |
| :--- | :--- |
| `Space` / `Enter` / `→` / 鼠标左键 | 打字未完成时立即补全整句；打字完成后推进下一行 |
| `←` / `Backspace` | 回退到上一句台词（支持跨场景回退） |
| `A` | 切换自动播放（Auto） |
| `L` | 打开历史记录（Backlog） |
| `H` / 鼠标右键 | 隐藏 / 显示全部 UI（纯画面与 CG 鉴赏模式） |
| `F3` | 切换 `玩家模式` / `调试模式`（开启树状流程图与舞台状态监视器） |
