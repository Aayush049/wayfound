import 'package:flutter/material.dart';

/// A global wrapper that centers content and limits content width to [maxWidth]
/// (default 720 logical pixels) on wide displays.
///
/// On screens narrower than [maxWidth], content occupies the full available width.
class WebResponsiveWrapper extends StatelessWidget {
  const WebResponsiveWrapper({
    super.key = const Key('web_responsive_wrapper'),
    required this.child,
    this.maxWidth = 720.0,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
