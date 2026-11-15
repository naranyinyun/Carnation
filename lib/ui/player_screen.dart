import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../player/novel_player.dart';
import '../script/script_models.dart';
import 'motion.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key, required this.player});

  final NovelPlayer player;

  static const _paper = Color(0xFFE8E0C0);
  static const _ink = Color(0xFF292721);
  static const _signal = Color(0xFFE55B45);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<PlaybackState>(
          stream: player.states,
          initialData: player.state,
          builder: (context, snapshot) {
            final state = snapshot.requireData;
            final backgroundId = state.line.backgroundId ?? state.scene.initialBackground;
            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 760;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: _SceneBackdrop(backgroundId: backgroundId),
                    ),
                    Positioned.fill(
                      child: _CharacterStage(
                        line: state.line,
                        viewportSize: constraints.biggest,
                      ),
                    ),
                    Positioned(
                      top: 20,
                      left: 24,
                      right: 24,
                      child: _SceneHeader(
                        sceneId: state.scene.id,
                        backgroundId: backgroundId,
                      ),
                    ),
                    Positioned.fill(
                      child: AnimatedSwitcher(
                        duration: M3Motion.mediumLong,
                        reverseDuration: M3Motion.medium,
                        switchInCurve: M3Motion.emphasizedDecelerate,
                        switchOutCurve: M3Motion.emphasizedAccelerate,
                        transitionBuilder: (child, animation) {
                          if (child.key == const ValueKey('choice_overlay')) {
                            return FadeTransition(opacity: animation, child: child);
                          }
                          return M3Motion.emphasizedScaleFade(
                            child,
                            animation,
                            beginScale: 0.97,
                            beginOffset: const Offset(0, 0.04),
                          );
                        },
                        child: state.isWaitingForChoice
                            ? _ChoiceOverlay(
                                key: const ValueKey('choice_overlay'),
                                options: state.line.options,
                                onChoose: player.choose,
                              )
                            : Align(
                                key: const ValueKey('dialogue_layer'),
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    wide ? 64 : 18,
                                    110,
                                    wide ? 64 : 18,
                                    24,
                                  ),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 900),
                                    child: _DialoguePanel(
                                      state: state,
                                      onNext: player.next,
                                      onChoose: player.choose,
                                      paper: _paper,
                                      ink: _ink,
                                      signal: _signal,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CharacterStage extends StatelessWidget {
  const _CharacterStage({
    required this.line,
    required this.viewportSize,
  });

  final ScriptLine line;
  final Size viewportSize;

  @override
  Widget build(BuildContext context) {
    final hasSprite = line.speakerId != 'narrator' && line.spriteId != null;
    final speakerKey = hasSprite ? ValueKey('speaker_${line.speakerId}') : const ValueKey('speaker_none');

    return AnimatedSwitcher(
      duration: M3Motion.medium,
      reverseDuration: M3Motion.short,
      switchInCurve: M3Motion.emphasizedDecelerate,
      switchOutCurve: M3Motion.emphasizedAccelerate,
      transitionBuilder: (child, animation) => M3Motion.emphasizedScaleFade(
        child,
        animation,
        beginScale: 0.96,
        beginOffset: const Offset(0, 0.03),
      ),
      child: hasSprite
          ? Stack(
              key: speakerKey,
              children: [
                AnimatedPositioned(
                  duration: M3Motion.mediumLong,
                  curve: M3Motion.emphasized,
                  left: viewportSize.width * (line.position?.x ?? 0.5) - 150,
                  bottom: 120,
                  width: 300,
                  height: viewportSize.height * 0.72,
                  child: AnimatedSwitcher(
                    duration: M3Motion.short,
                    switchInCurve: M3Motion.standardDecelerate,
                    switchOutCurve: M3Motion.standardAccelerate,
                    child: SvgPicture.asset(
                      _spritePath(line.speakerId, line.spriteId!),
                      key: ValueKey('${line.speakerId}_${line.spriteId}'),
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                      placeholderBuilder: (_) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            )
          : const SizedBox.expand(key: ValueKey('speaker_none')),
    );
  }
}

class _ChoiceOverlay extends StatefulWidget {
  const _ChoiceOverlay({
    super.key,
    required this.options,
    required this.onChoose,
  });

  final List<ScriptOption> options;
  final ValueChanged<String> onChoose;

  @override
  State<_ChoiceOverlay> createState() => _ChoiceOverlayState();
}

class _ChoiceOverlayState extends State<_ChoiceOverlay> with SingleTickerProviderStateMixin {
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
    final titleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.6, curve: M3Motion.emphasizedDecelerate),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(
          opacity: scrimAnimation,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 9, sigmaY: 9),
            child: const ColoredBox(color: Color(0x990D1020)),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: titleAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.25),
                        end: Offset.zero,
                      ).animate(titleAnimation),
                      child: const Text(
                        '選択',
                        style: TextStyle(color: Color(0xFFF1D9D2), fontSize: 13, letterSpacing: 8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (var i = 0; i < widget.options.length; i++) ...[
                    _StaggeredOptionButton(
                      option: widget.options[i],
                      index: i,
                      controller: _controller,
                      onChoose: widget.onChoose,
                    ),
                    const SizedBox(height: 12),
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
    required this.controller,
    required this.onChoose,
  });

  final ScriptOption option;
  final int index;
  final AnimationController controller;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final start = math.min(0.18 + index * 0.08, 0.6);
    final end = math.min(start + 0.5, 1.0);
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: M3Motion.emphasizedDecelerate),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.18),
          end: Offset.zero,
        ).animate(animation),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => onChoose(option.id),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFFF8F1),
              backgroundColor: const Color(0xAA20243A),
              side: const BorderSide(color: Color(0x99F1C2B3)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 19),
              shape: const RoundedRectangleBorder(),
              animationDuration: M3Motion.short,
            ),
            child: Text(
              option.text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, height: 1.45),
            ),
          ),
        ),
      ),
    );
  }
}

