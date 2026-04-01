import 'package:flutter/material.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  static const _panel = Color(0xFF0B1220);
  static const _border = Color(0xFF111827);
  static const _text = Color(0xFFE5E7EB);
  static const _sub = Color(0xFF9CA3AF);
  static const _accent = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        const Text(
          'Задачі',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _text,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Модуль задач готується до наступного етапу розвитку.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _sub,
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: _panel.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _accent.withValues(alpha: 0.24)),
                ),
                child: const Icon(
                  Icons.checklist_rounded,
                  size: 34,
                  color: _accent,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Скоро тут буде повноцінний екран задач',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Поручення, відповідальні, строки виконання та статуси.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _sub,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _border),
                ),
                child: const Text(
                  'MOVA Intelligence v1.2',
                  style: TextStyle(
                    color: _sub,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}