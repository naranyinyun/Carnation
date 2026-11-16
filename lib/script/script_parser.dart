import 'package:yaml/yaml.dart';

import 'script_models.dart';
import 'script_validator.dart';

abstract interface class ScriptParser {
  NovelScript parse(String source);
}

/// Parses the scene and dialogue specification from YAML into immutable models
/// and validates structural/reference rules via [ScriptValidator].
class YamlScriptParser implements ScriptParser {
  const YamlScriptParser({
    this.validator = const ScriptValidator(),
  });

  final ScriptValidator validator;

  @override
  NovelScript parse(String source) {
    final root = _map(loadYaml(source), 'document');
    _onlyKeys(root, {'scenes'}, 'document');
    final rawScenes = root['scenes'];
    if (rawScenes is! List || rawScenes.isEmpty) {
      throw const ScriptValidationException(
        location: 'document.scenes',
        reason: 'scenes must be a non-empty list',
      );
    }

    final scenes = <NovelScene>[];
    for (var sceneIndex = 0; sceneIndex < rawScenes.length; sceneIndex++) {
      scenes.add(_scene(rawScenes[sceneIndex], sceneIndex));
    }

    final startScenes = scenes.where((scene) => scene.isStart).toList();
    if (startScenes.length != 1) {
      throw const ScriptValidationException(
        location: 'scenes',
        reason: 'Exactly one scene must declare start: true',
      );
    }

    final script = NovelScript(
      scenes: List.unmodifiable(scenes),
      startSceneId: startScenes.single.id,
    );
    validator.validate(script);
    return script;
  }

  NovelScene _scene(Object? value, int index) {
    final scene = _map(value, 'scenes[$index]');
    _onlyKeys(
      scene,
      {'id', 'backgrounds', 'initial', 'dialog', 'end', 'start', 'bgm', 'enter'},
      'scenes[$index]',
    );
    final id = _string(scene['id'], 'scenes[$index].id');
    final backgrounds = _stringList(scene['backgrounds'], 'scene "$id".backgrounds');
    final initial = _string(scene['initial'], 'scene "$id".initial');

    final dialog = _map(scene['dialog'], 'scene "$id".dialog');
    if (dialog.isEmpty) {
      throw ScriptValidationException(
        location: 'scene "$id".dialog',
        reason: 'Scene "$id" must have at least one dialogue line',
      );
    }
    final lines = <ScriptLine>[];
    for (final entry in dialog.entries) {
      lines.add(_line(entry.key, entry.value, id));
    }

    return NovelScene(
      id: id,
      backgrounds: List.unmodifiable(backgrounds),
      initialBackground: initial,
      lines: List.unmodifiable(lines),
      isEnd: _optionalBool(scene['end'], false, 'scene "$id".end'),
      isStart: _optionalBool(scene['start'], false, 'scene "$id".start'),
      bgm: _optionalString(scene['bgm'], 'scene "$id".bgm'),
      enterTransition: _transition(scene['enter'], 'scene "$id".enter'),
    );
  }

  ScriptLine _line(Object? rawId, Object? value, String sceneId) {
    final lineId = _string(rawId, '$sceneId/dialog line id');
    final loc = '$sceneId/$lineId';
    final row = _map(value, loc);
    final selectors = row.keys.where((key) => key != 'options').toList();
    if (selectors.length != 1) {
      throw ScriptValidationException(
        location: loc,
        reason: 'Line must have exactly one speaker selector',
      );
    }
    final speakerId = selectors.single;
    final speaker = _map(row[speakerId], '$loc.$speakerId');
    _onlyKeys(
      speaker,
      {'say', 'voice', 'sprite', 'at', 'stage', 'animation', 'pause'},
      '$loc.$speakerId',
    );

    final stageMap = speaker.containsKey('stage')
        ? _map(speaker['stage'], '$loc.stage')
        : const <String, Object?>{};
    _onlyKeys(stageMap, {'background', 'cg', 'bgm', 'transition'}, '$loc.stage');

    final backgroundId = _optionalString(stageMap['background'], '$loc.stage.background');
    final stage = StageChange(
      backgroundId: backgroundId,
      hasCgChange: stageMap.containsKey('cg'),
      cgId: _optionalString(stageMap['cg'], '$loc.stage.cg'),
      hasBgmChange: stageMap.containsKey('bgm'),
      bgmId: _optionalString(stageMap['bgm'], '$loc.stage.bgm'),
      transition: _transition(stageMap['transition'], '$loc.stage.transition'),
    );

    final animations = _animations(speaker['animation'], '$loc.animation');
    final options = _options(row['options'], '$loc.options');

    return ScriptLine(
      id: lineId,
      speakerId: speakerId,
      text: _string(speaker['say'], '$loc.say'),
      spriteId: _optionalString(speaker['sprite'], '$loc.sprite'),
      backgroundId: backgroundId,
      voiceId: _optionalString(speaker['voice'], '$loc.voice'),
      position: speaker.containsKey('at') ? _position(speaker['at'], '$loc.at') : null,
      pause: speaker.containsKey('pause') ? _number(speaker['pause'], '$loc.pause') : null,
      stage: stage,
      animations: List.unmodifiable(animations),
      options: List.unmodifiable(options),
    );
  }

