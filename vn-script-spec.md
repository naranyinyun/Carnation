# 视觉小说脚本格式规范 v0.5

基于 YAML 的声明式剧本格式。作者只填字段，引擎负责解释。

---

## 1. 设计原则

**P1 — 声明而非执行。**
数据里没有逻辑、没有跳转、没有代码。作者声明"这一行需要什么"，引擎决定"怎么做"。

**P2 — 场景声明全集，行内稀疏覆盖。**
`scene` 声明本场景允许出现哪些背景；`dialog` 的行只能从中选择，不能引入新资产。变更的边界在场景，选择的权利在行。

**P3 — 高频状态用标量字段，低频演出用固定动词表。**
表情、位置每句都变 → 直接字段。进出场、动作偶尔发生 → 列表 + 封闭动词。

**P4 — 校验前移。**
所有引用（角色、表情、背景、语音、BGM）在编译期全部可查。宁可编译不过，不要静默降级。

**P5 — 演出参数不写数值。**
作者不写时长、不写毫秒、不写缓动曲线。屏幕相对位置坐标和内容节拍 `pause` 是例外。需要"慢一点"就用命名风格，引擎保证全篇手感一致。

**P6 — 未知字段必须报错。**
`sayy:` 少一个字母，必须编译失败，而不是让这句台词永远不显示。

**P7 — 剧本里没有状态。**
没有变量、没有旗标、没有 `when:`。分支只能通过选项跳转到不同场景来表达。

这条限制换来两个可证明的性质：**剧情图是一张无环图，因此必然终止**；**整部作品的流程图在编译期就能完整画出**。任何"玩过就变"的内容都不属于这个格式。

---

## 2. 文件组织

```
project/
  assets.yaml        # 资产 id → 文件路径
  characters.yaml    # 角色定义
  scenes/
    ch01.yaml        # 一个文件放一章,内含多个 scene
    ch02.yaml
```

`assets.yaml` 与 `characters.yaml` 全局各一份；`scenes/` 下按章拆文件，每个文件是一个 `scenes:` 列表。所有 id 相对各自文件根解析。

---

## 3. 顶层结构

### 3.1 assets

`assets.yaml` 是**唯一**的资产声明处：id → 文件。剧本里只引用 id，从不出现路径。

#### 基本形式

```yaml
background:
  classroom_noon: bg/classroom_noon.webp
  classroom_dusk: bg/classroom_dusk.webp

sprite:
  lin:
    neutral: char/lin/neutral.webp
    smile:   char/lin/smile.webp
  zhou:
    neutral: char/zhou/neutral.webp

cg:
  after_rain: cg/after_rain.webp

bgm:
  after_school: audio/bgm/after_school.ogg

voice:
  lin_001: audio/voice/lin_001.ogg
```

| 类型 | 由谁引用 | 命名空间 |
|---|---|---|
| `background` | `scene.backgrounds`、`scene.initial`、`stage.background` | 全局 |
| `sprite` | `characters.<id>.default_sprite`、行内 `sprite` | 按角色分组 |
| `cg` | `stage.cg` | 全局 |
| `bgm` | `scene.bgm`、`stage.bgm` | 全局 |
| `voice` | 行内 `voice` | 全局 |

**规则**

- 五个类型是独立命名空间，同名 id 互不冲突（`bgm: rainy` 与 `cg: rainy` 可以并存）。
- 路径相对 `assets.yaml` 所在目录。
- `sprite` 按角色分组，因此**角色的可选表情由 `assets.yaml` 决定**；`characters.yaml` 只声明 `default_sprite`，不重复列表，避免双重真相。
- 引用未声明的 id → 编译报错；声明了但全场未用 → 告警。

#### 立绘画布约定

立绘是**整张全身图**，每个表情一张独立文件。为了让引擎不需要任何锚点数据，素材必须满足三条：

1. **同一角色的所有表情共用同一画布尺寸。**
2. **人物脚底贴画布下边缘，水平居中。**
3. **所有角色按同一 DPI 导出**，即画布像素高正比于角色实际身高。

