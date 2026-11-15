import 'package:yaml/yaml.dart';

import 'script_models.dart';

abstract interface class ScriptParser {
  NovelScript parse(String source);
}

/// Parses the scene and dialogue subset needed by the first player MVP.
/// Maps are traversed in source order so dialogue keeps its authored order.
class YamlScriptParser implements ScriptParser {
  @override
  NovelScript parse(String source) {
    final root = _map(loadYaml(source), 'document');
    _onlyKeys(root, {'scenes'}, 'document');
    final rawScenes = root['scenes'];
    if (rawScenes is! List || rawScenes.isEmpty) {
      throw const FormatException('scenes must be a non-empty list');
    }

    final scenes = <NovelScene>[];
    for (var sceneIndex = 0; sceneIndex < rawScenes.length; sceneIndex++) {
      scenes.add(_scene(rawScenes[sceneIndex], sceneIndex));
    }

    final startScenes = scenes.where((scene) => scene.isStart).toList();
    if (startScenes.length != 1) {
      throw const FormatException('Exactly one scene must declare start: true');
    }

    final ids = scenes.map((scene) => scene.id).toSet();
    if (ids.length != scenes.length) {
      throw const FormatException('Scene ids must be unique');
    }
    for (final scene in scenes) {
      if (!scene.isEnd && scene.lines.last.options.isEmpty && scenes.last.id == scene.id) {
        throw FormatException('Non-terminal scene "${scene.id}" has no successor');
      }
      for (final line in scene.lines) {
        for (final option in line.options) {
          if (!ids.contains(option.targetSceneId)) {
            throw FormatException('Unknown option target "${option.targetSceneId}"');
          }
        }
      }
    }

    return NovelScript(scenes: List.unmodifiable(scenes), startSceneId: startScenes.single.id);
  }

  NovelScene _scene(Object? value, int index) {
    final scene = _map(value, 'scenes[$index]');
    _onlyKeys(scene, {'id', 'backgrounds', 'initial', 'dialog', 'end', 'start', 'bgm', 'enter'}, 'scene');
    final id = _string(scene['id'], 'scene.id');
    final backgrounds = _stringList(scene['backgrounds'], 'scene.backgrounds');
    final initial = _string(scene['initial'], 'scene.initial');
    if (!backgrounds.contains(initial)) {
      throw FormatException('Scene "$id" initial background must be declared in backgrounds');
    }

    final dialog = _map(scene['dialog'], 'scene.dialog');
    if (dialog.isEmpty) throw FormatException('Scene "$id" must have at least one dialogue line');
    final lines = <ScriptLine>[];
    for (final entry in dialog.entries) {
      lines.add(_line(entry.key, entry.value, id));
    }

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      if (lines[lineIndex].options.isNotEmpty && lineIndex != lines.length - 1) {
        throw FormatException('Options must be on the last line of scene "$id"');
      }
      final backgroundId = lines[lineIndex].backgroundId;
      if (backgroundId != null && !backgrounds.contains(backgroundId)) {
        throw FormatException('Background "$backgroundId" is not declared by scene "$id"');
      }
    }

    return NovelScene(
      id: id,
      backgrounds: List.unmodifiable(backgrounds),
      initialBackground: initial,
      lines: List.unmodifiable(lines),
      isEnd: _optionalBool(scene['end'], false, 'scene.end'),
      isStart: _optionalBool(scene['start'], false, 'scene.start'),
    );
  }

  ScriptLine _line(Object? rawId, Object? value, String sceneId) {
    final lineId = _string(rawId, 'dialog line id');
    final row = _map(value, '$sceneId/$lineId');
    final selectors = row.keys.where((key) => key != 'options').toList();
    if (selectors.length != 1) {
      throw FormatException('$sceneId/$lineId must have exactly one speaker selector');
    }
    final speakerId = selectors.single;
    final speaker = _map(row[speakerId], '$sceneId/$lineId.$speakerId');
    _onlyKeys(speaker, {'say', 'voice', 'sprite', 'at', 'stage', 'animation', 'pause'}, 'speaker line');

    final stage = speaker.containsKey('stage') ? _map(speaker['stage'], 'stage') : const <String, Object?>{};
    _onlyKeys(stage, {'background', 'cg', 'bgm', 'transition'}, 'stage');
    final backgrounds = _map(row, '$sceneId/$lineId');
    final options = _options(backgrounds['options'], '$sceneId/$lineId');

    return ScriptLine(
      id: lineId,
      speakerId: speakerId,
      text: _string(speaker['say'], '$sceneId/$lineId.say'),
      spriteId: _optionalString(speaker['sprite'], 'sprite'),
      backgroundId: _optionalString(stage['background'], 'stage.background'),
      voiceId: _optionalString(speaker['voice'], 'voice'),
      position: speaker.containsKey('at') ? _position(speaker['at']) : null,
      options: List.unmodifiable(options),
    );
  }

  List<ScriptOption> _options(Object? value, String context) {
    if (value == null) return const [];
    if (value is! List) throw FormatException('$context.options must be a list');
    return value.indexed.map((indexed) {
      final option = _map(indexed.$2, '$context.options[${indexed.$1}]');
      _onlyKeys(option, {'id', 'say', 'to'}, 'option');
      return ScriptOption(
        id: _string(option['id'], 'option.id'),
        text: _string(option['say'], 'option.say'),
        targetSceneId: _string(option['to'], 'option.to'),
      );
    }).toList();
  }

  ScreenPosition _position(Object? value) {
    final position = _map(value, 'at');
    _onlyKeys(position, {'x', 'y'}, 'at');
    final x = _number(position['x'], 'at.x');
    final y = _number(position['y'], 'at.y');
    if (x < 0 || x > 1 || y < 0 || y > 1) {
      throw const FormatException('at coordinates must be between 0 and 1');
    }
    return ScreenPosition(x: x, y: y);
  }

  Map<String, Object?> _map(Object? value, String context) {
    if (value is! Map) throw FormatException('$context must be a map');
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) throw FormatException('$context keys must be strings');
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  void _onlyKeys(Map<String, Object?> value, Set<String> allowed, String context) {
    final unknown = value.keys.where((key) => !allowed.contains(key));
    if (unknown.isNotEmpty) throw FormatException('Unknown $context field "${unknown.first}"');
  }

  String _string(Object? value, String context) {
    if (value is! String) throw FormatException('$context must be a string');
    return value;
  }

  String? _optionalString(Object? value, String context) {
    if (value == null) return null;
    return _string(value, context);
  }

  List<String> _stringList(Object? value, String context) {
    if (value is! List) throw FormatException('$context must be a list');
    return value.indexed.map((entry) => _string(entry.$2, '$context[${entry.$1}]')).toList();
  }

  bool _optionalBool(Object? value, bool fallback, String context) {
    if (value == null) return fallback;
    if (value is! bool) throw FormatException('$context must be a boolean');
    return value;
  }

  double _number(Object? value, String context) {
    if (value is! num) throw FormatException('$context must be a number');
    return value.toDouble();
  }
}
