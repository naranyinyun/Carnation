# Carnation

## Intro

Carnation 是面向 AI Agent 的 Visual Novel 构建工具。它以声明式、结构化的 YAML DSL 构建，这种语言面向 Agent 优化的同时，保留了简单易懂的人类易读性。

Carnation 旨在消除 Visual Novel 制作流程必须围绕程序设计进行展开而带来的痛点。现在，你只需要像编写舞台剧脚本那样设计传统舞台剧本，再交由 Agent 将其转换为 Carnation 可用的 YAML，即可快速、便捷地完成 Visual Novel 制作。

## Carnation YAML DSL

Carnation 的核心设计是它的 YAML DSL(CYD)，这种语言将标准的 YAML 转化为机器可执行的脚本。相较于直接编写脚本，YAML DSL 被设计为声明式、结构化、无状态的，编写它的复杂性由 Agent 承担，人类只需要担任传统的编剧和导演即可。

这种语言并不难看懂，来看一个例子：

```yaml
d002:
        keeper:
          sprite: unreadable
          at: {x: 0.72, y: 1.0}
          animation:
            - enter: {from: right, style: slow}
          say: "……"
```

它表示一个ID为`keeper`的角色在(0.72,1.0)的位置说了“...”，角色出场时从右侧缓慢进入，初始表情是`unreadable`
如果后续不需要更改角色的表情和位置，它就可以进一步简化为：

```yaml
d005:
        keeper:
          say: "不能。"
```

Carnation 要求剧情是一个有向无环图，这样就不会出现回环剧情的情况。在调试模式下，Carnation 可以绘制出剧情的树状图。

由于 DSL 本身没有状态，只要给定行号和场景，播放器所呈现的内容就是确定的，它与上下文和状态都无关。通过这样的设计，您不再需要管理复杂的状态，也不需要面临状态可能带来的污染，它也可以一定程度上抑制 AI 幻觉。

## 如何使用？

只需克隆此仓库到本地，让您的 Agent 读取 `.agents` 中的 SKILL，再将您的传统舞台脚本和资产交由 Agent 转化为 CYD。如果你需要了解 Carnation 的具体设计，可以阅读 `vn-script-spec.md` 和 `docs/develop-guide.md`

## 注意事项

Carnation 目前仍然处于想法验证的阶段，不过，它已经具备了讲一个好故事所需要的大多数功能。

我们欢迎关于 Carnation 任何方面的贡献（只要它符合设计哲学），也欢迎关于它的讨论和建议。如果你需要修改代码，请让 Agent 读取 `AGENT.md` 获取开发所需的信息。

感谢使用