满足之后，默认锚点 `{x: 0.5, y: 1.0}` 就是把画布底边对齐屏幕底部、水平居中。自定义 `at` 坐标相对屏幕定位同一锚点；矮的角色自然就矮，因为他的画布本来就矮。

> 不要为每个表情导出不同尺寸的画布、再靠裁剪去对齐。那会把"人物在画面里有多高"变成每张图都要单独核对的事，而且错一次就是视觉上的穿帮。

#### 标量 / 对象双形态

默认写成一个路径（标量）。素材不满足上面的约定时，升级成对象：

```yaml
sprite:
  lin:
    smile:
      file: char/lin/smile.webp
      anchor: [0.5, 1.0]     # 归一化坐标，(0,0) 为左上
      scale: 0.9             # 相对约定尺寸
```

| 字段 | 必填 | 说明 |
|---|---|---|
| `file` | 是 | 路径 |
| `anchor` | 否 | 缺省 `[0.5, 1.0]`（底部居中） |
| `scale` | 否 | 缺省 `1.0` |

两种写法编译后归一到同一个 IR。**绝大多数资产保持一行**，只有出问题的少数才带参数——和 `stage` 的"声明 + 稀疏覆盖"是同一个套路。

#### 背景

背景永远铺满全屏，没有锚点问题，只需要处理比例：

```yaml
background:
  classroom_noon:
    file: bg/classroom_noon.webp
    fit: cover               # cover / contain，缺省 cover
```

与项目分辨率比例不一致时**告警而非报错**——允许用超宽图做横移效果，但提醒你两侧可能被裁掉。

#### CG（事件插图）

CG 是叠加在场景之上的全屏图，出现后保持，直到被收回：

```yaml
# 显示
stage: {cg: after_rain}

# 收回，画面回到本场景的 background
stage: {cg: null}
```

`cg` 引用全局命名空间，**不做场景声明全集**：它是叠加层而不是背景替换，收回后画面仍由 `background` 决定，`画面 = f(scene, 行号)` 这个性质不受影响。

#### 格式与目录

| 类别 | 格式 | 说明 |
|---|---|---|
| 立绘 / CG | WebP（带 alpha） | 比 PNG 小 30–50% |
| 背景 | WebP / AVIF | 无 alpha，压缩率更好 |
| BGM / 音效 / 语音 | OGG Vorbis | 全项目统一一种 |

```
char/lin/neutral.webp
bg/classroom_noon.webp
cg/after_rain.webp
audio/bgm/after_school.ogg
audio/voice/lin_001.ogg
```

**多分辨率不进 `assets.yaml`。** `@2x`、`@3x` 由打包工具生成，属于构建问题，不是剧本问题。

#### 开发期占位

素材未就绪时用编译开关放行，缺图渲染成色块 + id 文字：

```
compile --allow-missing-assets
```

否则美术排期会直接卡住剧本写作。**发布构建必须关闭此开关。**

#### 表情的两条约定

1. **表情名用英文短名**（`smile` / `cry` / `angry`）。程序、翻译表、语音文件名、版本控制都要引用它；显示用的中文名放在 `characters.name`。
2. **切换过渡由引擎统一决定**（约 80–120ms 交叉淡化）。作者只写 `sprite: smile`，不声明时长——与转场时长同理（P5）。

#### 暂不实现

- **分层立绘**（身体/头发共用 + 脸部件合成）。它需要新增对齐数据与运行时合成，违背"单一真相"。触发条件：单角色表情超过 20 个、且包体成为瓶颈、且返工频繁。届时 id 与引用方式不变，只是 value 从路径变成对象，可平滑升级。
- **视差背景**、**视频过场**、**骨骼动画**。同属"资源系统"范畴，不在本版内。

### 3.2 characters

| 字段 | 必填 | 类型 | 说明 |
|---|---|---|---|
| *(键)* | 是 | string | 角色 id，全局唯一，建议短名 `lin` |
| `name` | 是 | string | 显示名 |
| `color` | 否 | color | 名牌颜色 |
| `default_sprite` | 是 | string | 默认表情，必须已在该角色名下的 `sprite` 中声明 |

