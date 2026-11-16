import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../assets/asset_models.dart';
import '../../player/playback_models.dart';
import '../motion.dart';
import '../scene_metadata.dart';

class GalgameDialogueBox extends StatelessWidget {
  const GalgameDialogueBox({
    super.key,
    required this.state,
    required this.characters,
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
  final CharacterCatalog characters;
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
    final profile = characters.profileFor(state.line.speakerId);
    final speakerColor = parseHexColor(profile.colorHex);
    final isNarrator = profile.isNarrator;

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
                          color: speakerColor.withValues(alpha: 0.72),
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
                              color: speakerColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: speakerColor.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            profile.name,
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
                      : speakerColor.withValues(alpha: 0.48),
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
                                  child: BlinkingCursor(color: speakerColor),
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
                            QuickMenuButton(
                              icon: Icons.undo_rounded,
                              label: '回退',
                              onTap: onStepBack,
                            ),
                            QuickMenuButton(
                              icon: Icons.subject_rounded,
                              label: '记录',
                              onTap: onOpenLog,
                            ),
                            QuickMenuButton(
                              icon: Icons.play_arrow_rounded,
                              label: '自动',
                              isActive: autoPlay,
                              onTap: onToggleAuto,
                            ),
                            QuickMenuButton(
                              icon: Icons.fast_forward_rounded,
                              label: '快进',
                              isActive: skipMode,
                              onTap: state.isWaitingForChoice || state.isEnded ? null : onToggleSkip,
                            ),
                            QuickMenuButton(
                              icon: Icons.bookmark_border_rounded,
                              label: '存取',
                              onTap: onOpenSaveLoad,
                            ),
                            if (debugMode)
                              QuickMenuButton(
                                icon: Icons.account_tree_outlined,
                                label: '流程',
                                onTap: onOpenFlowchart,
                              ),
                            QuickMenuButton(
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

class QuickMenuButton extends StatelessWidget {
  const QuickMenuButton({
    super.key,
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

class BlinkingCursor extends StatefulWidget {
  const BlinkingCursor({super.key, required this.color});

  final Color color;

  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor>
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
