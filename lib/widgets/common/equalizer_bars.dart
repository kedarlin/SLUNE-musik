import 'package:flutter/material.dart';

class EqualizerBars extends StatefulWidget {
  const EqualizerBars({
    required this.isPlaying,
    this.color = Colors.white,
    this.barWidth = 3,
    this.height = 16,
    super.key,
  });

  final bool isPlaying;
  final Color color;
  final double barWidth;
  final double height;

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  static const List<double> _phaseOffsets = <double>[0.0, 0.15, 0.3];

  @override
  void initState() {
    super.initState();
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(EqualizerBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List<Widget>.generate(_phaseOffsets.length, (int i) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.barWidth / 2),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget? child) {
                final double phase =
                    (_controller.value + _phaseOffsets[i]) % 1.0;
                // Triangle wave (0 -> 1 -> 0) from the sawtooth `phase`, eased.
                final double triangle = 1 - (2 * phase - 1).abs();
                final double t = Curves.easeInOut.transform(triangle);
                final double factor = 0.25 + 0.75 * t;
                return Container(
                  width: widget.barWidth,
                  height: widget.height * factor,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(widget.barWidth / 2),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}
