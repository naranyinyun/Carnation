import 'dart:async';

import '../script/script_models.dart';

class PlaybackState {
  const PlaybackState({
    required this.scene,
    required this.line,
    required this.sceneIndex,
    required this.lineIndex,
    this.isEnded = false,
  });

  final NovelScene scene;
  final ScriptLine line;
  final int sceneIndex;
  final int lineIndex;
  final bool isEnded;

  bool get isWaitingForChoice => line.options.isNotEmpty && !isEnded;
}

abstract interface class NovelPlayer {
  PlaybackState get state;
  Stream<PlaybackState> get states;
  void next();
  void choose(String optionId);
  Future<void> dispose();
}

class ScriptPlayer implements NovelPlayer {
  ScriptPlayer(this._script)
      : _sceneIndex = _script.scenes.indexWhere((scene) => scene.id == _script.startSceneId),
        _lineIndex = 0 {
    if (_sceneIndex < 0) throw StateError('Start scene is missing from script');
    _state = _snapshot();
  }

  final NovelScript _script;
  final StreamController<PlaybackState> _states = StreamController.broadcast();
  late PlaybackState _state;
  int _sceneIndex;
  int _lineIndex;

  @override
  PlaybackState get state => _state;

  @override
  Stream<PlaybackState> get states => _states.stream;

  @override
  void next() {
    if (_state.isEnded || _state.isWaitingForChoice) return;
    if (_lineIndex < _state.scene.lines.length - 1) {
      _lineIndex++;
      _publish();
      return;
    }

    if (_state.scene.isEnd) {
      _state = PlaybackState(
        scene: _state.scene,
        line: _state.line,
        sceneIndex: _sceneIndex,
        lineIndex: _lineIndex,
        isEnded: true,
      );
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

  void _enterScene(int index) {
    if (index < 0 || index >= _script.scenes.length) {
      throw StateError('Playback has no next scene');
    }
    _sceneIndex = index;
    _lineIndex = 0;
    _publish();
  }

  PlaybackState _snapshot() => PlaybackState(
        scene: _script.scenes[_sceneIndex],
        line: _script.scenes[_sceneIndex].lines[_lineIndex],
        sceneIndex: _sceneIndex,
        lineIndex: _lineIndex,
      );

  void _publish() {
    _state = _snapshot();
    _states.add(_state);
  }

  @override
  Future<void> dispose() => _states.close();
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
