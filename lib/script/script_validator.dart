import '../assets/asset_models.dart';
import 'script_models.dart';

class ScriptValidationException implements FormatException {
  const ScriptValidationException({
    required this.location,
    required this.reason,
    this.source,
  });

  final String location;
  final String reason;

  @override
  final dynamic source;

  @override
  int? get offset => null;

  @override
  String get message => '[$location] $reason';

  @override
  String toString() => 'ScriptValidationException: [$location] $reason';
}

class ScriptValidator {
  const ScriptValidator({
    this.assets,
    this.characters,
    this.fileExists,
    this.checkAudioFiles = false,
  });

  final AssetCatalog? assets;
  final CharacterCatalog? characters;
  final bool Function(String path)? fileExists;
  final bool checkAudioFiles;

  void validate(NovelScript script) {
    _validateCatalogConsistency();
    _validateFileExistence();
    _validateScenes(script);
    _validateAcyclicGraph(script);
  }

  Future<void> validateAsync(
    NovelScript script, {
    required Future<bool> Function(String path) assetExists,
  }) async {
    _validateCatalogConsistency();
    if (assets != null) {
      for (final entry in assets!.visualEntries) {
        if (!await assetExists(entry.path)) {
          throw ScriptValidationException(
            location: 'assets.${entry.category}.${entry.id}',
            reason: 'Referenced asset file "${entry.path}" does not exist',
          );
        }
      }
      if (checkAudioFiles) {
        for (final entry in assets!.audioEntries) {
          if (!await assetExists(entry.path)) {
            throw ScriptValidationException(
              location: 'assets.${entry.category}.${entry.id}',
              reason: 'Referenced audio file "${entry.path}" does not exist',
            );
          }
        }
      }
    }
    _validateScenes(script);
    _validateAcyclicGraph(script);
  }

  void _validateCatalogConsistency() {
    if (assets == null || characters == null) return;
    for (final profile in characters!.characters.values) {
      final defaultSprite = profile.defaultSprite;
      if (defaultSprite == null || defaultSprite.isEmpty) {
        throw ScriptValidationException(
          location: 'characters.${profile.id}',
          reason: 'Character "${profile.id}" must declare a default_sprite',
        );
      }
      if (!assets!.hasSprite(profile.id, defaultSprite)) {
        throw ScriptValidationException(
          location: 'characters.${profile.id}.default_sprite',
          reason:
              'Default sprite "$defaultSprite" for character "${profile.id}" is not declared in assets.yaml',
        );
      }
    }
  }

  void _validateFileExistence() {
    if (assets == null || fileExists == null) return;
    for (final entry in assets!.visualEntries) {
      if (!fileExists!(entry.path)) {
        throw ScriptValidationException(
          location: 'assets.${entry.category}.${entry.id}',
          reason: 'Referenced asset file "${entry.path}" does not exist',
        );
      }
    }
    if (checkAudioFiles) {
      for (final entry in assets!.audioEntries) {
        if (!fileExists!(entry.path)) {
          throw ScriptValidationException(
            location: 'assets.${entry.category}.${entry.id}',
            reason: 'Referenced audio file "${entry.path}" does not exist',
          );
        }
      }
    }
  }

  void _validateScenes(NovelScript script) {
    if (script.scenes.isEmpty) {
      throw const ScriptValidationException(
        location: 'scenes',
        reason: 'scenes must be a non-empty list',
      );
    }

    final sceneIds = <String>{};
    for (final scene in script.scenes) {
      if (!sceneIds.add(scene.id)) {
        throw ScriptValidationException(
          location: 'scene "${scene.id}"',
          reason: 'Duplicate scene id "${scene.id}"',
        );
      }
    }

    final startScenes = script.scenes.where((s) => s.isStart).toList();
    if (startScenes.length != 1) {
      throw const ScriptValidationException(
        location: 'scenes',
        reason: 'Exactly one scene must declare start: true',
      );
    }

    for (var sceneIndex = 0; sceneIndex < script.scenes.length; sceneIndex++) {
      final scene = script.scenes[sceneIndex];
      final sceneLoc = 'scene "${scene.id}"';

      if (scene.backgrounds.isEmpty) {
        throw ScriptValidationException(
          location: sceneLoc,
          reason: 'Scene "${scene.id}" must declare at least one background',
        );
      }

      if (!scene.backgrounds.contains(scene.initialBackground)) {
        throw ScriptValidationException(
          location: '$sceneLoc.initial',
          reason:
              'Scene "${scene.id}" initial background "${scene.initialBackground}" must be declared in backgrounds',
        );
      }

      if (assets != null) {
        for (final bg in scene.backgrounds) {
          if (!assets!.hasBackground(bg)) {
            throw ScriptValidationException(
              location: '$sceneLoc.backgrounds',
              reason: 'Background "$bg" is not declared in assets.yaml',
            );
          }
        }
        if (scene.bgm != null && !assets!.hasBgm(scene.bgm!)) {
          throw ScriptValidationException(
            location: '$sceneLoc.bgm',
            reason: 'BGM "${scene.bgm}" is not declared in assets.yaml',
          );
        }
      }

      if (scene.lines.isEmpty) {
        throw ScriptValidationException(
          location: '$sceneLoc.dialog',
          reason: 'Scene "${scene.id}" must have at least one dialogue line',
        );
      }

      final lineIds = <String>{};
      for (var lineIndex = 0; lineIndex < scene.lines.length; lineIndex++) {
        final line = scene.lines[lineIndex];
        final lineLoc = '${scene.id}/${line.id}';

        if (!lineIds.add(line.id)) {
          throw ScriptValidationException(
            location: lineLoc,
            reason: 'Duplicate line id "${line.id}" in scene "${scene.id}"',
          );
        }

        if (line.options.isNotEmpty && lineIndex != scene.lines.length - 1) {
          throw ScriptValidationException(
            location: lineLoc,
            reason: 'Options must be on the last line of scene "${scene.id}"',
          );
        }

        final bgOverride = line.stage.backgroundId ?? line.backgroundId;
        if (bgOverride != null && !scene.backgrounds.contains(bgOverride)) {
          throw ScriptValidationException(
            location: '$lineLoc.stage.background',
            reason: 'Background "$bgOverride" is not declared by scene "${scene.id}"',
          );
        }

        _validateSpeakerAndLineAssets(line, lineLoc);
        _validateLineOptions(line.options, sceneIds, lineLoc);
      }

      if (!scene.isEnd &&
          scene.lines.last.options.isEmpty &&
          sceneIndex == script.scenes.length - 1) {
        throw ScriptValidationException(
          location: sceneLoc,
          reason: 'Non-terminal scene "${scene.id}" has no successor',
        );
      }
    }
  }

