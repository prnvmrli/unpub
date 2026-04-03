import 'package:flutter/material.dart';

class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    required this.child,
    this.offsetY = 20,
    this.duration = const Duration(milliseconds: 350),
    super.key,
  });

  final Widget child;
  final double offsetY;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: 1 - value,
          child: Transform.translate(
            offset: Offset(0, value * offsetY),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }
}

