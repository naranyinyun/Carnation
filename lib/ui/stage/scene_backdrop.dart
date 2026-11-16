import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../assets/asset_models.dart';
import '../../script/script_models.dart';
import '../motion.dart';

class SceneBackdrop extends StatelessWidget {
  const SceneBackdrop({
    super.key,
    required this.backgroundId,
    required this.transition,
    required this.assets,
  });

  final String backgroundId;
  final TransitionKind transition;
  final AssetCatalog assets;

  @override
  Widget build(BuildContext context) {
    final path = assets.backgroundPath(backgroundId);

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
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.25, 1.0),
            ),
            child: child,
          );
        }
        return FadeTransition(opacity: animation, child: child);
      },
      child: SizedBox.expand(
        key: ValueKey(backgroundId),
        child: SvgPicture.asset(path, fit: BoxFit.cover),
      ),
    );
  }
}
