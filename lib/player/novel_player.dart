import 'dart:async';

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

  final int slot;
  final String sceneId;
  final int sceneIndex;
  final int lineIndex;
  final String speakerId;
  final String previewText;
  final String backgroundId;
  final DateTime savedAt;
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

abstract interface class NovelPlayer {
  NovelScript get script;
  PlaybackState get state;
  Stream<PlaybackState> get states;
  Map<int, SaveBookmark> get saves;
  void next();
  void choose(String optionId);
  void stepBack();
  void restart();
  void jumpTo(int sceneIndex, int lineIndex);
  void jumpToScene(String sceneId);
  void saveSlot(int slot);
  void loadSlot(int slot);
  Future<void> dispose();
}

class ScriptPlayer implements NovelPlayer {
  ScriptPlayer(this._script)
      : _sceneIndex = _script.scenes.indexWhere((scene) => scene.id == _script.startSceneId),
        _lineIndex = 0 {
    if (_sceneIndex < 0) throw StateError('Start scene is missing from script');
    _recordVisit(_sceneIndex, _lineIndex);
    _state = _snapshot();
  }

  final NovelScript _script;
  final StreamController<PlaybackState> _states = StreamController.broadcast();
  final List<(int sceneIndex, int lineIndex)> _history = [];
  final Map<int, SaveBookmark> _saves = {};

  late PlaybackState _state;
  int _sceneIndex;
  int _lineIndex;

  @override
  NovelScript get script => _script;

  @override
  PlaybackState get state => _state;

  @override
  Stream<PlaybackState> get states => _states.stream;

  @override
  Map<int, SaveBookmark> get saves => Map.unmodifiable(_saves);

  @override
  void next() {
    if (_state.isEnded || _state.isWaitingForChoice) return;
    if (_lineIndex < _state.scene.lines.length - 1) {
      _lineIndex++;
      _recordVisit(_sceneIndex, _lineIndex);
      _publish();
      return;
    }

    if (_state.scene.isEnd) {
      _state = _snapshot(isEnded: true);
      _states.add(_state);
      return;
    }

    _enterScene(_sceneIndex + 1);
  }

  @override
  void choose(String optionId) {
    if (!_state.isWaitingForChoice) return;
    final option = _state.line.options.where((item) => item.id == optionId).firstOrNull;
    if (option == null) throw ArgumentError.value(optionId, 'optionId', 'Unknown option');
    final targetIndex = _script.scenes.indexWhere((scene) => scene.id == option.targetSceneId);
    if (targetIndex < 0) throw StateError('Option target is missing from script');
    _enterScene(targetIndex);
  }

  @override
  void stepBack() {
    if (_state.isEnded) {
      _publish(isEnded: false);
      return;
    }
    if (_history.length <= 1) return;
    _history.removeLast();
    final previous = _history.last;
    _sceneIndex = previous.$1;
    _lineIndex = previous.$2;
    _publish();
  }

  @override
  void restart() {
    _history.clear();
    _sceneIndex = _script.scenes.indexWhere((scene) => scene.id == _script.startSceneId);
    _lineIndex = 0;
    _recordVisit(_sceneIndex, _lineIndex);
    _publish();
  }

  @override
  void jumpTo(int sceneIndex, int lineIndex) {
    if (sceneIndex < 0 || sceneIndex >= _script.scenes.length) return;
    final scene = _script.scenes[sceneIndex];
    if (lineIndex < 0 || lineIndex >= scene.lines.length) return;
    _sceneIndex = sceneIndex;
    _lineIndex = lineIndex;
    _recordVisit(_sceneIndex, _lineIndex);
    _publish();
  }

  @override
  void jumpToScene(String sceneId) {
    final targetIndex = _script.scenes.indexWhere((scene) => scene.id == sceneId);
    if (targetIndex < 0) return;
    _sceneIndex = targetIndex;
    _lineIndex = 0;
    _recordVisit(_sceneIndex, _lineIndex);
    _publish();
  }

  @override
  void saveSlot(int slot) {
    final current = _state;
    _saves[slot] = SaveBookmark(
      slot: slot,
      sceneId: current.scene.id,
      sceneIndex: current.sceneIndex,
      lineIndex: current.lineIndex,
      speakerId: current.line.speakerId,
      previewText: current.line.text.isEmpty ? '（演出节拍）' : current.line.text.replaceAll('\n', ' '),
      backgroundId: current.activeBackgroundId,
      savedAt: DateTime.now(),
    );
    _states.add(_state);
  }

  @override
  void loadSlot(int slot) {
    final bookmark = _saves[slot];
    if (bookmark == null) return;
    jumpTo(bookmark.sceneIndex, bookmark.lineIndex);
  }

  void _enterScene(int index) {
    if (index < 0 || index >= _script.scenes.length) {
      throw StateError('Playback has no next scene');
    }
    _sceneIndex = index;
    _lineIndex = 0;
    _recordVisit(_sceneIndex, _lineIndex);
    _publish();
  }

  void _recordVisit(int sceneIndex, int lineIndex) {
    if (_history.isNotEmpty && _history.last == (sceneIndex, lineIndex)) return;
    _history.add((sceneIndex, lineIndex));
  }

  PlaybackState _snapshot({bool isEnded = false}) {
    final scene = _script.scenes[_sceneIndex];
    final currentLine = scene.lines[_lineIndex];

    var backgroundId = scene.initialBackground;
    var bgmId = scene.bgm;
    String? cgId;
    final stageCharacters = <String, StageCharacter>{};

    for (var i = 0; i <= _lineIndex; i++) {
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

      if (line.speakerId != 'narrator') {
        final previous = stageCharacters[line.speakerId];
        final spriteId = line.spriteId ?? previous?.spriteId ?? 'neutral';
        var position = line.position ?? previous?.position ?? const ScreenPosition(x: 0.5, y: 1.0);

        for (final anim in line.animations) {
          if (anim.verb == AnimationVerb.move && anim.target != null) {
            position = anim.target!;
          }
        }

        final hasExit = line.animations.any((anim) => anim.verb == AnimationVerb.exit);
        if (hasExit && i < _lineIndex) {
          stageCharacters.remove(line.speakerId);
        } else {
          stageCharacters[line.speakerId] = StageCharacter(
            characterId: line.speakerId,
            spriteId: spriteId,
            position: position,
            isSpeaking: i == _lineIndex && !isEnded,
            isExiting: hasExit && i == _lineIndex,
            animations: i == _lineIndex ? line.animations : const [],
          );
        }
      }

      if (i == _lineIndex) {
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

    final transition = _lineIndex == 0 ? scene.enterTransition : currentLine.stage.transition;

    final backlog = <BacklogEntry>[];
    for (final (sIdx, lIdx) in _history) {
      final s = _script.scenes[sIdx];
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
      sceneIndex: _sceneIndex,
      lineIndex: _lineIndex,
      activeBackgroundId: backgroundId,
      activeTransition: transition,
      activeCgId: cgId,
      activeBgmId: bgmId,
      characters: List.unmodifiable(stageCharacters.values),
      backlog: List.unmodifiable(backlog),
      canStepBack: _history.length > 1 || isEnded,
      isEnded: isEnded,
    );
  }

  void _publish({bool isEnded = false}) {
    _state = _snapshot(isEnded: isEnded);
    _states.add(_state);
  }

  @override
  Future<void> dispose() => _states.close();
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
