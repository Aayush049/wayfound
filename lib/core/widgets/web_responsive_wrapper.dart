import 'package:flutter/material.dart';

/// Web application root shell that provides the full window background using
/// the theme's scaffold background color.
class WebResponsiveWrapper extends StatelessWidget {
  const WebResponsiveWrapper({
    super.key = const Key('web_responsive_wrapper'),
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }
}
