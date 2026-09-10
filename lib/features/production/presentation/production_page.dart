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
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 1000;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          desktop ? 20 : 12,
          desktop ? 14 : 10,
          desktop ? 20 : 12,
          28,
        ),
        children: [
          _ProductionHeader(
            desktop: desktop,
            onCreate: () => _createRequest(),
            onTemplates: () => context.push('/production/templates'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'Виробничий маршрут',
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
                '6 етапів',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: .52),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1000
                  ? 3
                  : constraints.maxWidth >= 620
                      ? 2
                      : 1;
              final tileHeight = columns == 1 ? 78.0 : 74.0;
              final stages = <Widget>[
                _ProcessCard(
                  step: '01',
                  title: ProductionRequestType.rawMaterial.title,
                  icon: Icons.grain_rounded,
                  color: const Color(0xFF18A999),
                  subtitle: 'Пиво, лимонад, шаблони',
                  actionLabel: 'Створити',
                  onTap: () =>
                      _createRequest(ProductionRequestType.rawMaterial),
                ),
                _ProcessCard(
                  step: '02',
                  title: 'Варки',
                  icon: Icons.local_fire_department_outlined,
                  color: const Color(0xFFD8A72E),
                  subtitle: 'Паспорти, ЦКТ і варки',
                  actionLabel: 'Відкрити',
                  onTap: () => context.push('/production/brew-passports'),
                ),
                _ProcessCard(
                  step: '03',
                  title: 'Холодне відділення',
                  icon: Icons.ac_unit_rounded,
                  color: const Color(0xFF22B8CF),
                  subtitle: 'Бродіння та внесення у ЦКТ',
                  actionLabel: 'Відкрити',
                  onTap: () => context.push('/production/cold-department'),
                ),
                _ProcessCard(
                  step: '04',
                  title: ProductionRequestType.bottling.title,
                  icon: Icons.local_drink_outlined,
                  color: const Color(0xFF3B82F6),
                  subtitle: 'Тара, партії та розлив',
                  actionLabel: 'Відкрити',
                  onTap: () => context.push('/production/bottling'),
                ),
                _ProcessCard(
                  step: '05',
                  title: ProductionRequestType.finishedGoods.title,
                  icon: Icons.inventory_2_outlined,
                  color: const Color(0xFF9B6DFF),
                  subtitle: 'Етикетка та передатування',
                  actionLabel: 'Створити',
                  onTap: () =>
                      _createRequest(ProductionRequestType.finishedGoods),
                ),
                _ProcessCard(
                  step: '06',
                  title: ProductionRequestType.returnToStock.title,
                  icon: Icons.assignment_return_outlined,
                  color: const Color(0xFFFF9F43),
                  subtitle: 'Повернення на склад',
                  actionLabel: 'Створити',
                  onTap: () =>
                      _createRequest(ProductionRequestType.returnToStock),
                ),
              ];
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stages.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: tileHeight,
                ),
                itemBuilder: (context, index) => stages[index],
              );
            },
          ),
          const SizedBox(height: 14),
          _RequestsSection(
            future: _future,
            onCreate: () => _createRequest(),
            onRetry: _refresh,
            onRefresh: _refresh,
          ),
          const SizedBox(height: 16),
          _ProductionReportSection(future: _future),
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
                borderRadius: BorderRadius.circular(2),
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
          'Варки, розлив та переміщення між виробництвом і складом',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: .64),
          ),
        ),
      ],
    );

    final button = FilledButton.icon(
      onPressed: onCreate,
      style: FilledButton.styleFrom(
        minimumSize: Size(desktop ? 170 : double.infinity, 40),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
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
    required this.title,
    required this.icon,
    required this.color,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final String step;
  final String title;
  final IconData icon;
  final Color color;
  final String subtitle;
  final String actionLabel;
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
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _hovered ? widget.color.withValues(alpha: .08) : cs.surface,
          border: Border.all(color: _hovered ? widget.color : border),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: .12),
                      border: Border.all(
                          color: widget.color.withValues(alpha: .42)),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              widget.step,
                              style: TextStyle(
                                color: widget.color,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              widget.actionLabel,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: widget.color,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(Icons.arrow_forward_rounded,
                                size: 14, color: widget.color),
                          ],
                        ),
                      ],
                    ),
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
    required this.onRefresh,
  });

  final Future<List<ProductionRequest>> future;
  final VoidCallback onCreate;
  final VoidCallback onRetry;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(2),
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
                        borderRadius: BorderRadius.circular(2),
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
                    const Spacer(),
                    Tooltip(
                      message: 'Оновити список',
                      child: IconButton.filledTonal(
                        onPressed:
                            snapshot.connectionState == ConnectionState.waiting
                                ? null
                                : onRefresh,
                        icon: const Icon(Icons.refresh_rounded),
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
                _RequestsTable(
                  requests: requests,
                  onChanged: onRefresh,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RequestsTable extends StatelessWidget {
  const _RequestsTable({required this.requests, required this.onChanged});

  final List<ProductionRequest> requests;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          headingRowHeight: 34,
          dataRowMinHeight: 50,
          dataRowMaxHeight: 58,
          horizontalMargin: 12,
          columnSpacing: 18,
          border: TableBorder.all(color: cs.outlineVariant),
          columns: const [
            DataColumn(label: Text('Документ')),
            DataColumn(label: Text('Маршрут')),
            DataColumn(label: Text('Коментар')),
            DataColumn(label: Text('Статус')),
            DataColumn(label: Text('WMS')),
          ],
          rows: [
            for (final request in requests)
              DataRow(
                onSelectChanged: (_) async {
                  final changed = await context.push<bool>(
                    '/production/requests/${request.id}',
                  );
                  if (changed == true) onChanged();
                },
                cells: [
                  DataCell(SizedBox(
                    width: 330,
                    child: Text(
                      request.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  )),
                  DataCell(SizedBox(
                    width: 300,
                    child: Text(
                      request.subtitle.trim().isEmpty ? '—' : request.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
                  DataCell(SizedBox(
                    width: 230,
                    child: Text(
                      _requestCommentText(request.comment).isEmpty
                          ? '—'
                          : _requestCommentText(request.comment),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
                  DataCell(SizedBox(
                    width: 130,
                    child: Text(
                      request.status.trim().isEmpty ? '—' : request.status,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  )),
                  DataCell(SizedBox(
                    width: 340,
                    child: Text(
                      request.wmsStatus.trim().isEmpty
                          ? '—'
                          : request.wmsStatus,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

String _requestCommentText(String value) {
  var text = value.trim();
  if (text.startsWith('[MOVA]')) {
    text = text.substring(6).trim();
  }
  while (text.startsWith(';')) {
    text = text.substring(1).trim();
  }
  return text;
}

class _ProductionReportSection extends StatelessWidget {
  const _ProductionReportSection({required this.future});

  final Future<List<ProductionRequest>> future;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: border),
      ),
      child: FutureBuilder<List<ProductionRequest>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const SizedBox.shrink();

          final requests = snapshot.data ?? const <ProductionRequest>[];
          final totals = _buildProductionReportTotals(requests);
          final routeCount = totals
              .map((total) =>
                  '${total.sourceWarehouse}|${total.destinationWarehouse}')
              .toSet()
              .length;
          final lineCount = requests.fold<int>(
            0,
            (sum, request) => sum + request.lines.length,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        color: cs.tertiary.withValues(alpha: .11),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Icon(
                        Icons.summarize_outlined,
                        size: 20,
                        color: cs.tertiary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Звіт за 7 днів',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Що, куди і в якій кількості замовляли',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: .58),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: border, height: 1),
              if (snapshot.connectionState != ConnectionState.done)
                const SizedBox(
                  height: 110,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _ProductionReportMetric(
                            label: 'Замовлень',
                            value: '${requests.length}',
                          ),
                          _ProductionReportMetric(
                            label: 'Рядків',
                            value: '$lineCount',
                          ),
                          _ProductionReportMetric(
                            label: 'Маршрутів',
                            value: '$routeCount',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (requests.isEmpty)
                        Text(
                          'За останній тиждень замовлень немає.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: .62),
                          ),
                        )
                      else if (totals.isEmpty)
                        Text(
                          'Після оновлення API тут зʼявляться підсумки по товарах.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: .62),
                          ),
                        )
                      else ...[
                        _ProductionReportHeader(),
                        const SizedBox(height: 8),
                        for (final total in totals)
                          _ProductionReportRow(total: total),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ProductionReportMetric extends StatelessWidget {
  const _ProductionReportMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: cs.primary.withValues(alpha: .18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: .68),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductionReportHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final desktop = MediaQuery.sizeOf(context).width >= 820;

    if (!desktop) return const SizedBox.shrink();

    final style = theme.textTheme.labelMedium?.copyWith(
      color: cs.onSurface.withValues(alpha: .52),
      fontWeight: FontWeight.w900,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text('Що', style: style)),
          Expanded(flex: 4, child: Text('Куди', style: style)),
          SizedBox(
            width: 150,
            child: Text('Кількість', textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

class _ProductionReportRow extends StatelessWidget {
  const _ProductionReportRow({required this.total});

  final _ProductionReportTotal total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final desktop = MediaQuery.sizeOf(context).width >= 820;
    final route = [total.sourceWarehouse, total.destinationWarehouse]
        .where((value) => value.trim().isNotEmpty)
        .join(' → ');
    final quantity = [
      _formatReportQuantity(total.quantity),
      total.unitName,
    ].where((value) => value.trim().isNotEmpty).join(' ');

    final item = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          total.itemName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${total.orderCount} зам.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: .56),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    final routeText = Text(
      route.isEmpty ? 'Маршрут не вказано' : route,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: cs.onSurface.withValues(alpha: .72),
        fontWeight: FontWeight.w700,
      ),
    );

    final quantityText = Text(
      quantity,
      textAlign: desktop ? TextAlign.right : TextAlign.left,
      style: theme.textTheme.titleSmall?.copyWith(
        color: cs.primary,
        fontWeight: FontWeight.w900,
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .34),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: .55)),
      ),
      child: desktop
          ? Row(
              children: [
                Expanded(flex: 5, child: item),
                Expanded(flex: 4, child: routeText),
                SizedBox(width: 150, child: quantityText),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                item,
                const SizedBox(height: 8),
                routeText,
                const SizedBox(height: 8),
                quantityText,
              ],
            ),
    );
  }
}

class _ProductionReportTotal {
  _ProductionReportTotal({
    required this.itemName,
    required this.unitName,
    required this.sourceWarehouse,
    required this.destinationWarehouse,
  });

  final String itemName;
  final String unitName;
  final String sourceWarehouse;
  final String destinationWarehouse;
  final Set<String> orderIds = <String>{};
  double quantity = 0;

  int get orderCount => orderIds.length;

  void add(String orderId, double value) {
    quantity += value;
    if (orderId.trim().isNotEmpty) orderIds.add(orderId);
  }
}

List<_ProductionReportTotal> _buildProductionReportTotals(
  List<ProductionRequest> requests,
) {
  final totalsByKey = <String, _ProductionReportTotal>{};

  for (final request in requests) {
    final source = request.sourceWarehouse.trim();
    final destination = request.destinationWarehouse.trim();
    for (final line in request.lines) {
      final itemName = line.itemName.trim();
      if (itemName.isEmpty) continue;
      final unitName = line.unitName.trim();
      final key = [
        itemName.toLowerCase(),
        unitName.toLowerCase(),
        source.toLowerCase(),
        destination.toLowerCase(),
      ].join('|');
      final total = totalsByKey.putIfAbsent(
        key,
        () => _ProductionReportTotal(
          itemName: itemName,
          unitName: unitName,
          sourceWarehouse: source,
          destinationWarehouse: destination,
        ),
      );
      total.add(request.id, line.quantity);
    }
  }

  final totals = totalsByKey.values.toList()
    ..sort((left, right) {
      final itemCompare = left.itemName.compareTo(right.itemName);
      if (itemCompare != 0) return itemCompare;
      return left.destinationWarehouse.compareTo(right.destinationWarehouse);
    });
  return totals;
}

String _formatReportQuantity(double value) {
  final hasFraction = value.truncateToDouble() != value;
  final text = value.toStringAsFixed(hasFraction ? 3 : 0);
  return text.replaceAll(RegExp(r'\.?0+$'), '').replaceAll('.', ',');
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
                borderRadius: BorderRadius.circular(2),
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
