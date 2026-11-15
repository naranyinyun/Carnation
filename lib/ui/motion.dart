import 'package:flutter/material.dart';

/// Material Design 3 motion tokens and transition builders.
abstract final class M3Motion {
  // M3 Easing curves
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve standardDecelerate = Cubic(0.0, 0.0, 0.0, 1.0);
  static const Curve standardAccelerate = Cubic(0.3, 0.0, 1.0, 1.0);

  // M3 Durations
  static const Duration short = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration mediumLong = Duration(milliseconds: 420);
  static const Duration long = Duration(milliseconds: 520);

  /// Material 3 Fade Through / Shared-Axis-Y inspired transition for content swaps.
  static Widget fadeSlideTransition(
    Widget child,
    Animation<double> animation, {
    Offset beginOffset = const Offset(0, 0.06),
  }) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: emphasizedDecelerate,
      reverseCurve: emphasizedAccelerate,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }

  /// Left-aligned layout builder for [AnimatedSwitcher] to prevent horizontal
  /// centering jumps when text width changes.
  static Widget leftAlignedLayoutBuilder(
    Widget? currentChild,
    List<Widget> previousChildren,
  ) {
    return Stack(
      alignment: Alignment.centerLeft,
      children: <Widget>[
        ...previousChildren,
        if (currentChild != null) currentChild,
      ],
    );
  }

  /// Material 3 Emphasized entrance with subtle scale + fade (for cards, overlays, sprites).
  static Widget emphasizedScaleFade(
    Widget child,
    Animation<double> animation, {
    double beginScale = 0.95,
    Offset beginOffset = const Offset(0, 0.03),
  }) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: emphasizedDecelerate,
      reverseCurve: emphasizedAccelerate,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: beginScale, end: 1.0).animate(curved),
          child: child,
        ),
      ),
    );
  }
}
