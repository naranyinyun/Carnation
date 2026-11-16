import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../player/playback_models.dart';

/// Manages typewriter character reveal, Auto-Play, Skip mode, and silent beat timers
/// independently of the widget tree.
class PlaybackPaceController extends ChangeNotifier {
  bool _autoPlay = false;
  bool _skipMode = false;
  String _fullText = '';
  int _visibleChars = 0;
  String _lastLineSignature = '';
  bool _disposed = false;

  Timer? _typewriterTimer;
  Timer? _autoTimer;
  Timer? _beatTimer;

  bool get autoPlay => _autoPlay;
  bool get skipMode => _skipMode;
  bool get isTyping => _visibleChars < _fullText.length;

  String get displayedText =>
      _fullText.substring(0, _visibleChars.clamp(0, _fullText.length));

  void syncWithState(PlaybackState state, VoidCallback onAdvance) {
    final sig = '${state.sceneIndex}:${state.lineIndex}:${state.isEnded}';
    if (sig == _lastLineSignature) return;
    _lastLineSignature = sig;

    _cancelTimers();

    if (state.isWaitingForChoice || state.isEnded) {
      _skipMode = false;
      _autoPlay = false;
    }

    if (state.line.isSilentBeat && !state.isEnded) {
      _fullText = '';
      _visibleChars = 0;
      final pauseMs = ((state.line.pause ?? 0.8) * 1000).round();
      _beatTimer = Timer(Duration(milliseconds: _skipMode ? 120 : pauseMs), () {
        if (!_disposed) onAdvance();
      });
      return;
    }

    _fullText = state.line.text;
    if (_skipMode || _fullText.isEmpty) {
      _visibleChars = _fullText.length;
      _scheduleAutoOrSkip(state, onAdvance);
    } else {
      _visibleChars = 0;
      _typewriterTimer = Timer.periodic(const Duration(milliseconds: 28), (timer) {
        if (_disposed) {
          timer.cancel();
          return;
        }
        if (_visibleChars < _fullText.length) {
          _visibleChars++;
          notifyListeners();
        } else {
          timer.cancel();
          _scheduleAutoOrSkip(state, onAdvance);
        }
      });
    }
  }

  void completeOrAdvance(PlaybackState state, VoidCallback onAdvance) {
    if (state.line.isSilentBeat) {
      _beatTimer?.cancel();
      onAdvance();
      return;
    }
    if (isTyping) {
      _typewriterTimer?.cancel();
      _visibleChars = _fullText.length;
      notifyListeners();
      _scheduleAutoOrSkip(state, onAdvance);
      return;
    }
    if (!state.isWaitingForChoice && !state.isEnded) {
      onAdvance();
    }
  }

  void toggleAuto(PlaybackState state, VoidCallback onAdvance) {
    _autoPlay = !_autoPlay;
    if (_autoPlay) _skipMode = false;
    notifyListeners();

    if (_autoPlay && !isTyping) {
      _scheduleAutoOrSkip(state, onAdvance);
    } else if (!_autoPlay) {
      _autoTimer?.cancel();
    }
  }

  void toggleSkip(PlaybackState state, VoidCallback onAdvance) {
    if (state.isWaitingForChoice || state.isEnded) return;
    _skipMode = !_skipMode;
    if (_skipMode) {
      _autoPlay = false;
      _typewriterTimer?.cancel();
      _visibleChars = _fullText.length;
    }
    notifyListeners();

    if (_skipMode) {
      _scheduleAutoOrSkip(state, onAdvance);
    } else {
      _autoTimer?.cancel();
    }
  }

  void _scheduleAutoOrSkip(PlaybackState state, VoidCallback onAdvance) {
    _autoTimer?.cancel();
    if (state.isEnded || state.isWaitingForChoice) return;
    if (_skipMode) {
      _autoTimer = Timer(const Duration(milliseconds: 110), () {
        if (!_disposed && _skipMode) onAdvance();
      });
    } else if (_autoPlay) {
      _autoTimer = Timer(const Duration(milliseconds: 1350), () {
        if (!_disposed && _autoPlay && !isTyping) onAdvance();
      });
    }
  }

  void _cancelTimers() {
    _typewriterTimer?.cancel();
    _autoTimer?.cancel();
    _beatTimer?.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelTimers();
    super.dispose();
  }
}
