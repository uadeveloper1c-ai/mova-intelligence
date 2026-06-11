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

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthProvider>().canAccessProduction) {
      return const Center(child: Text('Немає доступу'));
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;
    final desktop = MediaQuery.sizeOf(context).width >= 1000;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding:
            EdgeInsets.fromLTRB(desktop ? 24 : 16, 12, desktop ? 24 : 16, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Виробництво',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Сировина, розлив, повернення та рух готової продукції',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.66),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () async {
                  await context.push('/production/new');
                  if (mounted) await _refresh();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Створити заявку'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: desktop ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: desktop ? 1.65 : 1.25,
            children: const [
              _ProcessCard(
                type: ProductionRequestType.rawMaterial,
                icon: Icons.grain_rounded,
                color: Color(0xFF0F766E),
                subtitle: 'Пиво, лимонад, шаблони',
              ),
              _ProcessCard(
                type: ProductionRequestType.bottling,
                icon: Icons.local_drink_outlined,
                color: Color(0xFF2563EB),
                subtitle: 'Тара, партії та розлив',
              ),
              _ProcessCard(
                type: ProductionRequestType.finishedGoods,
                icon: Icons.inventory_2_outlined,
                color: Color(0xFF7C3AED),
                subtitle: 'Етикетка та передатування',
              ),
              _ProcessCard(
                type: ProductionRequestType.returnToStock,
                icon: Icons.assignment_return_outlined,
                color: Color(0xFFB45309),
                subtitle: 'Повернення на склад',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: FutureBuilder<List<ProductionRequest>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return _ProductionEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: 'Не вдалося завантажити заявки',
                    subtitle: '${snapshot.error}',
                  );
                }
                final requests = snapshot.data ?? const [];
                if (requests.isEmpty) {
                  return const _ProductionEmpty(
                    icon: Icons.factory_outlined,
                    title: 'Активних заявок ще немає',
                    subtitle: 'Створіть першу виробничу заявку',
                  );
                }
                return Column(
                  children: [
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
          ),
        ],
      ),
    );
  }
}

class _ProcessCard extends StatelessWidget {
  const _ProcessCard({
    required this.type,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  final ProductionRequestType type;
  final IconData icon;
  final Color color;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerTheme.color ?? cs.outlineVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push('/production/new?type=${type.code}'),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const Spacer(),
            Text(type.title,
                style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.62),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductionEmpty extends StatelessWidget {
  const _ProductionEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: cs.primary),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.62)),
            ),
          ],
        ),
      ),
    );
  }
}
