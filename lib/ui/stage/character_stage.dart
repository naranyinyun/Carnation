import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../assets/asset_models.dart';
import '../../player/playback_models.dart';
import '../../script/script_models.dart';
import '../motion.dart';

class CharacterStage extends StatelessWidget {
  const CharacterStage({
    super.key,
    required this.characters,
    required this.viewportSize,
    required this.sceneId,
    required this.lineId,
    required this.assets,
  });

  final List<StageCharacter> characters;
  final Size viewportSize;
  final String sceneId;
  final String lineId;
  final AssetCatalog assets;

  @override
  Widget build(BuildContext context) {
    final sorted = [...characters]..sort((a, b) {
        if (a.isSpeaking == b.isSpeaking) {
          return a.characterId.compareTo(b.characterId);
        }
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
            child: AnimatedCharacterActor(
              character: character,
              lineId: lineId,
              assets: assets,
            ),
          ),
      ],
    );
  }
}

class AnimatedCharacterActor extends StatefulWidget {
  const AnimatedCharacterActor({
    super.key,
    required this.character,
    required this.lineId,
    required this.assets,
  });

  final StageCharacter character;
  final String lineId;
  final AssetCatalog assets;

  @override
  State<AnimatedCharacterActor> createState() => _AnimatedCharacterActorState();
}

class _AnimatedCharacterActorState extends State<AnimatedCharacterActor>
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
  void didUpdateWidget(covariant AnimatedCharacterActor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _triggerAnimations();
  }

  void _triggerAnimations() {
    final key =
        '${widget.lineId}_${widget.character.animations.length}_${widget.character.isExiting}';
    if (key == _lastTriggerKey) return;
    _lastTriggerKey = key;

    if (widget.character.animations.isNotEmpty) {
      final hasSlow = widget.character.animations
          .any((a) => a.style == ScriptAnimationStyle.slow);
      final hasFast = widget.character.animations
          .any((a) => a.style == ScriptAnimationStyle.fast);
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
    final spritePath = widget.assets.spritePath(char.characterId, char.spriteId);
    final enterAnim = char.animations
        .where((a) => a.verb == AnimationVerb.enter)
        .firstOrNull;
    final exitAnim = char.animations
        .where((a) => a.verb == AnimationVerb.exit)
        .firstOrNull;
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
                spritePath,
                key: ValueKey('${char.characterId}_${char.spriteId}'),
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
