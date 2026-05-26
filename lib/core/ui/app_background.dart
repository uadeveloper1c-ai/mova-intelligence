import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [
                  Color(0xFF111C27),
                  Color(0xFF172536),
                  Color(0xFF203247),
                ]
              : const [
                  Color(0xFFF0F4F7),
                  Color(0xFFEAF2F5),
                  Color(0xFFE4EEF3),
                ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -20,
            child: _BlurOrb(
              size: 170,
              color: isDark
                  ? const Color(0xFF3AAFA9).withValues(alpha: 0.16)
                  : const Color(0xFF63D1C8).withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            top: 120,
            left: -30,
            child: _BlurOrb(
              size: 140,
              color: isDark
                  ? const Color(0xFF58A6FF).withValues(alpha: 0.12)
                  : const Color(0xFF7FB6FF).withValues(alpha: 0.11),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _BlurOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _BlurOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: size * 0.65,
              spreadRadius: size * 0.15,
            ),
          ],
        ),
      ),
    );
  }
}
