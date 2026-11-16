import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../script/script_models.dart';
import '../motion.dart';

class ChoiceOverlay extends StatefulWidget {
  const ChoiceOverlay({
    super.key,
    required this.options,
    required this.debugMode,
    required this.onChoose,
  });

  final List<ScriptOption> options;
  final bool debugMode;
  final ValueChanged<String> onChoose;

  @override
  State<ChoiceOverlay> createState() => _ChoiceOverlayState();
}

class _ChoiceOverlayState extends State<ChoiceOverlay>
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
                    StaggeredOptionButton(
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

class StaggeredOptionButton extends StatelessWidget {
  const StaggeredOptionButton({
    super.key,
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
