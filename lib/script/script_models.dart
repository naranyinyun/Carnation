enum TransitionKind { cut, fade, crossfade }

enum AnimationVerb { enter, exit, move, nod, shake, jump }

enum ScriptAnimationStyle { normal, fast, slow }

class StageChange {
  const StageChange({
    this.backgroundId,
    this.hasCgChange = false,
    this.cgId,
    this.hasBgmChange = false,
    this.bgmId,
    this.transition = TransitionKind.cut,
  });

  final String? backgroundId;
  final bool hasCgChange;
  final String? cgId;
  final bool hasBgmChange;
  final String? bgmId;
  final TransitionKind transition;
}

class CharacterAnimation {
  const CharacterAnimation({
    required this.verb,
    this.direction,
    this.target,
    this.style = ScriptAnimationStyle.normal,
  });

  final AnimationVerb verb;
  final String? direction;
  final ScreenPosition? target;
  final ScriptAnimationStyle style;
}

class NovelScript {
  const NovelScript({required this.scenes, required this.startSceneId});

  final List<NovelScene> scenes;
  final String startSceneId;

  NovelScene sceneById(String id) => scenes.firstWhere((scene) => scene.id == id);
}

class NovelScene {
  const NovelScene({
    required this.id,
    required this.backgrounds,
    required this.initialBackground,
    required this.lines,
    required this.isEnd,
    required this.isStart,
    this.bgm,
    this.enterTransition = TransitionKind.cut,
  });

  final String id;
  final List<String> backgrounds;
  final String initialBackground;
  final List<ScriptLine> lines;
  final bool isEnd;
  final bool isStart;
  final String? bgm;
  final TransitionKind enterTransition;
}

class ScriptLine {
  const ScriptLine({
    required this.id,
    required this.speakerId,
    required this.text,
    this.spriteId,
    this.backgroundId,
    this.voiceId,
    this.position,
    this.pause,
    this.stage = const StageChange(),
    this.animations = const [],
    this.options = const [],
  });

  final String id;
  final String speakerId;
  final String text;
  final String? spriteId;
  final String? backgroundId;
  final String? voiceId;
  final ScreenPosition? position;
  final double? pause;
  final StageChange stage;
  final List<CharacterAnimation> animations;
  final List<ScriptOption> options;

  bool get isSilentBeat => text.isEmpty && (pause ?? 0) > 0;
}

class ScreenPosition {
  const ScreenPosition({required this.x, required this.y});

  final double x;
  final double y;
}

class ScriptOption {
  const ScriptOption({required this.id, required this.text, required this.targetSceneId});

  final String id;
  final String text;
  final String targetSceneId;
}
