import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../api/auth_provider.dart';
import '../production_service.dart';

class ProductionPage extends StatefulWidget {
  const ProductionPage({super.key});

  @override
  State<ProductionPage> createState() => _ProductionPageState();
}

class _ProductionPageState extends State<ProductionPage> {
  late Future<List<ProductionRequest>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ProductionService>().getRequests();
  }

  Future<void> _refresh() async {
    final future = context.read<ProductionService>().getRequests();
    setState(() => _future = future);
    await future;
  }

  Future<void> _createRequest([ProductionRequestType? type]) async {
    final suffix = type == null ? '' : '?type=${type.code}';
    await context.push('/production/new$suffix');
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthProvider>().canAccessProduction) {
      return const Center(child: Text('Немає доступу'));
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final desktop = MediaQuery.sizeOf(context).width >= 1000;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          desktop ? 28 : 16,
          desktop ? 18 : 12,
          desktop ? 28 : 16,
          28,
        ),
        children: [
          _ProductionHeader(
            desktop: desktop,
            onCreate: () => _createRequest(),
            onTemplates: () => context.push('/production/templates'),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Text(
                'Оберіть операцію',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Divider(color: cs.outlineVariant.withValues(alpha: .7)),
              ),
              const SizedBox(width: 10),
              Text(
                '4 напрямки',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: .52),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: desktop ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: desktop ? 2.05 : 1.05,
            children: [
              _ProcessCard(
                step: '01',
                type: ProductionRequestType.rawMaterial,
                icon: Icons.grain_rounded,
                color: const Color(0xFF18A999),
                subtitle: 'Пиво, лимонад, шаблони',
                onTap: () => _createRequest(ProductionRequestType.rawMaterial),
              ),
              _ProcessCard(
                step: '02',
                type: ProductionRequestType.bottling,
                icon: Icons.local_drink_outlined,
                color: const Color(0xFF3B82F6),
                subtitle: 'Тара, партії та розлив',
                onTap: () => _createRequest(ProductionRequestType.bottling),
              ),
              _ProcessCard(
                step: '03',
                type: ProductionRequestType.finishedGoods,
                icon: Icons.inventory_2_outlined,
                color: const Color(0xFF9B6DFF),
                subtitle: 'Етикетка та передатування',
                onTap: () =>
                    _createRequest(ProductionRequestType.finishedGoods),
              ),
              _ProcessCard(
                step: '04',
                type: ProductionRequestType.returnToStock,
                icon: Icons.assignment_return_outlined,
                color: const Color(0xFFFF9F43),
                subtitle: 'Повернення на склад',
                onTap: () =>
                    _createRequest(ProductionRequestType.returnToStock),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _RequestsSection(
            future: _future,
            onCreate: () => _createRequest(),
            onRetry: _refresh,
          ),
        ],
      ),
    );
  }
}

class _ProductionHeader extends StatelessWidget {
  const _ProductionHeader({
    required this.desktop,
    required this.onCreate,
    required this.onTemplates,
  });

  final bool desktop;
  final VoidCallback onCreate;
  final VoidCallback onTemplates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.primary.withValues(alpha: .32)),
              ),
              child: Icon(Icons.factory_outlined, color: cs.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Виробництво',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          'Створення та контроль переміщень між виробництвом і складом',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: .64),
          ),
        ),
      ],
    );

    final button = FilledButton.icon(
      onPressed: onCreate,
      style: FilledButton.styleFrom(
        minimumSize: Size(desktop ? 190 : double.infinity, 46),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: const Icon(Icons.add_rounded),
      label: const Text(
        'Нова заявка',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );
    final templatesButton = OutlinedButton.icon(
      onPressed: onTemplates,
      icon: const Icon(Icons.receipt_long_outlined),
      label: const Text(
        'Шаблони',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );

    if (!desktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          content,
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: templatesButton),
              const SizedBox(width: 8),
              Expanded(child: button),
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: content),
        const SizedBox(width: 20),
        templatesButton,
        const SizedBox(width: 8),
        button,
      ],
    );
  }
}

class _ProcessCard extends StatefulWidget {
  const _ProcessCard({
    required this.step,
    required this.type,
    required this.icon,
    required this.color,
    required this.subtitle,
    required this.onTap,
  });

  final String step;
  final ProductionRequestType type;
  final IconData icon;
  final Color color;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_ProcessCard> createState() => _ProcessCardState();
}

class _ProcessCardState extends State<_ProcessCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _hovered ? widget.color : border,
            width: _hovered ? 1.5 : 1,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: widget.color.withValues(alpha: .14),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.color.withValues(alpha: .35),
                          ),
                        ),
                        child: Icon(widget.icon, color: widget.color, size: 24),
                      ),
                      const Spacer(),
                      Text(
                        widget.step,
                        style: TextStyle(
                          color: widget.color.withValues(alpha: .62),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    widget.type.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: .58),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Створити',
                        style: TextStyle(
                          color: widget.color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 17,
                        color: widget.color,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestsSection extends StatelessWidget {
  const _RequestsSection({
    required this.future,
    required this.onCreate,
    required this.onRetry,
  });

  final Future<List<ProductionRequest>> future;
  final VoidCallback onCreate;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: FutureBuilder<List<ProductionRequest>>(
        future: future,
        builder: (context, snapshot) {
          final requests = snapshot.data ?? const <ProductionRequest>[];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: .11),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.assignment_outlined,
                        size: 20,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Активні заявки',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: .11),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${requests.length}',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: border),
              if (snapshot.connectionState != ConnectionState.done)
                const SizedBox(
                  height: 190,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                _ProductionEmpty(
                  icon: Icons.cloud_off_outlined,
                  title: 'Не вдалося завантажити заявки',
                  subtitle: '${snapshot.error}',
                  actionLabel: 'Спробувати ще раз',
                  onAction: onRetry,
                )
              else if (requests.isEmpty)
                _ProductionEmpty(
                  icon: Icons.add_task_rounded,
                  title: 'Черга готова до роботи',
                  subtitle:
                      'Створіть перше переміщення — воно одразу з’явиться тут.',
                  actionLabel: 'Створити першу заявку',
                  onAction: onCreate,
                )
              else
                for (final request in requests)
                  ListTile(
                    leading: const Icon(Icons.factory_outlined),
                    title: Text(request.title),
                    subtitle: Text(request.subtitle),
                    trailing: Text(request.status),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _ProductionEmpty extends StatelessWidget {
  const _ProductionEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SizedBox(
      height: 210,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.primary.withValues(alpha: .3)),
              ),
              child: Icon(icon, size: 27, color: cs.primary),
            ),
            const SizedBox(height: 13),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: .58),
                ),
              ),
            ),
            const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