```yaml
characters:
  lin:
    name: 林
    color: "#7bb0ff"
    default_sprite: neutral
```

`narrator` 是保留 id，不需要在 `characters` 中定义，没有 `default_sprite`，也不能出现在 `assets.yaml` 的 `sprite` 下。

### 3.3 scenes

`scenes` 是**序列**（有序），每个元素是一个场景。

整部作品必须且只能有一个 `start: true` 的场景，作为首次进入作品时的入口。未声明或声明多个均为编译错误。场景列表顺序仍决定无选项场景的默认后继，与起始场景的位置无关。

---

## 4. scene

| 字段 | 必填 | 类型 | 说明 |
|---|---|---|---|
| `id` | 是 | string | 全局唯一，建议 `ch01.classroom` |
| `backgrounds` | 是 | string[] | 本场景允许出现的背景全集 |
| `initial` | 是 | string | 初始背景，必须 ∈ `backgrounds` |
| `bgm` | 否 | string \| null | 进入场景时的 BGM；`null` 表示静音 |
| `enter` | 否 | enum | 进入转场：`cut` / `fade` / `crossfade`，缺省 `cut` |
| `dialog` | 是 | map | 台词，见第 5 节 |
| `end` | 否 | bool | 终止场景，缺省 `false`，见 R12 |
| `start` | 否 | bool | 唯一作品入口；整部作品必须且只能有一个为 `true` |

```yaml
- id: ch01.classroom
  backgrounds: [classroom_noon, classroom_dusk]
  initial: classroom_noon
  bgm: gentle
  enter: fade
  dialog: { ... }
```

**约束**：`stage.background` 只能取 `backgrounds` 中的值。这条闭包性质是静态分析成立的前提。

---

## 5. dialog

### 5.1 形状

```yaml
dialog:
  <行 id>:
    <选择器>:              # 可选；旁白行用 narrator
      say: ...
      voice: ...
      sprite: ...
      at: ...
      stage: ...
      animation: ...
    options:               # 可选；与选择器同级，见 5.7
      - id: ...
        say: ...
        to: <scene id>
```

**选择器**是角色 id 或 `narrator`。选择器的值代表「**这一行**」，不是「这个角色」——所以旁白行也能改背景。

**行 id** 在 scene 内唯一即可，全局引用写作 `ch01.classroom/d002`。

**顺序**：行按 YAML 源文件中的出现顺序播放，从上到下。编译器必须保留映射键的源顺序；`order` 不是本格式字段，出现时按未知字段报错。带 `options` 的行等待玩家选择；选择后进入目标场景，并从目标场景开始按场景列表顺序继续播放，不回到来源场景的下一行或默认后继。

### 5.2 字段

| 字段 | 必填 | 类型 | 适用 | 说明 |
|---|---|---|---|---|
| `say` | 是 | string | 全部 | 文本，可为空串（见 R8） |
| `voice` | 否 | asset | 非旁白 | 语音文件 id |
| `sprite` | 否 | string | 非旁白 | 表情，必须 ∈ 该角色 `sprites` |
| `at` | 否 | object | 非旁白 | 屏幕相对坐标 `{x, y}`，两个值均为 0–1；见 5.6 |
| `stage` | 否 | object | 全部 | 见 5.3 |
| `animation` | 否 | list | 全部 | 见 5.4 |
| `pause` | 否 | number | 全部 | 秒；仅在 `say` 为空时生效 |

`pause` 和屏幕相对位置坐标是本格式的数值字段。

### 5.3 stage

| 字段 | 必填 | 类型 | 说明 |
|---|---|---|---|
| `background` | 否 | string | 必须 ∈ 本 scene 的 `backgrounds` |
| `cg` | 否 | string \| null | 全局 CG 库；`null` 表示收回 |
| `bgm` | 否 | string \| null | 全局音乐库；`null` 表示停止 |
| `transition` | 否 | enum | `cut` / `fade` / `crossfade`，缺省 `cut` |

`stage` 先于本行文本生效：玩家先看到画面变化，再读到描述画面变化的那句话。

每行最多一个 `stage`。需要连续两次变更，写两行。