  void _validateSpeakerAndLineAssets(ScriptLine line, String lineLoc) {
    final isNarrator = line.speakerId == CharacterCatalog.narratorId;

    if (isNarrator) {
      if (line.spriteId != null) {
        throw ScriptValidationException(
          location: '$lineLoc.narrator.sprite',
          reason: 'Narrator line cannot declare a sprite',
        );
      }
      if (line.voiceId != null) {
        throw ScriptValidationException(
          location: '$lineLoc.narrator.voice',
          reason: 'Narrator line cannot declare a voice',
        );
      }
      if (line.position != null) {
        throw ScriptValidationException(
          location: '$lineLoc.narrator.at',
          reason: 'Narrator line cannot declare screen position "at"',
        );
      }
      if (line.animations.isNotEmpty) {
        throw ScriptValidationException(
          location: '$lineLoc.narrator.animation',
          reason: 'Narrator line cannot declare character animations',
        );
      }
    } else if (characters != null && !characters!.hasCharacter(line.speakerId)) {
      throw ScriptValidationException(
        location: lineLoc,
        reason: 'Unknown character "${line.speakerId}" (not declared in characters.yaml)',
      );
    }

    if (assets != null) {
      if (!isNarrator && line.spriteId != null) {
        if (!assets!.hasSprite(line.speakerId, line.spriteId!)) {
          throw ScriptValidationException(
            location: '$lineLoc.${line.speakerId}.sprite',
            reason:
                'Unknown sprite "${line.spriteId}" for character "${line.speakerId}" (not declared in assets.yaml)',
          );
        }
      }
      if (line.voiceId != null && !assets!.hasVoice(line.voiceId!)) {
        throw ScriptValidationException(
          location: '$lineLoc.${line.speakerId}.voice',
          reason: 'Unknown voice "${line.voiceId}" (not declared in assets.yaml)',
        );
      }
      if (line.stage.cgId != null && !assets!.hasCg(line.stage.cgId!)) {
        throw ScriptValidationException(
          location: '$lineLoc.stage.cg',
          reason: 'Unknown CG "${line.stage.cgId}" (not declared in assets.yaml)',
        );
      }
      if (line.stage.bgmId != null && !assets!.hasBgm(line.stage.bgmId!)) {
        throw ScriptValidationException(
          location: '$lineLoc.stage.bgm',
          reason: 'Unknown BGM "${line.stage.bgmId}" (not declared in assets.yaml)',
        );
      }
    }
  }

  void _validateLineOptions(
    List<ScriptOption> options,
    Set<String> sceneIds,
    String lineLoc,
  ) {
    final optionIds = <String>{};
    for (final option in options) {
      if (!optionIds.add(option.id)) {
        throw ScriptValidationException(
          location: '$lineLoc.options',
          reason: 'Duplicate option id "${option.id}"',
        );
      }
      if (!sceneIds.contains(option.targetSceneId)) {
        throw ScriptValidationException(
          location: '$lineLoc.options[${option.id}]',
          reason: 'Unknown option target "${option.targetSceneId}"',
        );
      }
    }
  }

  void _validateAcyclicGraph(NovelScript script) {
    final indexById = <String, int>{
      for (var i = 0; i < script.scenes.length; i++) script.scenes[i].id: i,
    };

    // 0 = unvisited, 1 = visiting, 2 = visited
    final state = <String, int>{};

    void dfs(String sceneId) {
      state[sceneId] = 1;
      final index = indexById[sceneId]!;
      final scene = script.scenes[index];
      final lastOptions = scene.lines.last.options;

      final targets = <String>[];
      if (lastOptions.isNotEmpty) {
        for (final opt in lastOptions) {
          targets.add(opt.targetSceneId);
        }
      } else if (!scene.isEnd && index + 1 < script.scenes.length) {
        targets.add(script.scenes[index + 1].id);
      }

      for (final nextId in targets) {
        final nextState = state[nextId] ?? 0;
        if (nextState == 1) {
          throw ScriptValidationException(
            location: 'scene "$sceneId"',
            reason: 'Scene graph contains a cycle involving "$nextId"',
          );
        }
        if (nextState == 0) {
          dfs(nextId);
        }
      }

      state[sceneId] = 2;
    }

    for (final scene in script.scenes) {
      if ((state[scene.id] ?? 0) == 0) {
        dfs(scene.id);
      }
    }
  }
}
