# Carnation Script Syntax Cheatsheet (`v0.5`)

## 1. File Trio Overview

| File | Role | Allowed Top-Level Keys |
| :--- | :--- | :--- |
| `assets.yaml` | Maps asset IDs to file paths | `background`, `sprite`, `cg`, `bgm`, `voice` |
| `characters.yaml` | Defines speaker metadata | `characters` |
| `assets/scripts/*.yaml` | Ordered scene list & dialogue | `scenes` |

> **Strict Schema Rule**: Unknown keys anywhere in `assets.yaml`, `characters.yaml`, or `scripts/*.yaml` immediately fail compilation with `ScriptValidationException`.

---

## 2. Scene Schema (`scenes[i]`)

```yaml
scenes:
  - id: ch01.classroom
    backgrounds: [classroom_noon, classroom_dusk] # Required: whitelist for this scene
    initial: classroom_noon                       # Required: must be in `backgrounds`
    bgm: after_school                             # Optional: bgm ID or null
    enter: fade                                   # Optional: cut (default) | fade | crossfade
    start: true                                   # Optional: exactly ONE scene must be true
    end: false                                    # Optional: true for terminal ending scenes
    dialog:
      d001:
        ...
```

---

## 3. Dialogue Line Schema (`dialog.<line_id>`)

Each line under `dialog` maps a unique `<line_id>` (e.g. `d001`) to **exactly one speaker selector** (`narrator` or a character ID from `characters.yaml`), plus an optional sibling `options` list (only allowed on the **last** line of a scene).

```yaml
      d001:
        narrator:
          say: "午后的阳光斜斜地落在讲台边缘。"
          stage:
            background: classroom_noon
            bgm: after_school
            cg: null
            transition: crossfade

      d002:
        zhou:
          sprite: laugh
          at: {x: 0.76, y: 1.0}
          voice: zhou_001
          animation:
            - enter: {from: right}
            - jump: {}
          say: "喂，你还没走啊？"

      # Silent beat line (R8): empty `say` + `pause` seconds
      d003:
        narrator:
          say: ""
          pause: 0.8

      # Branching line (MUST be the last line of the scene)
      d004:
        lin:
          sprite: smile
          say: "明天见？"
        options:
          - {id: call, say: "「等一下，一起走吧。」", to: ch01.gate_call}
          - {id: quiet, say: "「明天见。」", to: ch01.gate_quiet}
```

### Allowed Fields Inside Speaker Block

| Field | Required | Allowed On `narrator`? | Type / Values | Semantics |
| :--- | :---: | :---: | :--- | :--- |
| `say` | **Yes** | Yes | `String` | Dialogue text (`\n` for line breaks). Use `""` with `pause` for silent beats. |
| `sprite` | No | **No** | `String` | Expression ID under `assets.yaml -> sprite.<charId>`. Inherited from previous line in same scene if omitted. |
| `at` | No | **No** | `{x: 0..1, y: 0..1}` | Normalized screen anchor (`0.24` left, `0.5` center, `0.76` right, `y: 1.0` bottom). Inherited if omitted. |
| `voice` | No | **No** | `String` | Voice ID under `assets.yaml -> voice`. |
| `pause` | No | Yes | `num` (seconds) | Used when `say: ""` to hide the dialogue box and auto-advance after `pause` seconds. |
| `stage` | No | Yes | `Map` | `{background, cg, bgm, transition}`. Applied before text. `cg: null` dismisses CG; `bgm: null` stops music. |
| `animation` | No | **No** | `List<Map>` | Ordered list of closed animation verbs for the speaking character. |

---

## 4. Closed Animation Verb Table (`animation`)

Each list item under `animation:` must be a single-key map choosing one of these 6 verbs, with optional `style: fast | slow`:

| Verb | Parameters | Effect & Stage State Impact |
| :--- | :--- | :--- |
| `enter` | `from: left \| right \| front`, `style: fast \| slow` | Slides/fades character onto stage ending at `at`. |
| `move` | `to: {x: 0..1, y: 0..1}`, `style: fast \| slow` | Smoothly glides character to new coordinates and updates their stage position. |
| `exit` | `to: left \| right \| back`, `style: fast \| slow` | Slides/fades character off stage. **Removes character from stage after this line completes.** |
| `nod` | `style: fast \| slow` | Gentle vertical nod bounce (preserves position). |
| `shake` | `style: fast \| slow` | Horizontal head/body shake oscillation (preserves position). |
| `jump` | `style: fast \| slow` | Startled upward jump (preserves position). |

---

## 5. Common Validation Pitfalls to Avoid

1. **Referencing a background in `stage.background` without adding it to `scene.backgrounds`**: Always add the background ID to both `assets.yaml` and the scene's `backgrounds: [...]` list.
2. **Putting `sprite`, `at`, `voice`, or `animation` on `narrator`**: Narrator lines can only have `say`, `pause`, and `stage`.
3. **Putting `options` in the middle of a scene**: `options` must always be on the final dialogue line of that scene.
4. **Creating a cycle in `options.to`**: Scene graphs must be strict DAGs (Directed Acyclic Graphs); never jump backward to an ancestor scene.
