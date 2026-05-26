import 'package:flutter/material.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  static const _accent = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final panel = cs.surface;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;
    final text = cs.onSurface;
    final sub = theme.textTheme.bodyMedium?.color ??
        cs.onSurface.withValues(alpha: 0.72);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        Text(
          'Задачі',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Модуль задач готується до наступного етапу розвитку.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: sub,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
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
              Text(
                'Скоро тут буде повноцінний екран задач',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Поручення, відповідальні, строки виконання та статуси.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: sub,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: border),
                ),
                child: Text(
                  'MOVA Intelligence v1.3.0',
                  style: TextStyle(
                    color: sub,
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