### 5.4 animation

**只作用于选择器指定的角色。** 一张封闭动词表，不允许自定义、不允许写数值。

**位移类**（`enter` 的场内终点由本行 `at` 决定；`move.to` 是移动终点，并更新角色位置状态）

| 动词 | 参数 | 说明 |
|---|---|---|
| `enter` | `from`: `left`/`right`/`front` | 从场外进入 |
| `exit` | `to`: `left`/`right`/`back` | 离场，之后不在场 |
| `move` | `to`: `{x, y}` | 场内移动至屏幕相对坐标 |

**表演类**（一次性，不改位置）

| 动词 | 参数 | 说明 |
|---|---|---|
| `nod` | — | 点头 |
| `shake` | — | 摇头 / 发抖 |
| `jump` | — | 惊吓跳起 |

**通用参数**

| 参数 | 取值 | 说明 |
|---|---|---|
| `style` | `fast` / `slow` | 时长变体，缺省标准 |

```yaml
animation:
  - enter: {from: right}
  - jump: {}
```

列表按顺序播放。

### 5.5 sprite

表情变更。未指定时**沿用该角色上一行的表情**；角色首次出现时使用 `characters.<id>.default_sprite`。

```yaml
lin:
  sprite: smile
  say: "不过，我还不想回去。"
```

### 5.6 at

位置是立绘素材锚点在屏幕中的归一化坐标：`x: 0` 为屏幕左边、`x: 1` 为右边；`y: 0` 为屏幕顶部、`y: 1` 为底部。两个值必须是 0–1 之间的数值。

```yaml
at: {x: 0.25, y: 1.0}
```

未指定时沿用该角色上一行的位置；角色首次出现时默认为 `{x: 0.5, y: 1.0}`（水平居中、底边贴屏幕底部）。这里的坐标指向素材自身的 `anchor`；素材锚点由 `assets.yaml` 的立绘定义决定。坐标位置与立绘缩放是两个独立设置。

### 5.7 options

选项是 `dialog` 行的一个字段，**与选择器同级**。

| 字段 | 必填 | 类型 | 说明 |
|---|---|---|---|
| `id` | 是 | string | 场景内唯一，用于追踪与测试断言 |
| `say` | 是 | string | 选项显示文本 |
| `to` | 是 | string | 目标场景 id，必须存在 |

```yaml
d005:
  zhou:
    sprite: neutral
    say: "明天见。"
  options:
    - id: call
      say: "「等一下。」"
      to: ch01.gate_call
    - id: quiet
      say: "（什么也没说）"
      to: ch01.gate_quiet
```

**约束**

- 带 `options` 的行**必须是所在场景的最后一行**，否则其后的行永远播不到，编译报错。
- 一个场景最多一处 `options`。
- 选择后直接进入目标场景，`stage` / `sprite` / `at` 全部由新场景重新决定（见 R7）。
- 选项没有显示条件、没有可用性判断。**因为没有状态，所以所有选项永远全部可见。**
- `options` 的行同样可以有 `stage` / `animation`，演出在选项出现之前完成。

### 5.8 文本与换行

`say` 接受三种 YAML 字符串写法，效果不同：

```yaml
# 1) 双引号：支持 \n 转义，适合一两处换行
say: "先别走。\n……我还有话没说。"

# 2) 块标量：天然保留换行，适合整段长台词
say: |
  先别走。
  ……我还有话没说。

# 3) 单引号 / 无引号：\n 是字面量，不会换行
say: '先别走。\n……'     # ← 会原样显示 \n，别这样写
```

**规则**

- `\n` 在双引号字符串中表示**文本框内换行**：不等待、不分页、不新增 `dialog` 行、不进回顾日志。
- 块标量结尾的换行会被去掉（等价 `|-`），不要用它制造空行。
- 不要在文本里用空格对齐或缩进排版——那是引擎的事（同 P5）。
- 编译器检测到 `say` 中含**字面量** `\n`（反斜杠 + n 两个字符）时告警，这几乎总是引号用错了。

---

## 6. 语义规则

