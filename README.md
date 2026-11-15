# Carnation

Flutter visual novel player MVP. The first slice loads an authored YAML script, parses it into immutable story models, and plays it through a small scene player.

## Boundaries

- `lib/script/` owns script models and the YAML parser. `ScriptParser` is the parser interface.
- `lib/player/` owns playback state and scene/option progression. `NovelPlayer` is the player interface.
- `assets/scripts/` contains the story as data, separate from parser and player code.
- `lib/ui/` renders a `NovelPlayer` and does not parse YAML or decide story flow.

The example includes original SVG backgrounds and character sprites. Voice playback, animation, save data, and full-project asset validation are not part of this first slice. See [docs/architecture.md](docs/architecture.md) for module boundaries and run instructions.

Run with `flutter run` and select one of the configured targets: Android, iOS, Web, Linux, macOS, or Windows.
