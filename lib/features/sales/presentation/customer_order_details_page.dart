import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../sales_service.dart';

class CustomerOrderDetailsPage extends StatefulWidget {
  const CustomerOrderDetailsPage({
    super.key,
    required this.uid,
  });

  final String uid;

  @override
  State<CustomerOrderDetailsPage> createState() =>
      _CustomerOrderDetailsPageState();
}

class _CustomerOrderDetailsPageState extends State<CustomerOrderDetailsPage> {
  late Future<SalesCustomerOrderDetails?> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<SalesService>().getCustomerOrderById(widget.uid);
  }

  void _reload() {
    setState(() {
      _future = context.read<SalesService>().getCustomerOrderById(widget.uid);
    });
  }

  String _fmtDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year.toString().substring(2)}';
  }

  String _fmtNumber(double value) {
    return value
        .toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
  }

  String _fmtMoney(double value, String currency) {
    return '${_fmtNumber(value)} ${currency.trim().isEmpty ? 'UAH' : currency.trim()}';
  }

  String _fmtQty(double value) =>
      value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 3);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 620;
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;
    final panel = cs.surface.withValues(alpha: isDark ? 0.92 : 0.96);
    final soft = cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.5 : 1);
    final text = cs.onSurface;
    final sub = theme.textTheme.bodyMedium?.color ??
        cs.onSurface.withValues(alpha: 0.72);

    return FutureBuilder<SalesCustomerOrderDetails?>(
      future: _future,
      builder: (context, snapshot) {
        final details = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final error = snapshot.error;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            compact ? 12 : 16,
            8,
            compact ? 12 : 16,
            24,
          ),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Назад',
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Замовлення клієнта',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: text,
                        ),
                      ),
                      if (details != null)
                        Text(
                          '№ ${_dash(details.header.number)}',
                          style: TextStyle(
                            color: sub,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Оновити',
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (error != null)
              _StatePanel(
                border: border,
                panel: panel,
                icon: Icons.cloud_off_outlined,
                title: 'Не вдалося завантажити замовлення',
                subtitle: '$error',
                action: OutlinedButton(
                  onPressed: _reload,
                  child: const Text('Спробувати ще раз'),
                ),
              )
            else if (loading)
              _StatePanel(
                border: border,
                panel: panel,
                icon: Icons.sync_rounded,
                title: 'Завантажуємо замовлення',
                subtitle: 'Отримую шапку та товари з 1С.',
              )
            else if (details == null)
              _StatePanel(
                border: border,
                panel: panel,
                icon: Icons.inbox_outlined,
                title: 'Замовлення не знайдено',
                subtitle: 'Перевірте доступ або оновіть список.',
              )
            else ...[
              _HeaderPanel(
                order: details.header,
                border: border,
                panel: panel,
                soft: soft,
                text: text,
                sub: sub,
                formatDate: _fmtDate,
                formatMoney: _fmtMoney,
              ),
              const SizedBox(height: 14),
              _LinesPanel(
                lines: details.lines,
                border: border,
                panel: panel,
                soft: soft,
                text: text,
                sub: sub,
                formatMoney: (value) =>
                    _fmtMoney(value, details.header.currency),
                formatNumber: _fmtNumber,
                formatQty: _fmtQty,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _HeaderPanel extends StatelessWidget {
  const _HeaderPanel({
    required this.order,
    required this.border,
    required this.panel,
    required this.soft,
    required this.text,
    required this.sub,
    required this.formatDate,
    required this.formatMoney,
  });

  final SalesCustomerOrder order;
  final Color border;
  final Color panel;
  final Color soft;
  final Color text;
  final Color sub;
  final String Function(DateTime?) formatDate;
  final String Function(double, String) formatMoney;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final partner = Text(
                _dash(order.partnerName),
                maxLines: compact ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: text,
                  fontSize: compact ? 20 : 22,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                ),
              );
              final amount = Text(
                formatMoney(order.amount, order.currency),
                textAlign: compact ? TextAlign.left : TextAlign.right,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: compact ? 24 : 24,
                  fontWeight: FontWeight.w900,
                ),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: partner),
                        const SizedBox(width: 10),
                        _StatusBadge(value: order.status),
                      ],
                    ),
                    const SizedBox(height: 10),
                    amount,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: partner),
                  const SizedBox(width: 12),
                  amount,
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            _dash(order.contractorName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: sub,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 520) return const SizedBox.shrink();
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeaderChip(
                    icon: Icons.calendar_month_outlined,
                    value: formatDate(order.shipmentDate),
                  ),
                  _HeaderChip(
                    icon: Icons.apartment_rounded,
                    value: order.organizationName,
                  ),
                  _HeaderChip(
                    icon: Icons.warehouse_outlined,
                    value: order.warehouseName,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 520
                      ? 2
                      : 1;
              final items = [
                _Fact('Організація', order.organizationName),
                _Fact('Оферта', order.agreementName),
                _Fact('Договір', order.contractName),
                _Fact('Склад', order.warehouseName),
                _Fact('Дата', formatDate(order.date)),
                _Fact('Відвантаження', formatDate(order.shipmentDate)),
                _Fact('Статус', order.status),
                _Fact('Коментар', order.comment),
              ];
              if (constraints.maxWidth < 520) {
                return _FactsList(
                  items: [
                    _Fact('Оферта', order.agreementName),
                    _Fact('Договір', order.contractName),
                    _Fact('Дата', formatDate(order.date)),
                    _Fact('Коментар', order.comment),
                  ],
                  border: border,
                  soft: soft,
                  text: text,
                  sub: sub,
                );
              }
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: columns == 4
                    ? 4.4
                    : columns == 2
                        ? 3.5
                        : 4.2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  for (final item in items)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: soft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: sub,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _dash(item.value),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: text,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LinesPanel extends StatelessWidget {
  const _LinesPanel({
    required this.lines,
    required this.border,
    required this.panel,
    required this.soft,
    required this.text,
    required this.sub,
    required this.formatMoney,
    required this.formatNumber,
    required this.formatQty,
  });

  final List<SalesCustomerOrderLine> lines;
  final Color border;
  final Color panel;
  final Color soft;
  final Color text;
  final Color sub;
  final String Function(double) formatMoney;
  final String Function(double) formatNumber;
  final String Function(double) formatQty;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: soft,
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Товари',
                  style: TextStyle(
                    color: text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  lines.length.toString(),
                  style: TextStyle(
                    color: sub,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (lines.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Center(
                child: Text(
                  'Товари не заповнені',
                  style: TextStyle(color: sub, fontWeight: FontWeight.w800),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 720) {
                  return _MobileLinesTable(
                    lines: lines,
                    border: border,
                    soft: soft,
                    text: text,
                    sub: sub,
                    formatMoney: formatMoney,
                    formatNumber: formatNumber,
                    formatQty: formatQty,
                  );
                }
                return Column(
                  children: [
                    _LineHeader(soft: soft, border: border),
                    for (final line in lines)
                      _LineRow(
                        line: line,
                        border: border,
                        text: text,
                        sub: sub,
                        formatMoney: formatMoney,
                        formatQty: formatQty,
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _FactsList extends StatelessWidget {
  const _FactsList({
    required this.items,
    required this.border,
    required this.soft,
    required this.text,
    required this.sub,
  });

  final List<_Fact> items;
  final Color border;
  final Color soft;
  final Color text;
  final Color sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      items[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: sub,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _dash(items[i].value),
                      textAlign: TextAlign.right,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: text,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        height: 1.16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _dash(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final text = _dash(value);
    final color = text.toLowerCase().contains('резерв')
        ? const Color(0xFF0EA5E9)
        : Theme.of(context).colorScheme.primary;
    return Container(
      constraints: const BoxConstraints(maxWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }
}

class _LineHeader extends StatelessWidget {
  const _LineHeader({required this.soft, required this.border});

  final Color soft;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
    return Container(
      height: 40,
      color: soft,
      child: Row(
        children: [
          _Cell('№', flex: 5, color: color),
          _Cell('Номенклатура', flex: 36, color: color),
          _Cell('Кількість', flex: 12, color: color, alignRight: true),
          _Cell('Вид ціни', flex: 18, color: color),
          _Cell('Ціна', flex: 14, color: color, alignRight: true),
          _Cell('Сума', flex: 15, color: color, alignRight: true),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.border,
    required this.text,
    required this.sub,
    required this.formatMoney,
    required this.formatQty,
  });

  final SalesCustomerOrderLine line;
  final Color border;
  final Color text;
  final Color sub;
  final String Function(double) formatMoney;
  final String Function(double) formatQty;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          _Cell(line.number.toString(), flex: 5, color: sub),
          Expanded(
            flex: 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dash(line.itemName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: text,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (line.characteristicName.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      line.characteristicName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: sub,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          _Cell(
            '${formatQty(line.quantity)} ${line.unitName}',
            flex: 12,
            color: text,
            strong: true,
            alignRight: true,
          ),
          _Cell(_dash(line.priceTypeName), flex: 18, color: sub),
          _Cell(
            formatMoney(line.price),
            flex: 14,
            color: sub,
            alignRight: true,
          ),
          _Cell(
            formatMoney(line.amount),
            flex: 15,
            color: text,
            strong: true,
            alignRight: true,
          ),
        ],
      ),
    );
  }
}

class _MobileLinesTable extends StatelessWidget {
  const _MobileLinesTable({
    required this.lines,
    required this.border,
    required this.soft,
    required this.text,
    required this.sub,
    required this.formatMoney,
    required this.formatNumber,
    required this.formatQty,
  });

  final List<SalesCustomerOrderLine> lines;
  final Color border;
  final Color soft;
  final Color text;
  final Color sub;
  final String Function(double) formatMoney;
  final String Function(double) formatNumber;
  final String Function(double) formatQty;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: soft,
            border: Border(top: BorderSide(color: border)),
          ),
          child: Row(
            children: [
              _MobileHeadCell('Номенклатура', flex: 34, color: sub),
              _MobileHeadCell('К-сть', flex: 13, color: sub, alignRight: true),
              _MobileHeadCell('Ціна', flex: 18, color: sub, alignRight: true),
              _MobileHeadCell('Сума', flex: 20, color: sub, alignRight: true),
            ],
          ),
        ),
        for (final line in lines)
          _MobileLineRow(
            line: line,
            border: border,
            text: text,
            sub: sub,
            formatMoney: formatMoney,
            formatNumber: formatNumber,
            formatQty: formatQty,
          ),
      ],
    );
  }
}

class _MobileLineRow extends StatelessWidget {
  const _MobileLineRow({
    required this.line,
    required this.border,
    required this.text,
    required this.sub,
    required this.formatMoney,
    required this.formatNumber,
    required this.formatQty,
  });

  final SalesCustomerOrderLine line;
  final Color border;
  final Color text;
  final Color sub;
  final String Function(double) formatMoney;
  final String Function(double) formatNumber;
  final String Function(double) formatQty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: border))),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 34,
                child: Text(
                  _dash(line.itemName),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
              ),
              _MobileDataCell(
                '${formatQty(line.quantity)} ${line.unitName}',
                flex: 13,
                color: text,
                strong: true,
              ),
              _MobileDataCell(
                formatNumber(line.price),
                flex: 18,
                color: sub,
              ),
              _MobileDataCell(
                formatNumber(line.amount),
                flex: 20,
                color: text,
                strong: true,
              ),
            ],
          ),
          if (line.priceTypeName.trim().isNotEmpty ||
              line.characteristicName.trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                [
                  if (line.priceTypeName.trim().isNotEmpty)
                    line.priceTypeName.trim(),
                  if (line.characteristicName.trim().isNotEmpty)
                    line.characteristicName.trim(),
                ].join(' / '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: sub,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MobileHeadCell extends StatelessWidget {
  const _MobileHeadCell(
    this.value, {
    required this.flex,
    required this.color,
    this.alignRight = false,
  });

  final String value;
  final int flex;
  final Color color;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MobileDataCell extends StatelessWidget {
  const _MobileDataCell(
    this.value, {
    required this.flex,
    required this.color,
    this.strong = false,
  });

  final String value;
  final int flex;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(left: 7),
        child: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
            height: 1.12,
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(
    this.value, {
    required this.flex,
    required this.color,
    this.strong = false,
    this.alignRight = false,
  });

  final String value;
  final int flex;
  final Color color;
  final bool strong;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            color: color,
            fontSize: 12.5,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            height: 1.18,
          ),
        ),
      ),
    );
  }
}

class _Fact {
  const _Fact(this.label, this.value);

  final String label;
  final String value;
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.border,
    required this.panel,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final Color border;
  final Color panel;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 260),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 38),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          if (action != null) ...[
            const SizedBox(height: 18),
            action!,
          ],
        ],
      ),
    );
  }
}

String _dash(String value) => value.trim().isEmpty ? '-' : value.trim();