| 编号 | 规则 |
|---|---|
| **R1** | 播放顺序 = `dialog` 中各行在 YAML 源文件中的出现顺序；场景默认后继 = `scenes` 列表中的下一场景。 |
| **R2** | 单行执行顺序：`stage` → `sprite`/`at` 终态 → `animation` 演出 → `voice` → 文本逐字显示 → 等待输入。 |
| **R3** | `sprite` / `at` 在角色维度上继承：未写则沿用上一行同一角色的值。 |
| **R4** | 默认在场：角色第一次作为选择器出现时，即视为在场上（位置取 `at` 或 `{x: 0.5, y: 1.0}`）。不必每句都写 `enter`。 |
| **R5** | `animation` 只作用于选择器角色。`narrator` 行不能做角色动作。 |
| **R6** | `exit` 之后该角色不在场；若之后仍有台词，编译告警（大概率是笔误）。 |
| **R7** | 进入新场景时，全部角色状态清空。场景之间不继承表情、位置、在场性。 |
| **R8** | `say` 为空串时：不显示文本框、不写入回顾日志、不等输入，只执行演出并等待 `pause`。 |
| **R9** | `stage.background` 必须 ∈ 本 scene 的 `backgrounds`。 |
| **R10** | `options` 出现即断链：该行播完后等待选择，不再顺序落到下一场景。 |
| **R11** | 无 `options` 且 `end: false` 时，播完顺序进入 `scenes` 列表中的下一个场景；若已是最后一个，编译报错。 |
| **R12** | `end: true` 表示终止，不产生默认后继，忽略列表中的后续场景。 |
| **R13** | 首次进入作品时从唯一 `start: true` 的场景开始。选择选项后进入其 `to` 场景；该目标场景完成后仍按 R11 继续，除非遇到 `options` 或 `end: true`。 |

---

## 7. 校验规则

编译期必须报错的：

1. 未知字段（拼写错误）。
2. 必填字段缺失（`scene.id`、`backgrounds`、`initial`、行内 `say`）。
3. `initial` ∉ `backgrounds`。
4. `stage.background` ∉ 本 scene 的 `backgrounds`。
5. `sprite` 未在该角色名下的 `sprite` 中声明；旁白行使用 `sprite` 或 `voice`。
6. 引用的 `voice` / `bgm` / `background` / `cg` 未在 `assets.yaml` 中声明。
7. `assets.yaml` 中声明的文件路径在磁盘上不存在。
8. 选择器不是已定义角色，也不是 `narrator`。
9. 全局 id 重复，或角色 id 使用保留字（`narrator` / `options`）。
10. `options` 所在行不是本场景的最后一行。
11. `options.to` 指向不存在的场景。
12. 场景图中存在环。
13. 非终止场景没有后继（无 `options`、无 `end: true`，且已是列表最后一个）。
14. 全部场景中没有 `start: true`，或有多个 `start: true`。

编译期告警的：

1. `exit` 之后该角色仍有台词。
2. scene 从未被任何地方引用（孤儿场景）。
3. `backgrounds` 中声明了但全场未使用的背景。
4. `dialog` 为空。
5. 场景被多个场景指向（图中有汇合）。合法，但值得确认不是笔误。
6. `assets.yaml` 中声明了但从未被引用的资产。
7. `say` 中出现字面量 `\n`（多半是引号用错）。
8. `background` 的宽高比与项目分辨率不一致（可能被裁切）。
9. 同一角色的立绘画布尺寸不一致（违反 3.1 的画布约定）。

---

## 8. 运行时模型

**核心性质**：当前画面 = `f(scene_id, 行号)`。

因为背景被场景收容、角色状态逐行继承且可重放，舞台状态完全由这两个值决定。

- **存档**：只记 `(scene_id, 行号)`。
- **读档**：定位场景，按 R2 从场景开头重放到该行。代价 O(场景行数)，通常几十行。
- **回滚**：退一行，按同一规则重算。不会出现"退回去了但背景没退回去"。
- **回顾日志**：由 `say` 非空的行构成，不需要额外存储。
- **跳过**：从当前位置向后快速应用各行的 `stage` / `sprite` / `at`，跳过动画与语音。

