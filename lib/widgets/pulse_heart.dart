import 'package:flutter/material.dart';

/// Animated pulsing heart icon that beats in sync with heart rate.
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
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _startAnimation();
  }

  void _startAnimation() {
    if (widget.bpm > 0) {
      final beatDuration = (60000 / widget.bpm).round();
      _controller.duration = Duration(milliseconds: beatDuration);
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
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
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: Icon(
        Icons.favorite,
        size: widget.size,
        color: widget.color,
      ),
    );
  }
}
