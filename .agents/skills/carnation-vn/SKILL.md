---
name: carnation-vn
description: >-
  Author, edit, generate SVG visual assets, and validate visual novel scripts in the
  Carnation engine. Use this skill whenever the user asks to write or modify story scenes,
  add characters or expressions, create backgrounds/sprites/CGs, or debug script validation
  errors in a Carnation project.
---

# Carnation Visual Novel AI-Native Authoring Skill

Carnation is a declarative, zero-state, DAG-based visual novel engine where **every screen frame is a pure function `f(scene_id, lineIndex)`**. AI agents can author complete playable visual novels by editing three declarative layers (`assets.yaml`, `characters.yaml`, `assets/scripts/*.yaml`) and generating matching SVG art assets.

---

## Core AI Workflow (Step-by-Step)

Whenever creating or modifying story content, characters, or visual assets in Carnation, follow this strict 4-step closed loop:

### Step 1: Register Characters (`characters.yaml`)
- Before a character can speak in any script, declare their ID, display `name`, hex `color`, and `default_sprite` in [characters.yaml](../../../characters.yaml).
- `narrator` is a built-in reserved ID for narration; **never** declare `narrator` or `options` in `characters.yaml`.
- Every character's `default_sprite` **must** exist under `sprite.<character_id>` in `assets.yaml`.

### Step 2: Create Visual Assets & Register in `assets.yaml`
- **Never** write file paths inside `assets/scripts/*.yaml`. All paths live exclusively in [assets.yaml](../../../assets.yaml) under five independent namespaces: `background`, `sprite`, `cg`, `bgm`, `voice`.
- If new visual assets (backgrounds, character expressions, CGs) are needed, generate SVG files following the canvas conventions in [references/svg-asset-templates.md](./references/svg-asset-templates.md):
  - **Backgrounds / CGs**: `viewBox="0 0 1600 900"` (16:9 widescreen).
  - **Character Sprites**: `viewBox="0 0 500 1000"` (1:2 full-body vertical canvas, feet aligned to the bottom center `y ≈ 965`). All expressions of the same character **must** share the exact same canvas dimensions and body alignment.
- Register every new file in `assets.yaml` before referencing its ID in a script.

### Step 3: Author or Edit Declarative Script (`assets/scripts/*.yaml`)
- Consult [references/script-syntax-cheatsheet.md](./references/script-syntax-cheatsheet.md) for exact YAML field rules.
- Key invariants to enforce while writing:
  1. **Exactly one `start: true`** scene across the entire script.
  2. **Scene background whitelist**: Every `initial` and inline `stage.background` in a scene **must** be listed in that scene's `backgrounds: [...]` array.
  3. **State inheritance**: Within a scene, a character automatically inherits their previous `sprite` and `at` coordinates if omitted. Entering a new scene clears all characters from the stage.
  4. **Narrator restrictions**: `narrator` lines can include `say`, `pause`, and `stage`, but **must never** include `sprite`, `at`, `voice`, or `animation`.
  5. **Options & DAG termination**: `options` may only appear on the **last line** of a scene, all `option.id` values within a line must be unique, every non-terminal scene without `options` must have a sequential successor, and the scene graph must be **acyclic (no loops)**.

### Step 4: Run Closed-Loop Validation (Mandatory)
After editing any YAML or SVG file, **always** run the validation script or test suite to verify zero syntax, reference, or file-existence errors:

```bash
flutter test test/script_validator_test.dart
```
Or run the standalone CLI validator directly:
```bash
flutter test .agents/skills/carnation-vn/scripts/validate_project.dart
```
If `ScriptValidationException` is reported (formatted as `[location] reason`), fix the exact scene/line or asset entry indicated before finishing your turn.