class _SceneHeader extends StatelessWidget {
  const _SceneHeader({required this.sceneId, required this.backgroundId});

  final String sceneId;
  final String backgroundId;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.rotate(
          angle: -0.035,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFFE8E0C0),
            child: AnimatedSwitcher(
              duration: M3Motion.medium,
              reverseDuration: M3Motion.short,
              transitionBuilder: (child, animation) => M3Motion.fadeSlideTransition(
                child,
                animation,
                beginOffset: const Offset(0, -0.18),
              ),
              child: Text(
                sceneId,
                key: ValueKey(sceneId),
                style: const TextStyle(color: Color(0xFF292721), fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF101319).withValues(alpha: 0.58),
            border: Border.all(color: Colors.white24),
          ),
          child: AnimatedSwitcher(
            duration: M3Motion.medium,
            reverseDuration: M3Motion.short,
            transitionBuilder: (child, animation) => M3Motion.fadeSlideTransition(
              child,
              animation,
              beginOffset: const Offset(0, -0.18),
            ),
            child: Text(
              backgroundId,
              key: ValueKey(backgroundId),
              style: const TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _DialoguePanel extends StatelessWidget {
  const _DialoguePanel({
    required this.state,
    required this.onNext,
    required this.onChoose,
    required this.paper,
    required this.ink,
    required this.signal,
  });

  final PlaybackState state;
  final VoidCallback onNext;
  final ValueChanged<String> onChoose;
  final Color paper;
  final Color ink;
  final Color signal;

  @override
  Widget build(BuildContext context) {
    final speaker = state.line.speakerId == 'narrator'
        ? '旁白'
        : state.line.speakerId == 'lin'
            ? '林'
            : '周';
    final lineKey = ValueKey('${state.sceneIndex}_${state.lineIndex}');

    return AnimatedSize(
      duration: M3Motion.medium,
      curve: M3Motion.emphasized,
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          color: paper,
          border: Border.all(color: ink, width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x774B2522), offset: Offset(7, 7))],
        ),
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: M3Motion.short,
                  curve: M3Motion.standard,
                  width: 9,
                  height: 9,
                  color: signal,
                ),
                const SizedBox(width: 9),
                AnimatedSwitcher(
                  duration: M3Motion.short,
                  layoutBuilder: M3Motion.leftAlignedLayoutBuilder,
                  transitionBuilder: (child, animation) => M3Motion.fadeSlideTransition(
                    child,
                    animation,
                    beginOffset: const Offset(0, 0.14),
                  ),
                  child: Text(
                    speaker,
                    key: ValueKey(speaker),
                    style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                  ),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: M3Motion.short,
                  child: Text(
                    state.line.id,
                    key: lineKey,
                    style: TextStyle(color: ink.withValues(alpha: 0.55), fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            AnimatedSwitcher(
              duration: M3Motion.medium,
              reverseDuration: M3Motion.short,
              layoutBuilder: M3Motion.leftAlignedLayoutBuilder,
              transitionBuilder: (child, animation) => M3Motion.fadeSlideTransition(
                child,
                animation,
                beginOffset: const Offset(0, 0.08),
              ),
              child: SizedBox(
                key: lineKey,
                width: double.infinity,
                child: Text(
                  state.line.text,
                  style: TextStyle(color: ink, fontSize: 21, height: 1.65),
                ),
              ),
            ),
            const SizedBox(height: 15),
            if (state.isWaitingForChoice)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: state.line.options
                    .map(
                      (option) => OutlinedButton(
                        onPressed: () => onChoose(option.id),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ink,
                          side: BorderSide(color: ink.withValues(alpha: 0.65)),
                          shape: const RoundedRectangleBorder(),
                          animationDuration: M3Motion.short,
                        ),
                        child: Text(option.text),
                      ),
                    )
                    .toList(),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: state.isEnded ? null : onNext,
                  icon: AnimatedSwitcher(
                    duration: M3Motion.short,
                    child: Icon(
                      state.isEnded ? Icons.done : Icons.arrow_forward,
                      key: ValueKey(state.isEnded),
                      size: 17,
                    ),
                  ),
                  label: AnimatedSwitcher(
                    duration: M3Motion.short,
                    child: Text(
                      state.isEnded ? '结束' : '继续',
                      key: ValueKey(state.isEnded),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: ink,
                    foregroundColor: paper,
                    shape: const RoundedRectangleBorder(),
                    animationDuration: M3Motion.short,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SceneBackdrop extends StatelessWidget {
  const _SceneBackdrop({required this.backgroundId});

  final String backgroundId;

  @override
  Widget build(BuildContext context) {
    final path = switch (backgroundId) {
      'classroom_dusk' => 'assets/backgrounds/classroom_dusk.svg',
      'rooftop_night' => 'assets/backgrounds/rooftop_night.svg',
      _ => null,
    };
    return AnimatedSwitcher(
      duration: M3Motion.long,
      switchInCurve: M3Motion.standard,
      switchOutCurve: M3Motion.standard,
      child: SizedBox.expand(
        key: ValueKey(backgroundId),
        child: path == null
            ? const ColoredBox(color: Color(0xFF22283A))
            : SvgPicture.asset(path, fit: BoxFit.cover),
      ),
    );
  }
}

String _spritePath(String characterId, String spriteId) => 'assets/characters/${characterId}_$spriteId.svg';
