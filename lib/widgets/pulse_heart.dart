import 'package:flutter/material.dart';

/// Animated pulsing heart icon that beats in sync with the heart rate.
class PulseHeart extends StatefulWidget {
  final int bpm;
  final double size;
  final Color color;

  const PulseHeart({
    super.key,
    required this.bpm,
    this.size = 80,
    this.color = const Color(0xFFE53935),
  });

  @override
  State<PulseHeart> createState() => _PulseHeartState();
}

class _PulseHeartState extends State<PulseHeart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _startAnimation();
  }

  void _startAnimation() {
    if (widget.bpm > 0) {
      final beatDuration = (60000 / widget.bpm).round();
      _controller.duration = Duration(milliseconds: beatDuration);
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void didUpdateWidget(PulseHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bpm != widget.bpm) {
      _startAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Gentle heartbeat pulse, resting at zero when disconnected
        final t = _controller.value;
        final scale = widget.bpm > 0 ? 1.0 + 0.12 * _beatCurve(t) : 1.0;
        return Transform.scale(
          scale: scale,
          child: Icon(
            Icons.favorite,
            size: widget.size,
            color: widget.bpm > 0 ? widget.color : widget.color.withOpacity(0.4),
            shadows: widget.bpm > 0
                ? [
                    Shadow(
                      color: widget.color.withOpacity(0.45),
                      blurRadius: widget.size * 0.3,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }

  /// Lub-dub double-pulse curve: sharp rise, dip, second rise, rest.
  double _beatCurve(double t) {
    if (t < 0.15) return Curves.easeOut.transform(t / 0.15);
    if (t < 0.3) {
      return 1.0 - Curves.easeIn.transform((t - 0.15) / 0.15) * 0.25;
    }
    if (t < 0.45) return 0.75 + Curves.easeOut.transform((t - 0.3) / 0.15) * 0.25;
    return 1.0 - Curves.easeIn.transform((t - 0.45) / 0.55);
  }
}
