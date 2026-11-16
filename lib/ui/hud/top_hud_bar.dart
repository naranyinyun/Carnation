import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../player/playback_models.dart';
import '../motion.dart';
import '../scene_metadata.dart';

class GalgameTopHud extends StatelessWidget {
  const GalgameTopHud({
    super.key,
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
    final sceneTitle = sceneDisplayTitle(state.scene.id);
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
          GlassPillButton(
            icon: Icons.account_tree_outlined,
            label: '流程图',
            accent: const Color(0xFFF0C66B),
            onTap: onOpenFlowchart,
          ),
          const SizedBox(width: 8),
        ],

        // Mode Switcher Pill (玩家 / 调试)
        GlassPillButton(
          icon: debugMode ? Icons.bug_report_outlined : Icons.person_outline_rounded,
          label: debugMode ? '调试' : '玩家',
          accent: debugMode ? const Color(0xFFE55B45) : Colors.white70,
          onTap: onToggleDebug,
        ),
      ],
    );
  }
}

class GlassPillButton extends StatelessWidget {
  const GlassPillButton({
    super.key,
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
