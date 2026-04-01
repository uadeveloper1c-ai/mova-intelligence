import 'dart:ui';
import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  static const _base = Color(0xFF122033);
  static const _baseDeep = Color(0xFF0C1727);
  static const _soft = Color(0xFF1B2C43);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: _baseDeep),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _base,
                _baseDeep,
              ],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.85, -0.95),
              radius: 1.3,
              colors: [
                _soft,
                Color(0x00000000),
              ],
              stops: [0.0, 1.0],
            ),
          ),
        ),
        const Positioned(
          top: -140,
          left: -160,
          child: _GlowBlob(
            color: Color(0x3822D3EE),
            size: 390,
          ),
        ),
        const Positioned(
          bottom: -170,
          right: -150,
          child: _GlowBlob(
            color: Color(0x2A38BDF8),
            size: 410,
          ),
        ),
        const Positioned(
          top: 110,
          right: -160,
          child: _GlowBlob(
            color: Color(0x1D10B981),
            size: 340,
          ),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(color: Colors.transparent),
        ),
        child,
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowBlob({
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}