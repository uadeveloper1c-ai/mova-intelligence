import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  static const _panel = Color(0xFF0B1220);
  static const _border = Color(0xFF111827);
  static const _text = Color(0xFFE5E7EB);
  static const _sub = Color(0xFF9CA3AF);
  static const _accent = Color(0xFF22D3EE);
  static const _disabled = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      children: [
        const Text(
          'Розділи MOVA Intelligence',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _text,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Швидкий доступ до основних модулів системи.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _sub,
          ),
        ),
        const SizedBox(height: 16),

        _MenuCard(
          title: 'Події / Повідомлення',
          subtitle: 'Історія дій, пуші, статуси, замовлення з Telegram',
          icon: Icons.notifications_none_rounded,
          accent: const Color(0xFF38BDF8),
          onTap: () => context.push('/events'),
        ),
        const SizedBox(height: 12),

        const _MenuCard(
          title: 'План робіт на сьогодні',
          subtitle: 'По відділах, виробництво, склад, логістика',
          icon: Icons.factory_outlined,
          accent: Color(0xFFF59E0B),
          isComingSoon: true,
        ),
        const SizedBox(height: 12),

        const _MenuCard(
          title: 'Старший зміни',
          subtitle: 'Хто відповідальний сьогодні по відділу',
          icon: Icons.badge_outlined,
          accent: Color(0xFFA78BFA),
          isComingSoon: true,
        ),
        const SizedBox(height: 12),

        _MenuCard(
          title: 'Задачі',
          subtitle: 'Список задач та статуси виконання',
          icon: Icons.checklist_rounded,
          accent: const Color(0xFF22C55E),
          onTap: () => context.push('/tasks'),
        ),
        const SizedBox(height: 12),

        _MenuCard(
          title: 'Звіти',
          subtitle: 'Аналітика, показники та огляд для керівника',
          icon: Icons.bar_chart_rounded,
          accent: const Color(0xFF10B981),
          onTap: () => context.push('/reports'),
        ),
        const SizedBox(height: 12),

        _MenuCard(
          title: 'Розпізнати документ (OCR)',
          subtitle: 'Фото або галерея → створити заявку',
          icon: Icons.document_scanner_outlined,
          accent: const Color(0xFF22D3EE),
          onTap: () => context.push('/invoices/recognize'),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.onTap,
    this.isComingSoon = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final bool isComingSoon;

  static const _panel = Color(0xFF0B1220);
  static const _border = Color(0xFF111827);
  static const _text = Color(0xFFE5E7EB);
  static const _sub = Color(0xFF9CA3AF);
  static const _disabled = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final enabled = !isComingSoon && onTap != null;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: enabled ? onTap : null,
      child: Ink(
        decoration: BoxDecoration(
          color: _panel.withValues(alpha: enabled ? 0.94 : 0.82),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: (enabled ? accent : _disabled).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (enabled ? accent : _disabled).withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: enabled ? accent : _disabled,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: enabled ? _text : _sub,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (isComingSoon) const _SoonBadge(),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: enabled ? _sub : _disabled,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                enabled ? Icons.chevron_right_rounded : Icons.lock_outline_rounded,
                color: enabled ? _sub : _disabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoonBadge extends StatelessWidget {
  const _SoonBadge();

  static const _panel = Color(0xFF0B1220);
  static const _border = Color(0xFF111827);
  static const _sub = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _panel.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
      ),
      child: const Text(
        'Скоро',
        style: TextStyle(
          color: _sub,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}