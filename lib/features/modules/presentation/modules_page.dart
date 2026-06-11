import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../api/auth_provider.dart';

class ModulesPage extends StatelessWidget {
  const ModulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = cs.onSurface;
    final sub = theme.textTheme.bodyMedium?.color ??
        cs.onSurface.withValues(alpha: 0.7);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        Text(
          'Модулі',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Функціональні розділи платформи MOVA Intelligence.',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: sub,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Основні модулі',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        _ModuleCard(
          title: 'Профіль',
          subtitle: 'Аватар, відділ, керівник та тема оформлення',
          icon: Icons.account_circle_outlined,
          accent: const Color(0xFF0EA5E9),
          onTap: () => context.push('/modules/profile'),
        ),
        const SizedBox(height: 12),
        _ModuleCard(
          title: 'Погодження',
          subtitle: 'Заявки на оплату та інші погодження',
          icon: Icons.verified_outlined,
          accent: const Color(0xFF2F80ED),
          onTap: () => context.go('/work'),
        ),
        const SizedBox(height: 12),
        _ModuleCard(
          title: 'Задачі',
          subtitle: 'Постановка, контроль та виконання задач',
          icon: Icons.checklist_rounded,
          accent: const Color(0xFF22C55E),
          onTap: () => context.push('/tasks'),
        ),
        const SizedBox(height: 12),
        _ModuleCard(
          title: 'Події',
          subtitle: 'Стрічка подій, сповіщення та історія змін',
          icon: Icons.notifications_none_rounded,
          accent: const Color(0xFFF59E0B),
          onTap: () => context.push('/events'),
        ),
        const SizedBox(height: 12),
        _ModuleCard(
          title: 'Комунікації',
          subtitle: auth.canAccessNotifications
              ? 'Діалоги, повідомлення та створення нових тем'
              : 'Діалоги та вхідні повідомлення команди',
          icon: Icons.forum_outlined,
          accent: const Color(0xFF14B8A6),
          onTap: () => context.push('/modules/communications'),
        ),
        const SizedBox(height: 12),
        _ModuleCard(
          title: 'Документи / OCR',
          subtitle: 'Розпізнавання документів та створення заявки',
          icon: Icons.document_scanner_outlined,
          accent: const Color(0xFF3AAFA9),
          onTap: () => context.push('/invoices/recognize'),
        ),
        const SizedBox(height: 12),
        if (auth.canAccessProduction) ...[
          _ModuleCard(
            title: 'Виробництво',
            subtitle: 'Сировина, розлив, повернення та готова продукція',
            icon: Icons.factory_outlined,
            accent: const Color(0xFF0F766E),
            onTap: () => context.push('/production'),
          ),
          const SizedBox(height: 12),
        ],
        _ModuleCard(
          title: 'Звіти',
          subtitle: 'Аналітика, показники та огляд для керівника',
          icon: Icons.bar_chart_rounded,
          accent: const Color(0xFF8B5CF6),
          onTap: () => context.push('/reports'),
        ),
        const SizedBox(height: 18),
        Text(
          'Додатково',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        const _ModuleCard(
          title: 'Склад',
          subtitle: 'Залишки, рухи та контроль товарів',
          icon: Icons.warehouse_outlined,
          accent: Color(0xFF64748B),
          isComingSoon: true,
        ),
        const SizedBox(height: 12),
        const _ModuleCard(
          title: 'Закупівлі',
          subtitle: 'Постачальники, замовлення та погодження',
          icon: Icons.shopping_cart_outlined,
          accent: Color(0xFF64748B),
          isComingSoon: true,
        ),
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = cs.onSurface;
    final sub = theme.textTheme.bodyMedium?.color ??
        cs.onSurface.withValues(alpha: 0.7);
    final border = theme.dividerTheme.color ?? cs.outlineVariant;
    final panel = cs.surface;

    final disabled = theme.brightness == Brightness.dark
        ? const Color(0xFF72839A)
        : const Color(0xFF94A3B8);

    final enabled = !isComingSoon && onTap != null;
    final iconColor = enabled ? accent : disabled;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: enabled ? onTap : null,
      child: Ink(
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.16 : 0.06,
              ),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.20),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: iconColor,
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
                              color: enabled ? text : sub,
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
                        color: enabled ? sub : disabled,
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
                enabled
                    ? Icons.chevron_right_rounded
                    : Icons.lock_outline_rounded,
                color: enabled ? sub : disabled,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.dividerTheme.color ?? theme.colorScheme.outlineVariant;
    final panel = theme.colorScheme.surface;
    final sub = theme.textTheme.bodyMedium?.color ??
        theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        'Скоро',
        style: TextStyle(
          color: sub,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
