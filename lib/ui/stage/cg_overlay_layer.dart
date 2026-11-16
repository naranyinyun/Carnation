import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../assets/asset_models.dart';
import '../motion.dart';

class CgOverlayLayer extends StatelessWidget {
  const CgOverlayLayer({
    super.key,
    required this.cgId,
    required this.debugMode,
    required this.assets,
  });

  final String? cgId;
  final bool debugMode;
  final AssetCatalog assets;

  @override
  Widget build(BuildContext context) {
    final path = cgId == null ? null : assets.cgPath(cgId!);

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
