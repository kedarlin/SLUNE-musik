import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

class ScrollingTitle extends StatelessWidget {
  const ScrollingTitle({
    required this.text,
    required this.style,
    required this.height,
    this.startPadding = 0,
    this.alignment = Alignment.center,
    super.key,
  });

  final String text;
  final TextStyle style;
  final double height;
  final double startPadding;
  final Alignment alignment;

  static String _clean(String raw) =>
      raw.replaceAll(RegExp(r'\s+'), ' ').trim();

  @override
  Widget build(BuildContext context) {
    final String display = _clean(text);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final TextPainter painter = TextPainter(
            text: TextSpan(text: display, style: style),
            maxLines: 1,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();

          if (painter.width <= constraints.maxWidth) {
            return Align(
              alignment: alignment,
              child: Text(display, style: style, maxLines: 1),
            );
          }

          return Marquee(
            text: display,
            style: style,
            velocity: 40.0,
            startAfter: const Duration(seconds: 2),
            startPadding: startPadding,
            pauseAfterRound: const Duration(seconds: 1),
            fadingEdgeStartFraction: 0.12,
            fadingEdgeEndFraction: 0.12,
          );
        },
      ),
    );
  }
}
