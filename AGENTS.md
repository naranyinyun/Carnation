# Carnation — AI-Native Visual Novel Engine Guide (`AGENTS.md`)

Carnation is a declarative, zero-state, DAG-based visual novel engine built with Flutter. Because stage state is a pure deterministic function `f(scene_id, lineIndex)` and all assets/scripts are declarative YAML + SVG, AI agents can create and verify complete visual novels end-to-end without manual GUI intervention.

## Specialized Agent Skill

When authoring or modifying stories, characters, SVG illustrations, or debugging script errors, load and follow the workspace skill:

- **Skill Entry**: [`.agents/skills/carnation-vn/SKILL.md`](./.agents/skills/carnation-vn/SKILL.md)
- **Syntax Cheatsheet**: [`.agents/skills/carnation-vn/references/script-syntax-cheatsheet.md`](./.agents/skills/carnation-vn/references/script-syntax-cheatsheet.md)
- **SVG Art Templates**: [`.agents/skills/carnation-vn/references/svg-asset-templates.md`](./.agents/skills/carnation-vn/references/svg-asset-templates.md)

## Quick Verification Commands

Always run these commands after modifying any YAML script, asset catalog, or Dart source file:

```bash
# Validate all YAML scripts, character/asset references, DAG acyclic rules, and SVG file existence
flutter test .agents/skills/carnation-vn/scripts/validate_project.dart

# Run full unit & widget test suite
flutter test

# Run static analyzer
flutter analyze
```
