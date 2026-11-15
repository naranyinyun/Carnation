import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../player/novel_player.dart';
import '../script/script_models.dart';
import 'motion.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.player,
    this.initialDebugMode = false,
  });

  final NovelPlayer player;
  final bool initialDebugMode;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final FocusNode _focusNode = FocusNode();

  late bool _debugMode = widget.initialDebugMode;
  bool _hideUi = false;
  bool _autoPlay = false;
  bool _skipMode = false;

  String _fullText = '';
  int _visibleChars = 0;
  String _lastLineSignature = '';

  Timer? _typewriterTimer;
  Timer? _autoTimer;
  Timer? _beatTimer;

  bool get _isTyping => _visibleChars < _fullText.length;

  @override
  void initState() {
    super.initState();
    _syncLine(widget.player.state);
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _autoTimer?.cancel();
    _beatTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _syncLine(PlaybackState state) {
    final sig = '${state.sceneIndex}:${state.lineIndex}:${state.isEnded}';
    if (sig == _lastLineSignature) return;
    _lastLineSignature = sig;

    _typewriterTimer?.cancel();
    _autoTimer?.cancel();
    _beatTimer?.cancel();

    if (state.isWaitingForChoice || state.isEnded) {
      _skipMode = false;
      _autoPlay = false;
    }

    if (state.line.isSilentBeat && !state.isEnded) {
      _fullText = '';
      _visibleChars = 0;
      final pauseMs = ((state.line.pause ?? 0.8) * 1000).round();
      _beatTimer = Timer(Duration(milliseconds: _skipMode ? 120 : pauseMs), () {
        if (mounted) widget.player.next();
      });
      return;
    }

    _fullText = state.line.text;
    if (_skipMode || _fullText.isEmpty) {
      _visibleChars = _fullText.length;
      _scheduleAutoOrSkip(state);
    } else {
      _visibleChars = 0;
      _typewriterTimer = Timer.periodic(const Duration(milliseconds: 28), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_visibleChars < _fullText.length) {
          setState(() {
            _visibleChars++;
          });
        } else {
          timer.cancel();
          _scheduleAutoOrSkip(state);
        }
      });
    }
  }

  void _scheduleAutoOrSkip(PlaybackState state) {
    _autoTimer?.cancel();
    if (state.isEnded || state.isWaitingForChoice) return;
    if (_skipMode) {
      _autoTimer = Timer(const Duration(milliseconds: 110), () {
        if (mounted && _skipMode) widget.player.next();
      });
    } else if (_autoPlay) {
      _autoTimer = Timer(const Duration(milliseconds: 1350), () {
        if (mounted && _autoPlay && !_isTyping) widget.player.next();
      });
    }
  }

  void _handlePrimaryAdvance(PlaybackState state) {
    if (_hideUi) {
      setState(() => _hideUi = false);
      return;
    }
    if (state.line.isSilentBeat) {
      _beatTimer?.cancel();
      widget.player.next();
      return;
    }
    if (_isTyping) {
      _typewriterTimer?.cancel();
      setState(() {
        _visibleChars = _fullText.length;
      });
      _scheduleAutoOrSkip(state);
      return;
    }
    if (!state.isWaitingForChoice && !state.isEnded) {
      widget.player.next();
    }
  }

  void _toggleAuto(PlaybackState state) {
    setState(() {
      _autoPlay = !_autoPlay;
      if (_autoPlay) _skipMode = false;
    });
    if (_autoPlay && !_isTyping) {
      _scheduleAutoOrSkip(state);
    } else if (!_autoPlay) {
      _autoTimer?.cancel();
    }
  }

  void _toggleSkip(PlaybackState state) {
    if (state.isWaitingForChoice || state.isEnded) return;
    setState(() {
      _skipMode = !_skipMode;
      if (_skipMode) {
        _autoPlay = false;
        _typewriterTimer?.cancel();
        _visibleChars = _fullText.length;
      }
    });
    if (_skipMode) {
      _scheduleAutoOrSkip(state);
    } else {
      _autoTimer?.cancel();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event, PlaybackState state) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.arrowRight) {
      _handlePrimaryAdvance(state);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.backspace) {
      if (state.canStepBack) widget.player.stepBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyH) {
      setState(() => _hideUi = !_hideUi);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyA) {
      _toggleAuto(state);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyL) {
      _openBacklogSheet(context, state);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f3) {
      setState(() => _debugMode = !_debugMode);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _openBacklogSheet(BuildContext context, PlaybackState state) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '历史记录',
      barrierColor: Colors.black26,
      transitionDuration: M3Motion.medium,
      pageBuilder: (ctx, anim, secondaryAnim) {
        return _BacklogModal(
          entries: state.backlog,
          debugMode: _debugMode,
          onJump: (sIdx, lIdx) {
            Navigator.of(ctx).pop();
            widget.player.jumpTo(sIdx, lIdx);
          },
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) =>
          M3Motion.emphasizedScaleFade(child, anim, beginScale: 0.96),
    );
  }

  void _openSaveLoadSheet(BuildContext context) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '存取档',
      barrierColor: Colors.black26,
      transitionDuration: M3Motion.medium,
      pageBuilder: (ctx, anim, secondaryAnim) {
        return _SaveLoadModal(
          player: widget.player,
          debugMode: _debugMode,
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) =>
          M3Motion.emphasizedScaleFade(child, anim, beginScale: 0.96),
    );
  }

  void _openFlowchartSheet(BuildContext context, PlaybackState state) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '流程图',
      barrierColor: Colors.black26,
      transitionDuration: M3Motion.medium,
      pageBuilder: (ctx, anim, secondaryAnim) {
        return _FlowchartModal(
          script: widget.player.script,
          currentSceneId: state.scene.id,
          debugMode: _debugMode,
          onSelectScene: (sceneId) {
            Navigator.of(ctx).pop();
            widget.player.jumpToScene(sceneId);
          },
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) =>
          M3Motion.emphasizedScaleFade(child, anim, beginScale: 0.96),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      body: StreamBuilder<PlaybackState>(
        stream: widget.player.states,
        initialData: widget.player.state,
        builder: (context, snapshot) {
          final state = snapshot.requireData;
          _syncLine(state);

          return Focus(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: (node, event) => _handleKeyEvent(node, event, state),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 760;
                final showBottomPanel = !_hideUi && !state.line.isSilentBeat;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _handlePrimaryAdvance(state),
                  onSecondaryTap: () => setState(() => _hideUi = !_hideUi),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Background Layer
                      Positioned.fill(
                        child: _SceneBackdrop(
                          backgroundId: state.activeBackgroundId,
                          transition: state.activeTransition,
                        ),
                      ),

                      // 2. Soft Vignette
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x3805070D),
                                  Color(0x0005070D),
                                  Color(0x0005070D),
                                  Color(0x6605070D),
                                ],
                                stops: [0.0, 0.18, 0.72, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 3. Multi-Character Stage Layer
                      Positioned.fill(
                        child: IgnorePointer(
                          child: _CharacterStage(
                            characters: state.characters,
                            viewportSize: constraints.biggest,
                            sceneId: state.scene.id,
                            lineId: state.line.id,
                          ),
                        ),
                      ),

                      // 4. Event CG Overlay Layer
                      Positioned.fill(
                        child: IgnorePointer(
                          child: _CgOverlayLayer(
                            cgId: state.activeCgId,
                            debugMode: _debugMode,
                          ),
                        ),
                      ),

                      // 5. Top Bar
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          bottom: false,
                          child: AnimatedSlide(
                            duration: M3Motion.medium,
                            curve: M3Motion.emphasized,
                            offset: _hideUi ? const Offset(0, -1.2) : Offset.zero,
                            child: AnimatedOpacity(
                              duration: M3Motion.short,
                              opacity: _hideUi ? 0 : 1,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: wide ? 28 : 14,
                                  vertical: 12,
                                ),
                                child: _GalgameTopHud(
                                  state: state,
                                  debugMode: _debugMode,
                                  onToggleDebug: () => setState(() => _debugMode = !_debugMode),
                                  onOpenFlowchart: () => _openFlowchartSheet(context, state),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 6. Dialogue Box & Quick Bar
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: SafeArea(
                          top: false,
                          child: AnimatedSlide(
                            duration: M3Motion.medium,
                            curve: M3Motion.emphasized,
                            offset: showBottomPanel ? Offset.zero : const Offset(0, 0.35),
                            child: AnimatedOpacity(
                              duration: M3Motion.short,
                              opacity: showBottomPanel ? 1 : 0,
                              child: IgnorePointer(
                                ignoring: !showBottomPanel,
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    wide ? 52 : 14,
                                    0,
                                    wide ? 52 : 14,
                                    wide ? 20 : 12,
                                  ),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 980),
                                      child: _GalgameDialogueBox(
                                        state: state,
                                        debugMode: _debugMode,
                                        displayedText: _fullText.substring(
                                          0,
                                          _visibleChars.clamp(0, _fullText.length),
                                        ),
                                        isTyping: _isTyping,
                                        autoPlay: _autoPlay,
                                        skipMode: _skipMode,
                                        onStepBack: state.canStepBack ? widget.player.stepBack : null,
                                        onToggleAuto: () => _toggleAuto(state),
                                        onToggleSkip: () => _toggleSkip(state),
                                        onOpenLog: () => _openBacklogSheet(context, state),
                                        onOpenSaveLoad: () => _openSaveLoadSheet(context),
                                        onOpenFlowchart: () => _openFlowchartSheet(context, state),
                                        onHideUi: () => setState(() => _hideUi = true),
                                        onRestart: widget.player.restart,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 7. Choice Overlay
                      Positioned.fill(
                        child: AnimatedSwitcher(
                          duration: M3Motion.mediumLong,
                          reverseDuration: M3Motion.short,
                          child: state.isWaitingForChoice && !_hideUi
                              ? _ChoiceOverlay(
                                  key: ValueKey('choice_${state.scene.id}_${state.line.id}'),
                                  options: state.line.options,
                                  debugMode: _debugMode,
                                  onChoose: widget.player.choose,
                                )
                              : const SizedBox.shrink(key: ValueKey('no_choice')),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Scene Backdrop & CG Overlay
// ─────────────────────────────────────────────────────────────────────────────

class _SceneBackdrop extends StatelessWidget {
  const _SceneBackdrop({
    required this.backgroundId,
    required this.transition,
  });

  final String backgroundId;
  final TransitionKind transition;

  @override
  Widget build(BuildContext context) {
    final path = switch (backgroundId) {
      'classroom_noon' => 'assets/backgrounds/classroom_noon.svg',
      'classroom_dusk' => 'assets/backgrounds/classroom_dusk.svg',
      'classroom_dusk_rain' => 'assets/backgrounds/classroom_dusk_rain.svg',
      'rooftop_night' => 'assets/backgrounds/rooftop_night.svg',
      'rooftop_night_rain' => 'assets/backgrounds/rooftop_night_rain.svg',
      'hallway_night' => 'assets/backgrounds/hallway_night.svg',
      'gate_night' => 'assets/backgrounds/gate_night.svg',
      _ => null,
    };

    final duration = switch (transition) {
      TransitionKind.cut => const Duration(milliseconds: 120),
      TransitionKind.fade => const Duration(milliseconds: 620),
      TransitionKind.crossfade => const Duration(milliseconds: 520),
    };

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: M3Motion.standard,
      switchOutCurve: M3Motion.standard,
      transitionBuilder: (child, animation) {
        if (transition == TransitionKind.fade) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: const Interval(0.25, 1.0)),
            child: child,
          );
        }
        return FadeTransition(opacity: animation, child: child);
      },
      child: SizedBox.expand(
        key: ValueKey(backgroundId),
        child: path == null
            ? const ColoredBox(color: Color(0xFF161B28))
            : SvgPicture.asset(path, fit: BoxFit.cover),
      ),
    );
  }
}

class _CgOverlayLayer extends StatelessWidget {
  const _CgOverlayLayer({
    required this.cgId,
    required this.debugMode,
  });

  final String? cgId;
  final bool debugMode;

  @override
  Widget build(BuildContext context) {
    final path = switch (cgId) {
      'after_rain' => 'assets/cg/after_rain.svg',
      _ => null,
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 650),
      switchInCurve: M3Motion.emphasizedDecelerate,
      switchOutCurve: M3Motion.emphasizedAccelerate,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.03, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: path == null
          ? const SizedBox.shrink(key: ValueKey('no_cg'))
          : Stack(
              key: ValueKey('cg_$cgId'),
              fit: StackFit.expand,
              children: [
                SvgPicture.asset(path, fit: BoxFit.cover),
                if (debugMode)
                  Positioned(
                    top: 64,
                    left: 28,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x66101420),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        'CG: $cgId',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Multi-Character Stage & Action Verbs
// ─────────────────────────────────────────────────────────────────────────────

class _CharacterStage extends StatelessWidget {
  const _CharacterStage({
    required this.characters,
    required this.viewportSize,
    required this.sceneId,
    required this.lineId,
  });

  final List<StageCharacter> characters;
  final Size viewportSize;
  final String sceneId;
  final String lineId;

  @override
  Widget build(BuildContext context) {
    final sorted = [...characters]..sort((a, b) {
        if (a.isSpeaking == b.isSpeaking) return a.characterId.compareTo(b.characterId);
        return a.isSpeaking ? 1 : -1;
      });

    final spriteWidth = (viewportSize.width * 0.28).clamp(240.0, 360.0);
    final spriteHeight = viewportSize.height * 0.78;

    return Stack(
      key: ValueKey('stage_$sceneId'),
      clipBehavior: Clip.none,
      children: [
        for (final character in sorted)
          AnimatedPositioned(
            key: ValueKey('pos_${sceneId}_${character.characterId}'),
            duration: M3Motion.mediumLong,
            curve: M3Motion.emphasized,
            left: viewportSize.width * character.position.x - spriteWidth / 2,
            bottom: (1.0 - character.position.y) * viewportSize.height + 46,
            width: spriteWidth,
            height: spriteHeight,
            child: _AnimatedCharacterActor(
              character: character,
              lineId: lineId,
            ),
          ),
      ],
    );
  }
}

class _AnimatedCharacterActor extends StatefulWidget {
  const _AnimatedCharacterActor({
    required this.character,
    required this.lineId,
  });

  final StageCharacter character;
  final String lineId;

  @override
  State<_AnimatedCharacterActor> createState() => _AnimatedCharacterActorState();
}

class _AnimatedCharacterActorState extends State<_AnimatedCharacterActor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  String _lastTriggerKey = '';

  @override
  void initState() {
    super.initState();
    _triggerAnimations();
  }

  @override
  void didUpdateWidget(covariant _AnimatedCharacterActor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _triggerAnimations();
  }

  void _triggerAnimations() {
    final key = '${widget.lineId}_${widget.character.animations.length}_${widget.character.isExiting}';
    if (key == _lastTriggerKey) return;
    _lastTriggerKey = key;

    if (widget.character.animations.isNotEmpty) {
      final hasSlow = widget.character.animations.any((a) => a.style == ScriptAnimationStyle.slow);
      final hasFast = widget.character.animations.any((a) => a.style == ScriptAnimationStyle.fast);
      _controller.duration = Duration(
        milliseconds: hasSlow ? 760 : (hasFast ? 320 : 500),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final char = widget.character;
    final enterAnim = char.animations.where((a) => a.verb == AnimationVerb.enter).firstOrNull;
    final exitAnim = char.animations.where((a) => a.verb == AnimationVerb.exit).firstOrNull;
    final hasNod = char.animations.any((a) => a.verb == AnimationVerb.nod);
    final hasShake = char.animations.any((a) => a.verb == AnimationVerb.shake);
    final hasJump = char.animations.any((a) => a.verb == AnimationVerb.jump);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = M3Motion.emphasizedDecelerate.transform(_controller.value);
        final rawT = _controller.value;

        var dx = 0.0;
        var dy = 0.0;
        var opacity = 1.0;

        if (enterAnim != null) {
          opacity = t.clamp(0.0, 1.0);
          final dir = enterAnim.direction ?? 'front';
          if (dir == 'left') dx += (1.0 - t) * -90.0;
          if (dir == 'right') dx += (1.0 - t) * 90.0;
          if (dir == 'front') dy += (1.0 - t) * 28.0;
        }

        if (exitAnim != null) {
          opacity = (1.0 - t).clamp(0.0, 1.0);
          final dir = exitAnim.direction ?? 'back';
          if (dir == 'left') dx -= t * 110.0;
          if (dir == 'right') dx += t * 110.0;
          if (dir == 'back') dy += t * 24.0;
        }

        if (hasNod) {
          dy += math.sin(rawT * math.pi) * 16.0;
        }
        if (hasJump) {
          dy -= math.sin(rawT * math.pi) * 32.0;
        }
        if (hasShake) {
          dx += math.sin(rawT * math.pi * 4) * 11.0 * (1.0 - rawT);
        }

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: child,
          ),
        );
      },
      child: AnimatedScale(
        duration: M3Motion.medium,
        curve: M3Motion.emphasized,
        scale: char.isSpeaking ? 1.02 : 0.96,
        alignment: Alignment.bottomCenter,
        child: AnimatedOpacity(
          duration: M3Motion.medium,
          opacity: char.isSpeaking ? 1.0 : 0.72,
          child: ColorFiltered(
            colorFilter: char.isSpeaking
                ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                : const ColorFilter.mode(Color(0x550D111C), BlendMode.srcATop),
            child: AnimatedSwitcher(
              duration: M3Motion.short,
              switchInCurve: M3Motion.standardDecelerate,
              switchOutCurve: M3Motion.standardAccelerate,
              child: SvgPicture.asset(
                _spritePath(char.characterId, char.spriteId),
                key: ValueKey('${char.characterId}_${char.spriteId}'),
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                placeholderBuilder: (_) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Minimal Translucent Top HUD
// ─────────────────────────────────────────────────────────────────────────────

class _GalgameTopHud extends StatelessWidget {
  const _GalgameTopHud({
    required this.state,
    required this.debugMode,
    required this.onToggleDebug,
    required this.onOpenFlowchart,
  });

  final PlaybackState state;
  final bool debugMode;
  final VoidCallback onToggleDebug;
  final VoidCallback onOpenFlowchart;

  @override
  Widget build(BuildContext context) {
    final sceneTitle = _sceneDisplayTitle(state.scene.id);
    final animText = state.line.animations.map((a) => a.verb.name).join(',');

    return Row(
      children: [
        // Scene Title Pill
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x400E1320),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: AnimatedSwitcher(
                duration: M3Motion.medium,
                child: Text(
                  sceneTitle,
                  key: ValueKey(state.scene.id),
                  style: const TextStyle(
                    color: Color(0xFFF4EDE2),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Debug Telemetry Pill (Debug Mode Only)
        if (debugMode) ...[
          const SizedBox(width: 8),
          Flexible(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x480E1320),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x66F0C66B), width: 0.8),
                  ),
                  child: Text(
                    [
                      '${state.scene.id}/${state.line.id}',
                      'bg:${state.activeBackgroundId}',
                      'bgm:${state.activeBgmId ?? "off"}',
                      if (state.line.voiceId != null) 'v:${state.line.voiceId}',
                      if (animText.isNotEmpty) 'act:$animText',
                    ].join(' · '),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF0C66B),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],

        const Spacer(),

        // Flowchart Quick Button (Debug Mode Only)
        if (debugMode) ...[
          _GlassPillButton(
            icon: Icons.account_tree_outlined,
            label: '流程图',
            accent: const Color(0xFFF0C66B),
            onTap: onOpenFlowchart,
          ),
          const SizedBox(width: 8),
        ],

        // Mode Switcher Pill (玩家 / 调试)
        _GlassPillButton(
          icon: debugMode ? Icons.bug_report_outlined : Icons.person_outline_rounded,
          label: debugMode ? '调试' : '玩家',
          accent: debugMode ? const Color(0xFFE55B45) : Colors.white70,
          onTap: onToggleDebug,
        ),
      ],
    );
  }
}

class _GlassPillButton extends StatelessWidget {
  const _GlassPillButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: const Color(0x400E1320),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: accent.withValues(alpha: 0.45), width: 0.9),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: accent),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Crystal-Clear Glassmorphic Galgame Dialogue Window
// ─────────────────────────────────────────────────────────────────────────────

class _GalgameDialogueBox extends StatelessWidget {
  const _GalgameDialogueBox({
    required this.state,
    required this.debugMode,
    required this.displayedText,
    required this.isTyping,
    required this.autoPlay,
    required this.skipMode,
    required this.onStepBack,
    required this.onToggleAuto,
    required this.onToggleSkip,
    required this.onOpenLog,
    required this.onOpenSaveLoad,
    required this.onOpenFlowchart,
    required this.onHideUi,
    required this.onRestart,
  });

  final PlaybackState state;
  final bool debugMode;
  final String displayedText;
  final bool isTyping;
  final bool autoPlay;
  final bool skipMode;
  final VoidCallback? onStepBack;
  final VoidCallback onToggleAuto;
  final VoidCallback onToggleSkip;
  final VoidCallback onOpenLog;
  final VoidCallback onOpenSaveLoad;
  final VoidCallback onOpenFlowchart;
  final VoidCallback onHideUi;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final speakerMeta = _speakerProfile(state.line.speakerId);
    final isNarrator = state.line.speakerId == 'narrator';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Floating Speaker Nameplate
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 6),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: M3Motion.short,
                transitionBuilder: (child, anim) => M3Motion.fadeSlideTransition(
                  child,
                  anim,
                  beginOffset: const Offset(0, 0.18),
                ),
                child: ClipRRect(
                  key: ValueKey('plate_${state.line.speakerId}'),
                  borderRadius: BorderRadius.circular(10),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0x66101624),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: speakerMeta.color.withValues(alpha: 0.72),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: speakerMeta.color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: speakerMeta.color.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            speakerMeta.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(color: Colors.black87, blurRadius: 4),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Main Translucent Glass Dialogue Box
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 148),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x4512192B),
                    Color(0x620A0E18),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isNarrator
                      ? Colors.white.withValues(alpha: 0.24)
                      : speakerMeta.color.withValues(alpha: 0.48),
                  width: 1.1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x44000000),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dialogue Text
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 68),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: isNarrator ? const Color(0xFFEDE7DC) : Colors.white,
                            fontSize: 20,
                            height: 1.68,
                            letterSpacing: 0.5,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 1)),
                              Shadow(color: Colors.black87, blurRadius: 2, offset: Offset(0, 1)),
                            ],
                          ),
                          children: [
                            TextSpan(text: displayedText),
                            if (!isTyping && !state.isWaitingForChoice && !state.isEnded)
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: _BlinkingCursor(color: speakerMeta.color),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Controls Row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                    child: Row(
                      children: [
                        if (state.isEnded)
                          TextButton.icon(
                            onPressed: onRestart,
                            icon: const Icon(Icons.replay_rounded, size: 15),
                            label: const Text('重新开始'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFF0C66B),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        const Spacer(),
                        Wrap(
                          spacing: 2,
                          children: [
                            _QuickMenuButton(
                              icon: Icons.undo_rounded,
                              label: '回退',
                              onTap: onStepBack,
                            ),
                            _QuickMenuButton(
                              icon: Icons.subject_rounded,
                              label: '记录',
                              onTap: onOpenLog,
                            ),
                            _QuickMenuButton(
                              icon: Icons.play_arrow_rounded,
                              label: '自动',
                              isActive: autoPlay,
                              onTap: onToggleAuto,
                            ),
                            _QuickMenuButton(
                              icon: Icons.fast_forward_rounded,
                              label: '快进',
                              isActive: skipMode,
                              onTap: state.isWaitingForChoice || state.isEnded ? null : onToggleSkip,
                            ),
                            _QuickMenuButton(
                              icon: Icons.bookmark_border_rounded,
                              label: '存取',
                              onTap: onOpenSaveLoad,
                            ),
                            if (debugMode)
                              _QuickMenuButton(
                                icon: Icons.account_tree_outlined,
                                label: '流程',
                                onTap: onOpenFlowchart,
                              ),
                            _QuickMenuButton(
                              icon: Icons.visibility_off_outlined,
                              label: '隐藏',
                              onTap: onHideUi,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickMenuButton extends StatelessWidget {
  const _QuickMenuButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = !enabled
        ? Colors.white24
        : isActive
            ? const Color(0xFF111520)
            : Colors.white70;

    return Material(
      color: isActive ? const Color(0xFFF0C66B) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor({required this.color});

  final Color color;

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.25, end: 1.0).animate(_controller),
      child: Text(
        '▼',
        style: TextStyle(color: widget.color, fontSize: 13),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Translucent Choice Overlay
// ─────────────────────────────────────────────────────────────────────────────

class _ChoiceOverlay extends StatefulWidget {
  const _ChoiceOverlay({
    super.key,
    required this.options,
    required this.debugMode,
    required this.onChoose,
  });

  final List<ScriptOption> options;
  final bool debugMode;
  final ValueChanged<String> onChoose;

  @override
  State<_ChoiceOverlay> createState() => _ChoiceOverlayState();
}

class _ChoiceOverlayState extends State<_ChoiceOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: M3Motion.long,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scrimAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.65, curve: M3Motion.standardDecelerate),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(
          opacity: scrimAnimation,
          child: const ColoredBox(color: Color(0x38060911)),
        ),
        Align(
          alignment: const Alignment(0, -0.15),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < widget.options.length; i++) ...[
                    _StaggeredOptionButton(
                      option: widget.options[i],
                      index: i,
                      debugMode: widget.debugMode,
                      controller: _controller,
                      onChoose: widget.onChoose,
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StaggeredOptionButton extends StatelessWidget {
  const _StaggeredOptionButton({
    required this.option,
    required this.index,
    required this.debugMode,
    required this.controller,
    required this.onChoose,
  });

  final ScriptOption option;
  final int index;
  final bool debugMode;
  final AnimationController controller;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final start = math.min(0.12 + index * 0.1, 0.6);
    final end = math.min(start + 0.5, 1.0);
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: M3Motion.emphasizedDecelerate),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(animation),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: const Color(0x52121A2B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.35), width: 1.1),
              ),
              child: InkWell(
                onTap: () => onChoose(option.id),
                splashColor: const Color(0x33F0C66B),
                highlightColor: const Color(0x22F0C66B),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '❖',
                        style: TextStyle(color: Color(0xFFF0C66B), fontSize: 13),
                      ),
                      const SizedBox(width: 14),
                      Flexible(
                        child: Text(
                          option.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                      if (debugMode) ...[
                        const SizedBox(width: 10),
                        Text(
                          '→ ${option.targetSceneId}',
                          style: const TextStyle(
                            color: Color(0xCCF0C66B),
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. Modals: 历史记录, 存取档, 树状流程图 (Visual Tree Flowchart)
// ─────────────────────────────────────────────────────────────────────────────

class _BacklogModal extends StatelessWidget {
  const _BacklogModal({
    required this.entries,
    required this.debugMode,
    required this.onJump,
  });

  final List<BacklogEntry> entries;
  final bool debugMode;
  final void Function(int sceneIndex, int lineIndex) onJump;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 540),
        child: _GlassModalShell(
          title: '历史记录',
          onClose: () => Navigator.of(context).pop(),
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 18),
            itemBuilder: (context, index) {
              final item = entries[index];
              final profile = _speakerProfile(item.speakerId);
              return InkWell(
                onTap: () => onJump(item.sceneIndex, item.lineIndex),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                          item.speakerId == 'narrator' ? '' : profile.name,
                          style: TextStyle(
                            color: profile.color,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ),
                      if (debugMode)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            '${item.sceneId}/${item.lineId}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SaveLoadModal extends StatefulWidget {
  const _SaveLoadModal({
    required this.player,
    required this.debugMode,
  });

  final NovelPlayer player;
  final bool debugMode;

  @override
  State<_SaveLoadModal> createState() => _SaveLoadModalState();
}

class _SaveLoadModalState extends State<_SaveLoadModal> {
  @override
  Widget build(BuildContext context) {
    final saves = widget.player.saves;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 500),
        child: _GlassModalShell(
          title: '存取档',
          onClose: () => Navigator.of(context).pop(),
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final slot = index + 1;
              final bookmark = saves[slot];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0x33161E30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: bookmark != null ? const Color(0x66F0C66B) : Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '0$slot',
                      style: const TextStyle(
                        color: Color(0xFFF0C66B),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: bookmark == null
                          ? const Text(
                              '空',
                              style: TextStyle(color: Colors.white38, fontSize: 14),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _sceneDisplayTitle(bookmark.sceneId),
                                  style: const TextStyle(
                                    color: Color(0xFFF0C66B),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  bookmark.previewText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () {
                        widget.player.saveSlot(slot);
                        setState(() {});
                      },
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFF0C66B)),
                      child: const Text('存入'),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: bookmark == null
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              widget.player.loadSlot(slot);
                            },
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text('读取'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Visual Tree Diagram Flowchart (树状流程图)
// ─────────────────────────────────────────────────────────────────────────────

class _FlowchartEdge {
  const _FlowchartEdge({
    required this.fromId,
    required this.toId,
    this.label,
  });

  final String fromId;
  final String toId;
  final String? label;
}

class _FlowchartModal extends StatelessWidget {
  const _FlowchartModal({
    required this.script,
    required this.currentSceneId,
    required this.debugMode,
    required this.onSelectScene,
  });

  final NovelScript script;
  final String currentSceneId;
  final bool debugMode;
  final ValueChanged<String> onSelectScene;

  @override
  Widget build(BuildContext context) {
    // 1. Build edges & compute tree depth per scene
    final edges = <_FlowchartEdge>[];
    final depths = <String, int>{script.startSceneId: 0};

    for (var i = 0; i < script.scenes.length; i++) {
      final scene = script.scenes[i];
      final currentDepth = depths[scene.id] ?? i;
      final options = scene.lines.last.options;

      if (options.isNotEmpty) {
        for (final opt in options) {
          edges.add(_FlowchartEdge(
            fromId: scene.id,
            toId: opt.targetSceneId,
            label: _shortenOptionText(opt.text),
          ));
          final prevDepth = depths[opt.targetSceneId] ?? 0;
          if (currentDepth + 1 > prevDepth) {
            depths[opt.targetSceneId] = currentDepth + 1;
          }
        }
      } else if (!scene.isEnd && i + 1 < script.scenes.length) {
        final nextId = script.scenes[i + 1].id;
        edges.add(_FlowchartEdge(fromId: scene.id, toId: nextId));
        final prevDepth = depths[nextId] ?? 0;
        if (currentDepth + 1 > prevDepth) {
          depths[nextId] = currentDepth + 1;
        }
      }
    }

    // 2. Group scenes by tree column (depth)
    final columns = <int, List<NovelScene>>{};
    var maxDepth = 0;
    var maxRows = 1;
    for (final scene in script.scenes) {
      final d = depths[scene.id] ?? 0;
      if (d > maxDepth) maxDepth = d;
      final list = columns.putIfAbsent(d, () => []);
      list.add(scene);
      if (list.length > maxRows) maxRows = list.length;
    }

    const nodeW = 152.0;
    const nodeH = 74.0;
    const colGap = 76.0;
    const rowGap = 48.0;
    const padX = 36.0;
    const padY = 44.0;

    final canvasW = padX * 2 + (maxDepth + 1) * nodeW + maxDepth * colGap;
    final canvasH = math.max(300.0, padY * 2 + maxRows * nodeH + (maxRows - 1) * rowGap);

    final nodeCenters = <String, Offset>{};
    final nodeRects = <String, Rect>{};

    for (final entry in columns.entries) {
      final col = entry.key;
      final scenesInCol = entry.value;
      final totalColH = scenesInCol.length * nodeH + (scenesInCol.length - 1) * rowGap;
      final startY = (canvasH - totalColH) / 2;
      final x = padX + col * (nodeW + colGap);

      for (var row = 0; row < scenesInCol.length; row++) {
        final scene = scenesInCol[row];
        final y = startY + row * (nodeH + rowGap);
        final rect = Rect.fromLTWH(x, y, nodeW, nodeH);
        nodeRects[scene.id] = rect;
        nodeCenters[scene.id] = rect.center;
      }
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 460),
        child: _GlassModalShell(
          title: '流程图',
          onClose: () => Navigator.of(context).pop(),
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SizedBox(
                  width: canvasW,
                  height: canvasH,
                  child: Stack(
                    children: [
                      // Tree Connecting Lines & Branch Labels
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _TreeEdgePainter(
                            edges: edges,
                            nodeRects: nodeRects,
                          ),
                        ),
                      ),

                      // Tree Scene Nodes
                      for (final scene in script.scenes)
                        if (nodeRects[scene.id] != null)
                          Positioned.fromRect(
                            rect: nodeRects[scene.id]!,
                            child: _TreeSceneNode(
                              scene: scene,
                              isCurrent: scene.id == currentSceneId,
                              debugMode: debugMode,
                              onTap: () => onSelectScene(scene.id),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TreeSceneNode extends StatelessWidget {
  const _TreeSceneNode({
    required this.scene,
    required this.isCurrent,
    required this.debugMode,
    required this.onTap,
  });

  final NovelScene scene;
  final bool isCurrent;
  final bool debugMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isCurrent
        ? const Color(0xFFF0C66B)
        : scene.isEnd
            ? const Color(0xAAFF8F7D)
            : Colors.white30;

    return Material(
      color: isCurrent ? const Color(0x55E55B45) : const Color(0x40161F33),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: isCurrent ? 1.8 : 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _sceneDisplayTitle(scene.id),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (debugMode) ...[
                const SizedBox(height: 4),
                Text(
                  scene.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ] else if (scene.isEnd) ...[
                const SizedBox(height: 3),
                const Text(
                  '结局',
                  style: TextStyle(
                    color: Color(0xFFF0C66B),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TreeEdgePainter extends CustomPainter {
  const _TreeEdgePainter({
    required this.edges,
    required this.nodeRects,
  });

  final List<_FlowchartEdge> edges;
  final Map<String, Rect> nodeRects;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0x88E8D5B7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xFFF0C66B)
      ..style = PaintingStyle.fill;

    for (final edge in edges) {
      final fromRect = nodeRects[edge.fromId];
      final toRect = nodeRects[edge.toId];
      if (fromRect == null || toRect == null) continue;

      final start = Offset(fromRect.right, fromRect.center.dy);
      final end = Offset(toRect.left, toRect.center.dy);
      final midX = (start.dx + end.dx) / 2;

      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(midX, start.dy, midX, end.dy, end.dx, end.dy);

      canvas.drawPath(path, linePaint);
      canvas.drawCircle(start, 3.0, dotPaint);
      canvas.drawCircle(end, 3.5, dotPaint);

      if (edge.label != null && edge.label!.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(
            text: edge.label,
            style: const TextStyle(
              color: Color(0xFFF0C66B),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 90);

        final labelCenter = Offset(midX, (start.dy + end.dy) / 2 - 12);
        tp.paint(
          canvas,
          Offset(labelCenter.dx - tp.width / 2, labelCenter.dy - tp.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TreeEdgePainter oldDelegate) =>
      oldDelegate.edges != edges || oldDelegate.nodeRects != nodeRects;
}

class _GlassModalShell extends StatelessWidget {
  const _GlassModalShell({
    required this.title,
    required this.onClose,
    required this.child,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: const Color(0x640D121F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.25), width: 1.0),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 12, 10),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. Display Metadata Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SpeakerProfile {
  const _SpeakerProfile({
    required this.name,
    required this.color,
  });

  final String name;
  final Color color;
}

_SpeakerProfile _speakerProfile(String speakerId) {
  return switch (speakerId) {
    'lin' => const _SpeakerProfile(
        name: '林',
        color: Color(0xFF7BB0FF),
      ),
    'zhou' => const _SpeakerProfile(
        name: '周',
        color: Color(0xFFFFB86C),
      ),
    _ => const _SpeakerProfile(
        name: '旁白',
        color: Color(0xFFD6CBB8),
      ),
  };
}

String _sceneDisplayTitle(String sceneId) {
  return switch (sceneId) {
    'ch01.classroom' => '放学后的教室',
    'ch01.rooftop' => '雨中的天台',
    'ch01.hallway' => '夜间走廊',
    'ch01.gate_call' => '雨霁同归',
    'ch01.gate_quiet' => '余音独行',
    _ => sceneId,
  };
}

String _shortenOptionText(String text) {
  final cleaned = text.replaceAll(RegExp(r'[「」（）()]'), '').trim();
  if (cleaned.length <= 6) return cleaned;
  return '${cleaned.substring(0, 6)}…';
}

String _spritePath(String characterId, String spriteId) =>
    'assets/characters/${characterId}_$spriteId.svg';