  List<CharacterAnimation> _animations(Object? value, String context) {
    if (value == null) return const [];
    if (value is! List) {
      throw ScriptValidationException(location: context, reason: 'animation must be a list');
    }
    final result = <CharacterAnimation>[];
    for (var i = 0; i < value.length; i++) {
      final item = _map(value[i], '$context[$i]');
      if (item.length != 1) {
        throw ScriptValidationException(
          location: '$context[$i]',
          reason: 'Each animation entry must declare exactly one animation verb',
        );
      }
      final verbName = item.keys.single;
      final params = _map(item[verbName], '$context[$i].$verbName');
      final style = _animationStyle(params['style'], '$context[$i].$verbName.style');

      switch (verbName) {
        case 'enter':
          _onlyKeys(params, {'from', 'style'}, '$context[$i].enter');
          result.add(CharacterAnimation(
            verb: AnimationVerb.enter,
            direction: _optionalString(params['from'], '$context[$i].enter.from') ?? 'front',
            style: style,
          ));
        case 'exit':
          _onlyKeys(params, {'to', 'style'}, '$context[$i].exit');
          result.add(CharacterAnimation(
            verb: AnimationVerb.exit,
            direction: _optionalString(params['to'], '$context[$i].exit.to') ?? 'back',
            style: style,
          ));
        case 'move':
          _onlyKeys(params, {'to', 'style'}, '$context[$i].move');
          result.add(CharacterAnimation(
            verb: AnimationVerb.move,
            target: params.containsKey('to') ? _position(params['to'], '$context[$i].move.to') : null,
            style: style,
          ));
        case 'nod':
          _onlyKeys(params, {'style'}, '$context[$i].nod');
          result.add(CharacterAnimation(verb: AnimationVerb.nod, style: style));
        case 'shake':
          _onlyKeys(params, {'style'}, '$context[$i].shake');
          result.add(CharacterAnimation(verb: AnimationVerb.shake, style: style));
        case 'jump':
          _onlyKeys(params, {'style'}, '$context[$i].jump');
          result.add(CharacterAnimation(verb: AnimationVerb.jump, style: style));
        default:
          throw ScriptValidationException(
            location: '$context[$i]',
            reason: 'Unknown animation verb "$verbName"',
          );
      }
    }
    return result;
  }

  TransitionKind _transition(Object? value, String context) {
    if (value == null) return TransitionKind.cut;
    return switch (_string(value, context)) {
      'cut' => TransitionKind.cut,
      'fade' => TransitionKind.fade,
      'crossfade' => TransitionKind.crossfade,
      final other => throw ScriptValidationException(
          location: context,
          reason: 'Unknown transition "$other"',
        ),
    };
  }

  ScriptAnimationStyle _animationStyle(Object? value, String context) {
    if (value == null) return ScriptAnimationStyle.normal;
    return switch (_string(value, context)) {
      'fast' => ScriptAnimationStyle.fast,
      'slow' => ScriptAnimationStyle.slow,
      final other => throw ScriptValidationException(
          location: context,
          reason: 'Unknown animation style "$other"',
        ),
    };
  }

  List<ScriptOption> _options(Object? value, String context) {
    if (value == null) return const [];
    if (value is! List) {
      throw ScriptValidationException(location: context, reason: 'options must be a list');
    }
    return value.indexed.map((indexed) {
      final option = _map(indexed.$2, '$context[${indexed.$1}]');
      _onlyKeys(option, {'id', 'say', 'to'}, '$context[${indexed.$1}]');
      return ScriptOption(
        id: _string(option['id'], '$context[${indexed.$1}].id'),
        text: _string(option['say'], '$context[${indexed.$1}].say'),
        targetSceneId: _string(option['to'], '$context[${indexed.$1}].to'),
      );
    }).toList();
  }

  ScreenPosition _position(Object? value, String context) {
    final position = _map(value, context);
    _onlyKeys(position, {'x', 'y'}, context);
    final x = _number(position['x'], '$context.x');
    final y = _number(position['y'], '$context.y');
    if (x < 0 || x > 1 || y < 0 || y > 1) {
      throw ScriptValidationException(
        location: context,
        reason: 'at coordinates must be between 0 and 1',
      );
    }
    return ScreenPosition(x: x, y: y);
  }

  Map<String, Object?> _map(Object? value, String context) {
    if (value is! Map) {
      throw ScriptValidationException(location: context, reason: 'Expected a map');
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw ScriptValidationException(location: context, reason: 'Map keys must be strings');
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  void _onlyKeys(Map<String, Object?> value, Set<String> allowed, String context) {
    final unknown = value.keys.where((key) => !allowed.contains(key));
    if (unknown.isNotEmpty) {
      throw ScriptValidationException(
        location: context,
        reason: 'Unknown field "${unknown.first}"',
      );
    }
  }

  String _string(Object? value, String context) {
    if (value is! String) {
      throw ScriptValidationException(location: context, reason: 'Expected a string');
    }
    return value;
  }

  String? _optionalString(Object? value, String context) {
    if (value == null) return null;
    return _string(value, context);
  }

  List<String> _stringList(Object? value, String context) {
    if (value is! List) {
      throw ScriptValidationException(location: context, reason: 'Expected a list');
    }
    return value.indexed.map((entry) => _string(entry.$2, '$context[${entry.$1}]')).toList();
  }

  bool _optionalBool(Object? value, bool fallback, String context) {
    if (value == null) return fallback;
    if (value is! bool) {
      throw ScriptValidationException(location: context, reason: 'Expected a boolean');
    }
    return value;
  }

  double _number(Object? value, String context) {
    if (value is! num) {
      throw ScriptValidationException(location: context, reason: 'Expected a number');
    }
    return value.toDouble();
  }
}
