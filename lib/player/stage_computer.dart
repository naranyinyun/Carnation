import '../assets/asset_models.dart';
import '../script/script_models.dart';
import 'playback_models.dart';

/// Pure deterministic calculator for `f(scene_id, lineIndex)`.
class StageComputer {
  const StageComputer({this.characters});

  final CharacterCatalog? characters;

  PlaybackState compute({
    required NovelScript script,
    required int sceneIndex,
    required int lineIndex,
    required List<(int sceneIndex, int lineIndex)> history,
    bool isEnded = false,
  }) {
    final scene = script.scenes[sceneIndex];
    final currentLine = scene.lines[lineIndex];

    var backgroundId = scene.initialBackground;
    var bgmId = scene.bgm;
    String? cgId;
    final stageCharacters = <String, StageCharacter>{};

    for (var i = 0; i <= lineIndex; i++) {
      final line = scene.lines[i];
      if (line.stage.backgroundId != null) {
        backgroundId = line.stage.backgroundId!;
      }
      if (line.stage.hasBgmChange) {
        bgmId = line.stage.bgmId;
      }
      if (line.stage.hasCgChange) {
        cgId = line.stage.cgId;
      }

      if (line.speakerId != CharacterCatalog.narratorId) {
        final previous = stageCharacters[line.speakerId];
        final defaultSprite =
            characters?.characters[line.speakerId]?.defaultSprite ?? 'neutral';
        final spriteId = line.spriteId ?? previous?.spriteId ?? defaultSprite;
        var position =
            line.position ?? previous?.position ?? const ScreenPosition(x: 0.5, y: 1.0);

        for (final anim in line.animations) {
          if (anim.verb == AnimationVerb.move && anim.target != null) {
            position = anim.target!;
          }
        }

        final hasExit = line.animations.any((anim) => anim.verb == AnimationVerb.exit);
        if (hasExit && i < lineIndex) {
          stageCharacters.remove(line.speakerId);
        } else {
          stageCharacters[line.speakerId] = StageCharacter(
            characterId: line.speakerId,
            spriteId: spriteId,
            position: position,
            isSpeaking: i == lineIndex && !isEnded,
            isExiting: hasExit && i == lineIndex,
            animations: i == lineIndex ? line.animations : const [],
          );
        }
      }

      if (i == lineIndex) {
        for (final entry in stageCharacters.entries.toList()) {
          if (entry.key != line.speakerId) {
            stageCharacters[entry.key] = StageCharacter(
              characterId: entry.value.characterId,
              spriteId: entry.value.spriteId,
              position: entry.value.position,
              isSpeaking: false,
              isExiting: false,
              animations: const [],
            );
          }
        }
      }
    }

    final transition =
        lineIndex == 0 ? scene.enterTransition : currentLine.stage.transition;

    final backlog = <BacklogEntry>[];
    for (final (sIdx, lIdx) in history) {
      if (sIdx < 0 || sIdx >= script.scenes.length) continue;
      final s = script.scenes[sIdx];
      if (lIdx < 0 || lIdx >= s.lines.length) continue;
      final l = s.lines[lIdx];
      if (l.text.isNotEmpty) {
        backlog.add(BacklogEntry(
          sceneIndex: sIdx,
          lineIndex: lIdx,
          sceneId: s.id,
          lineId: l.id,
          speakerId: l.speakerId,
          text: l.text,
          voiceId: l.voiceId,
        ));
      }
    }

    return PlaybackState(
      scene: scene,
      line: currentLine,
      sceneIndex: sceneIndex,
      lineIndex: lineIndex,
      activeBackgroundId: backgroundId,
      activeTransition: transition,
      activeCgId: cgId,
      activeBgmId: bgmId,
      characters: List.unmodifiable(stageCharacters.values),
      backlog: List.unmodifiable(backlog),
      canStepBack: history.length > 1 || isEnded,
      isEnded: isEnded,
    );
  }
}
