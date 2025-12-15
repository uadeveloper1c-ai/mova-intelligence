import 'dart:ui';
import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // многослойный градієнт
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF8EC5FC), // світлий голубий
                Color(0xFF6A85F1), // насиченіший
                Color(0xFFE0C3FC), // ніжно фіолетовий
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),

        // м'яке розмиття
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
          child: Container(color: Colors.transparent),
        ),

        child,
      ],
    );
  }
}
