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
  });

  final String id;
  final List<String> backgrounds;
  final String initialBackground;
  final List<ScriptLine> lines;
  final bool isEnd;
  final bool isStart;
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
    this.options = const [],
  });

  final String id;
  final String speakerId;
  final String text;
  final String? spriteId;
  final String? backgroundId;
  final String? voiceId;
  final ScreenPosition? position;
  final List<ScriptOption> options;
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