运行时主循环只有一件事：**按顺序取行，解释字段，不执行逻辑。**

因为无状态，场景图是一张有向无环图，于是还有几条性质：

- **终止性可证明**：图无环 + 每个非终止场景都有后继 ⇒ 任意游玩路径必然终止。
- **全图可静态渲染**：编译期就能输出完整流程图（含所有分支与结局），用于审校剧情结构。
- **重复进入同一场景是幂等的**：没有"已看过"的记忆，切回去看到的内容完全一样。

---

## 9. 示例

### 9.1 最小示例

```yaml
characters:
  lin:
    name: 林
    color: "#7bb0ff"
    default_sprite: neutral

scenes:
  - id: ch01.classroom
    backgrounds: [classroom_noon, classroom_dusk]
    initial: classroom_noon
    bgm: gentle
    enter: fade
    start: true
    dialog:
      d001:
        narrator:
          say: "窗外的蝉鸣忽然停了一瞬。"
          stage: {background: classroom_noon}

      d002:
        lin:
          sprite: neutral
          at: {x: 0.5, y: 1.0}
          animation:
            - enter: {from: right}
          say: "你来了。"
          voice: lin_001

      d003:
        narrator:
          say: "窗外的光开始偏黄。"
          stage:
            background: classroom_dusk
            transition: crossfade

      d004:
        lin:
          sprite: smile
          say: "……不过，我还不想回去。"
          voice: lin_002

  - id: ch01.rooftop
    backgrounds: [rooftop_night]
    initial: rooftop_night
    bgm: rain_loop
    enter: crossfade
    dialog:
      d001:
        lin:
          sprite: away
          at: {x: 0.5, y: 1.0}
          animation:
            - enter: {from: front}
          say: "雨好像不会停了。"
          voice: lin_003
    end: true
```

### 9.2 完整示例

五个场景、两个角色、两个结局，覆盖主要字段与全部动画动词。可作为编译器的冒烟测试用例。

**assets.yaml**

```yaml
background:
  classroom_noon:      bg/classroom_noon.webp
  classroom_dusk:      bg/classroom_dusk.webp
  classroom_dusk_rain: bg/classroom_dusk_rain.webp
  rooftop_night_rain:  bg/rooftop_night_rain.webp
  hallway_night:       bg/hallway_night.webp
  gate_night:          bg/gate_night.webp

sprite:
  lin:
    neutral:   char/lin/neutral.webp
    smile:     char/lin/smile.webp
    away:      char/lin/away.webp
    surprised: char/lin/surprised.webp
  zhou:
    neutral:   char/zhou/neutral.webp
    laugh:     char/zhou/laugh.webp
    serious:   char/zhou/serious.webp
    surprised: char/zhou/surprised.webp

cg:
  after_rain: cg/after_rain.webp

bgm:
  after_school:  audio/bgm/after_school.ogg
  rain_light:    audio/bgm/rain_light.ogg
  rain_loop:     audio/bgm/rain_loop.ogg
  hallway_quiet: audio/bgm/hallway_quiet.ogg

voice:
  lin_001:  audio/voice/lin_001.ogg
  lin_002:  audio/voice/lin_002.ogg
  lin_003:  audio/voice/lin_003.ogg
  lin_004:  audio/voice/lin_004.ogg
  lin_005:  audio/voice/lin_005.ogg
  zhou_001: audio/voice/zhou_001.ogg
  zhou_002: audio/voice/zhou_002.ogg
  zhou_003: audio/voice/zhou_003.ogg
  zhou_004: audio/voice/zhou_004.ogg
  zhou_005: audio/voice/zhou_005.ogg
```

**characters.yaml**

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

**scenes/ch01.yaml**

