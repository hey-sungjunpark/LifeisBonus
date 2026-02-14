import 'package:flutter/material.dart';

class ResponsiveFrame extends StatelessWidget {
  const ResponsiveFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth < 480) {
          return child;
        }
        double contentWidth;
        if (maxWidth >= 1200) {
          contentWidth = 720;
        } else if (maxWidth >= 900) {
          contentWidth = 600;
        } else if (maxWidth >= 720) {
          contentWidth = 520;
        } else {
          contentWidth = 480;
        }
        final media = MediaQuery.of(context);
        final clampedWidth = contentWidth.clamp(320.0, maxWidth);
        final adjusted = media.copyWith(
          size: Size(clampedWidth, media.size.height),
        );
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: clampedWidth),
              child: MediaQuery(
                data: adjusted,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
