import 'package:flutter/material.dart';

class BouncingDot extends StatefulWidget {
  final Color color;
  final Duration delay;

  const BouncingDot({super.key, required this.color, required this.delay});

  @override
  State<BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<BouncingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _animation = Tween<double>(begin: 0, end: -8).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    Future.delayed(widget.delay, () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _animation.value),
        child: Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: widget.color),
        ),
      ),
    );
  }
}