```yaml
scenes:

  # ─────────────── 场景一：放学后的教室 ───────────────
  - id: ch01.classroom
    backgrounds: [classroom_dusk, classroom_dusk_rain]
    initial: classroom_dusk
    bgm: after_school
    enter: fade
    start: true
    dialog:

      d001:
        narrator:
          say: "蝉鸣忽然停了。放学后的教室空得能听见自己的呼吸。"

      d002:
        zhou:
          sprite: laugh
          at: {x: 0.8, y: 1.0}
          animation:
            - enter: {from: right}
          say: "喂，你还没走啊？"
          voice: zhou_001

      d003:
        lin:
          sprite: neutral
          at: {x: 0.2, y: 1.0}
          say: "……你没走，我怎么走。"
          voice: lin_001

      # 只写 say → 沿用上一行的 sprite(laugh) 与 at(right)
      d004:
        zhou:
          say: "这话说得我可太爱听了。"
          voice: zhou_002

      # 换景：目标必须在本场景 backgrounds 之内
      d005:
        narrator:
          say: "窗外的光又暗了一格。"
          stage:
            background: classroom_dusk_rain
            bgm: rain_light
            transition: crossfade

      d006:
        lin:
          sprite: away
          say: "……下雨了。"

      # 无文本节拍：不显示文本框、不进日志、不等输入
      d007:
        narrator:
          say: ""
          pause: 1.0

      d008:
        lin:
          sprite: neutral
          animation:
            - nod: {}
          say: "那就等雨停吧。"
          voice: lin_002

      d009:
        zhou:
          sprite: surprised
          animation:
            - jump: {}
          say: "难得听你这么说。"

      # 说话人自己做无声演出：走到中央再停
      d010:
        zhou:
          say: ""
          at: {x: 0.5, y: 1.0}
          animation:
            - move: {to: {x: 0.5, y: 1.0}}
          pause: 0.6

      d011:
        lin:
          sprite: away
          animation:
            - exit: {to: left, style: slow}
          say: "我先回去了。"
          voice: lin_003

  # ─────────────── 场景二：雨中的天台 ───────────────
    - id: ch01.rooftop
    backgrounds: [rooftop_night_rain]
    initial: rooftop_night_rain
    bgm: rain_loop
    enter: crossfade
    dialog:

      d001:
        lin:
          sprite: away
          at: {x: 0.5, y: 1.0}
          animation:
            - enter: {from: front}
          say: "雨好像不会停了。"

      d002:
        narrator:
          say: "她没有回头，肩膀在雨里微微发抖。"

      # 只改 BGM、不动背景：bgm: null 表示停乐
      d003:
        narrator:
          say: "音乐不知什么时候停了，只剩下雨声。"
          stage: {bgm: null}

      d004:
        lin:
          sprite: neutral
          say: "……刚才在教室里，谢谢你没说破。"
          voice: lin_004

      d005:
        lin:
          sprite: surprised
          animation:
            - shake: {}
          say: "！不是，你别笑。"

      d006:
        lin:
          sprite: smile
          say: "……算了。"

  # ─────────────── 场景三：走廊 ───────────────
  - id: ch01.hallway
    backgrounds: [hallway_night]
    initial: hallway_night
    bgm: hallway_quiet
    enter: cut
    dialog:

      d001:
        narrator:
          say: "走廊只剩最后一盏灯。"

      # 新场景不继承上一场景的在场性，必须重新 enter
      d002:
        zhou:
          sprite: neutral
          at: {x: 0.5, y: 1.0}
          animation:
            - enter: {from: left}
          say: "送回去了？"
          voice: zhou_003

      d003:
        narrator:
          say: ""
          pause: 0.8

      d004:
        zhou:
          sprite: serious
          animation:
            - shake: {}
          say: "……算了，不说这个。"

      # 选项与选择器同级；带 options 的行必须是本场景最后一行
      d005:
        zhou:
          sprite: neutral
          say: "明天见。"
          voice: zhou_004
        options:
          - id: call
            say: "「等一下。」"
            to: ch01.gate_call
          - id: quiet
            say: "（什么也没说）"
            to: ch01.gate_quiet

  # ─────────────── 结局 A：叫住他 ───────────────
  - id: ch01.gate_call
    backgrounds: [hallway_night, gate_night]
    initial: hallway_night
    bgm: hallway_quiet
    enter: cut
    dialog:

      d001:
        zhou:
          sprite: surprised
          at: {x: 0.8, y: 1.0}
          animation:
            - enter: {from: left}
          say: "……啊？"
          voice: zhou_005

      d002:
        lin:
          sprite: away
          at: {x: 0.2, y: 1.0}
          say: "……没什么。就是，明天见。"
          voice: lin_005

      d003:
        narrator:
          say: "我说完就后悔了。"
          stage:
            background: gate_night
            transition: fade

      d004:
        narrator:
          say: "……雨停了。"
          stage: {cg: after_rain}
    end: true

  # ─────────────── 结局 B：什么也没说 ───────────────
  - id: ch01.gate_quiet
    backgrounds: [hallway_night]
    initial: hallway_night
    bgm: hallway_quiet
    enter: cut
    dialog:

      d001:
        narrator:
          say: "他走远了。走廊的灯在我身后灭了一盏。"
          stage: {bgm: null}
    end: true
```

