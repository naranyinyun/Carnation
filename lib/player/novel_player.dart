import 'dart:async';

import '../assets/asset_models.dart';
import '../script/script_models.dart';
import 'playback_models.dart';
import 'save_repository.dart';
import 'stage_computer.dart';

export 'playback_models.dart';
export 'save_repository.dart';
export 'stage_computer.dart';

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
  ScriptPlayer(
    this._script, {
    CharacterCatalog? characters,
    SaveRepository? saveRepository,
  })  : _stageComputer = StageComputer(characters: characters),
        _saveRepository = saveRepository ?? InMemorySaveRepository(),
        _sceneIndex = _script.scenes.indexWhere((scene) => scene.id == _script.startSceneId),
        _lineIndex = 0 {
    if (_sceneIndex < 0) throw StateError('Start scene is missing from script');
    _saves.addAll(_saveRepository.loadAll(script: _script));
    _recordVisit(_sceneIndex, _lineIndex);
    _state = _computeState();
  }

  final NovelScript _script;
  final StageComputer _stageComputer;
  final SaveRepository _saveRepository;
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
      _state = _computeState(isEnded: true);
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
    if (slot <= 0) throw ArgumentError.value(slot, 'slot', 'Slot must be positive');
    final current = _state;
    final bookmark = SaveBookmark(
      slot: slot,
      sceneId: current.scene.id,
      sceneIndex: current.sceneIndex,
      lineIndex: current.lineIndex,
      speakerId: current.line.speakerId,
      previewText: current.line.text.isEmpty ? '（演出节拍）' : current.line.text.replaceAll('\n', ' '),
      backgroundId: current.activeBackgroundId,
      savedAt: DateTime.now(),
    );
    _saves[slot] = bookmark;
    _saveRepository.save(bookmark);
    _states.add(_state);
  }

  @override
  void loadSlot(int slot) {
    final bookmark = _saves[slot];
    if (bookmark == null) return;
    final targetSceneIndex = _script.scenes.indexWhere((s) => s.id == bookmark.sceneId);
    if (targetSceneIndex < 0) {
      _saves.remove(slot);
      _saveRepository.delete(slot);
      _states.add(_state);
      return;
    }
    final scene = _script.scenes[targetSceneIndex];
    if (bookmark.lineIndex < 0 || bookmark.lineIndex >= scene.lines.length) {
      _saves.remove(slot);
      _saveRepository.delete(slot);
      _states.add(_state);
      return;
    }
    jumpTo(targetSceneIndex, bookmark.lineIndex);
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

  PlaybackState _computeState({bool isEnded = false}) {
    return _stageComputer.compute(
      script: _script,
      sceneIndex: _sceneIndex,
      lineIndex: _lineIndex,
      history: _history,
      isEnded: isEnded,
    );
  }

  void _publish({bool isEnded = false}) {
    _state = _computeState(isEnded: isEnded);
    _states.add(_state);
  }

  @override
  Future<void> dispose() => _states.close();
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
