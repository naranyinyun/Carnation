import '../script/script_models.dart';

class StageCharacter {
  const StageCharacter({
    required this.characterId,
    required this.spriteId,
    required this.position,
    required this.isSpeaking,
    this.isExiting = false,
    this.animations = const [],
  });

  final String characterId;
  final String spriteId;
  final ScreenPosition position;
  final bool isSpeaking;
  final bool isExiting;
  final List<CharacterAnimation> animations;
}

class BacklogEntry {
  const BacklogEntry({
    required this.sceneIndex,
    required this.lineIndex,
    required this.sceneId,
    required this.lineId,
    required this.speakerId,
    required this.text,
    this.voiceId,
  });

  final int sceneIndex;
  final int lineIndex;
  final String sceneId;
  final String lineId;
  final String speakerId;
  final String text;
  final String? voiceId;
}

class SaveBookmark {
  const SaveBookmark({
    required this.slot,
    required this.sceneId,
    required this.sceneIndex,
    required this.lineIndex,
    required this.speakerId,
    required this.previewText,
    required this.backgroundId,
    required this.savedAt,
  });

  factory SaveBookmark.fromJson(Map<String, Object?> json) {
    final slot = json['slot'];
    final sceneId = json['sceneId'];
    final sceneIndex = json['sceneIndex'];
    final lineIndex = json['lineIndex'];
    final speakerId = json['speakerId'];
    final previewText = json['previewText'];
    final backgroundId = json['backgroundId'];
    final savedAtRaw = json['savedAt'];

    if (slot is! int ||
        slot <= 0 ||
        sceneId is! String ||
        sceneId.isEmpty ||
        sceneIndex is! int ||
        sceneIndex < 0 ||
        lineIndex is! int ||
        lineIndex < 0 ||
        speakerId is! String ||
        speakerId.isEmpty ||
        previewText is! String ||
        backgroundId is! String ||
        backgroundId.isEmpty ||
        savedAtRaw is! String) {
      throw const FormatException('Invalid SaveBookmark JSON structure');
    }

    final savedAt = DateTime.tryParse(savedAtRaw);
    if (savedAt == null) {
      throw const FormatException('Invalid SaveBookmark savedAt timestamp');
    }

    return SaveBookmark(
      slot: slot,
      sceneId: sceneId,
      sceneIndex: sceneIndex,
      lineIndex: lineIndex,
      speakerId: speakerId,
      previewText: previewText,
      backgroundId: backgroundId,
      savedAt: savedAt,
    );
  }

  final int slot;
  final String sceneId;
  final int sceneIndex;
  final int lineIndex;
  final String speakerId;
  final String previewText;
  final String backgroundId;
  final DateTime savedAt;

  Map<String, Object?> toJson() => {
        'slot': slot,
        'sceneId': sceneId,
        'sceneIndex': sceneIndex,
        'lineIndex': lineIndex,
        'speakerId': speakerId,
        'previewText': previewText,
        'backgroundId': backgroundId,
        'savedAt': savedAt.toIso8601String(),
      };
}

class PlaybackState {
  const PlaybackState({
    required this.scene,
    required this.line,
    required this.sceneIndex,
    required this.lineIndex,
    required this.activeBackgroundId,
    required this.activeTransition,
    required this.characters,
    required this.backlog,
    this.activeCgId,
    this.activeBgmId,
    this.canStepBack = false,
    this.isEnded = false,
  });

  final NovelScene scene;
  final ScriptLine line;
  final int sceneIndex;
  final int lineIndex;
  final String activeBackgroundId;
  final TransitionKind activeTransition;
  final String? activeCgId;
  final String? activeBgmId;
  final List<StageCharacter> characters;
  final List<BacklogEntry> backlog;
  final bool canStepBack;
  final bool isEnded;

  bool get isWaitingForChoice => line.options.isNotEmpty && !isEnded;
}
