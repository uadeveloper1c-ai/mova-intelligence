import 'package:flutter/material.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  static const _panel = Color(0xFF0B1220);
  static const _border = Color(0xFF111827);
  static const _text = Color(0xFFE5E7EB);
  static const _sub = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        const Text(
          'Звіти та аналітика',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _text,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Підготовка екрану для керівника. У версії 1.2 тут буде короткий бізнес-огляд.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _sub,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),

        const Row(
          children: [
            Expanded(
              child: _KpiCard(
                title: 'Заявки',
                value: '—',
                subtitle: 'За обраний період',
                icon: Icons.receipt_long_rounded,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                title: 'Погоджено',
                value: '—',
                subtitle: 'Підтверджені заявки',
                icon: Icons.verified_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        const Row(
          children: [
            Expanded(
              child: _KpiCard(
                title: 'До оплати',
                value: '—',
                subtitle: 'Очікують оплати',
                icon: Icons.payments_outlined,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                title: 'Сума',
                value: '—',
                subtitle: 'Загальний обсяг',
                icon: Icons.bar_chart_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        const _PreviewCard(
          title: 'Що з’явиться у v1.2',
          items: [
            'Кількість заявок за період',
            'Статуси: на погодженні / до оплати / оплачено',
            'Суми по статусах',
            'Динаміка по днях',
            'Топ контрагентів або статей витрат',
          ],
          icon: Icons.auto_graph_rounded,
        ),
        const SizedBox(height: 12),

        const _PreviewCard(
          title: 'Статус екрану',
          items: [
            'UI-заготовка вже готова',
            'Наступний крок — підключення реальних даних',
            'Екран буде використаний для демонстрації шефу',
          ],
          icon: Icons.flag_outlined,
        ),
        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _panel.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: const Row(
            children: [
              Icon(Icons.rocket_launch_outlined, color: _sub),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'MOVA Intelligence v1.2 preview',
                  style: TextStyle(
                    color: _text,
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

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  static const _panel = Color(0xFF0B1220);
  static const _border = Color(0xFF111827);
  static const _text = Color(0xFFE5E7EB);
  static const _sub = Color(0xFF9CA3AF);
  static const _accent = Color(0xFF22D3EE);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accent.withValues(alpha: 0.24)),
            ),
            child: Icon(icon, color: _accent),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: _sub,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: _text,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: _sub,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.title,
    required this.items,
    required this.icon,
  });

  final String title;
  final List<String> items;
  final IconData icon;

  static const _panel = Color(0xFF0B1220);
  static const _border = Color(0xFF111827);
  static const _text = Color(0xFFE5E7EB);
  static const _sub = Color(0xFF9CA3AF);
  static const _accent = Color(0xFF22D3EE);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _accent.withValues(alpha: 0.24)),
                ),
                child: Icon(icon, color: _accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: _sub,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: _sub,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}