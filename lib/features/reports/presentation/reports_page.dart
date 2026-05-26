import 'package:flutter/material.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

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
          'Звіти та аналітика',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Підготовка екрану для керівника. У версії 1.3.0 тут буде короткий бізнес-огляд.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: sub,
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
          title: 'Що з’явиться у v1.3.0',
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
            color: panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Icon(Icons.rocket_launch_outlined, color: sub),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'MOVA Intelligence v1.3.0 preview',
                  style: TextStyle(
                    color: text,
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

  static const _accent = Color(0xFF22D3EE);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final panel = cs.surface;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;
    final text = cs.onSurface;
    final sub = theme.textTheme.bodyMedium?.color ??
        cs.onSurface.withValues(alpha: 0.72);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
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
            style: TextStyle(
              color: sub,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: text,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: sub,
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

  static const _accent = Color(0xFF22D3EE);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final panel = cs.surface;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;
    final text = cs.onSurface;
    final sub = theme.textTheme.bodyMedium?.color ??
        cs.onSurface.withValues(alpha: 0.72);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
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
                  style: TextStyle(
                    color: text,
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
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: sub,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: sub,
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