**示例覆盖点**

| 机制 | 位置 |
|---|---|
| 表情继承（只写 `say`） | 场景一 `d004` |
| 位置继承 | 场景一 `d004` |
| 无文本节拍 | 场景一 `d007`、`d010`，场景三 `d003` |
| 换背景（含 `crossfade`） | 场景一 `d005` |
| 换 BGM / 停乐 | 场景一 `d005`、场景二 `d003` |
| `enter` 三个方向 | 场景一 `d002`，场景二 `d001`，场景三 `d002` |
| `move` | 场景一 `d010` |
| `exit` + `style: slow` | 场景一 `d011` |
| `nod` / `jump` / `shake` | 场景一 `d008`/`d009`，场景二 `d005` |
| 旁白无 `sprite`/`voice` | 全部 `narrator` 行 |
| 场景间状态清空（R7） | 场景三 `d002` 重新 `enter` |
| `options` 与选择器同级 | 场景三 `d005` |
| 选项跳转两个不同场景 | 场景三 `d005` → 结局 A / 结局 B |
| `end: true` 终止 | 两个结局场景 |
| 结局内再次换背景 | 结局 A `d003`（`gate_night`） |
| 显示事件 CG | 结局 A `d004`（`after_rain`） |

---

## 10. 已否决的字段

记录在案，避免反复讨论。

| 字段 | 否决理由 |
|---|---|
| `weather` | 由背景美术决定，与 `background` 构成双重真相。若需作为逻辑条件，用叙事状态变量表达，不要塞进舞台字段。 |
| `time` | 同上。`classroom_noon` 已经编码了时段。 |
| `cast` | 可由 `speaker` 并集推导。真正推不出的只有"在场但沉默"，而给该角色一行台词即可解决（E1 已定案不实现）。 |
| 行内 `background` 直接覆盖（不声明全集） | 失去资产校验与场景画面的可穷举性。 |

---

## 11. 定案记录：明确不做

以下四项经讨论确定不实现，不是遗漏。

| 编号 | 内容 | 决定 |
|---|---|---|
| E1 | 跨角色动画（A 说话时 B 默默退场） | **不实现。** `animation` 只作用于选择器角色。需要 B 动，就让 B 有一行台词。 |
| E2 | 条件行 / 状态判断 | **不实现。** 设计里没有状态（P7）。没有变量，就不存在"根据状态显示不同内容"。 |
| E3 | 选项 | **已转为正式语法。** 见 5.7：`options` 与选择器同级，按 `to` 跳转场景。 |
| E4 | 转场时长的数值控制 | **不实现。** 时长由运行时决定（P5）。作者只选 `cut` / `fade` / `crossfade` 与 `style`，不写数字。 |

**E2 的连带影响**：因为没有状态，选项不能"选过就消失"，场景不能"第二次进来不一样"，角色的态度也不可能有累积。所有分支必须由选项显式表达。

这是格式的边界，不是缺陷：**需要记忆的玩法不属于这个格式。** 如果哪天确实需要，那是在它之上另建一层，而不是往这里加 `when:`。

---

*文档版本 v0.5 —— 加入场景入口与屏幕相对坐标，明确源文件顺序和选项后的默认流程。*
