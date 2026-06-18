import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth/session_store.dart';
import '../sales_service.dart';

class CustomerOrdersPage extends StatefulWidget {
  const CustomerOrdersPage({super.key});

  @override
  State<CustomerOrdersPage> createState() => _CustomerOrdersPageState();
}

class _CustomerOrdersPageState extends State<CustomerOrdersPage> {
  DateTimeRange? _range;
  String _partnerQuery = '';
  String? _orgUid;
  List<OrgAccess> _orgs = const [];
  late Future<List<SalesCustomerOrder>> _future;

  final _partnerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _range = DateTimeRange(
      start: today,
      end: today,
    );
    _future = Future.value(const <SalesCustomerOrder>[]);
    _loadOrgs();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _partnerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrgs() async {
    final session = await SessionStore.loadSession();
    if (!mounted) return;
    setState(() {
      _orgs = session?.orgs ?? const [];
    });
  }

  void _reload() {
    final fallbackStart = DateTime(2026, 4, 21);
    final today = DateTime.now();
    final range = _range;

    setState(() {
      _future = context.read<SalesService>().getCustomerOrders(
            dateFrom: range?.start ?? fallbackStart,
            dateTo: range?.end ?? today,
            partner: _partnerQuery,
            orgUid: _orgUid ?? '',
          );
    });
  }

  void _resetFilters() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _partnerQuery = '';
      _partnerCtrl.clear();
      _orgUid = null;
      _range = DateTimeRange(
        start: today,
        end: today,
      );
    });
    _reload();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2026, 4, 21),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _range,
      locale: const Locale('uk', 'UA'),
      helpText: 'Період замовлень',
      cancelText: 'Скасувати',
      confirmText: 'Застосувати',
      saveText: 'Застосувати',
    );

    if (picked == null) return;
    setState(() => _range = picked);
    _reload();
  }

  String get _periodShort {
    if (_range == null) return 'З 21.04.26';
    return '${_fmtShort(_range!.start)}–${_fmtShort(_range!.end)}';
  }

  String get _orgShort {
    final uid = _orgUid?.trim() ?? '';
    if (uid.isEmpty) return 'Усі';
    for (final org in _orgs) {
      if (_orgValue(org) == uid) return org.name.isEmpty ? uid : org.name;
    }
    return uid;
  }

  String _fmtShort(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year.toString().substring(2)}';

  String _fmtMoney(double value, String currency) {
    final text = value
        .toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
    return '$text ${currency.trim().isEmpty ? 'UAH' : currency.trim()}';
  }

  String _fmtNumber(double value) {
    return value
        .toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
  }

  Future<void> _showDebtReport() async {
    final service = context.read<SalesService>();
    final controller = TextEditingController();
    Timer? debounce;
    var partners = <SalesReference>[];
    var debts = <SalesDebtRow>[];
    SalesReference? selected;
    var loadingPartners = false;
    var loadingDebt = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> searchPartners(String query) async {
            setDialogState(() {
              loadingPartners = true;
              error = null;
            });
            try {
              final found = await service.searchPartners(query);
              if (!dialogContext.mounted) return;
              setDialogState(() => partners = found);
            } catch (e) {
              if (!dialogContext.mounted) return;
              setDialogState(() => error = '$e');
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => loadingPartners = false);
              }
            }
          }

          Future<void> loadDebt(SalesReference partner) async {
            setDialogState(() {
              selected = partner;
              controller.text = partner.name;
              partners = const [];
              debts = const [];
              loadingDebt = true;
              error = null;
            });
            try {
              final rows = await service.getReceivables(
                partnerUid: partner.uid,
                contractorUid: '',
              );
              if (!dialogContext.mounted) return;
              setDialogState(() => debts = rows);
            } catch (e) {
              if (!dialogContext.mounted) return;
              setDialogState(() => error = '$e');
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => loadingDebt = false);
              }
            }
          }

          void scheduleSearch(String query) {
            debounce?.cancel();
            debounce = Timer(
              const Duration(milliseconds: 300),
              () => searchPartners(query),
            );
          }

          return AlertDialog(
            title: const Text('Дебіторка партнера'),
            content: SizedBox(
              width: 720,
              height: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Партнер',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: loadingPartners
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              tooltip: 'Знайти',
                              onPressed: () => searchPartners(controller.text),
                              icon: const Icon(Icons.arrow_forward_rounded),
                            ),
                    ),
                    onChanged: scheduleSearch,
                    onSubmitted: searchPartners,
                  ),
                  const SizedBox(height: 10),
                  if (partners.isNotEmpty)
                    Flexible(
                      child: Material(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: partners.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final partner = partners[index];
                            return ListTile(
                              dense: true,
                              title: Text(
                                partner.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: partner.code.isEmpty
                                  ? null
                                  : Text(partner.code),
                              onTap: () => loadDebt(partner),
                            );
                          },
                        ),
                      ),
                    ),
                  if (selected != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      selected!.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Expanded(
                    child: loadingDebt
                        ? const Center(child: CircularProgressIndicator())
                        : _DebtReportTable(
                            rows: debts,
                            formatNumber: _fmtNumber,
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Закрити'),
              ),
            ],
          );
        },
      ),
    );
    debounce?.cancel();
    controller.dispose();
  }

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
    final accent = cs.primary;

    return FutureBuilder<List<SalesCustomerOrder>>(
      future: _future,
      builder: (context, snapshot) {
        final orders = snapshot.data ?? const <SalesCustomerOrder>[];
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final total = orders.fold<double>(0, (sum, item) => sum + item.amount);
        final orgCount = orders
            .map((e) =>
                e.organizationUid.isEmpty ? e.orgCode : e.organizationUid)
            .where((e) => e.isNotEmpty)
            .toSet()
            .length;
        final today = DateTime.now();
        final todayCount = orders.where((item) {
          final d = item.shipmentDate;
          return d != null &&
              d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
        }).length;

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
                        'Замовлення клієнтів',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: text,
                        ),
                      ),
                      Text(
                        'Продажі, відвантаження та суми за період',
                        style: TextStyle(
                          color: sub,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showDebtReport,
                      icon: const Icon(Icons.account_balance_wallet_outlined,
                          size: 18),
                      label: Text(compact ? 'Борг' : 'Дебіторка'),
                    ),
                    FilledButton.icon(
                      onPressed: () =>
                          context.push('/sales/customer-order/new'),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(compact ? 'Новий' : 'Новий заказ'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (compact)
              _MobileSummaryStrip(
                panel: panel,
                border: border,
                orders: orders.length,
                total: _fmtMoney(total, 'UAH'),
                today: todayCount,
                orgs: orgCount,
              )
            else
              _SummaryGrid(
                panel: panel,
                border: border,
                children: [
                  _SummaryCard(
                    icon: Icons.receipt_long_outlined,
                    title: orders.length.toString(),
                    subtitle: 'Замовлень у вибірці',
                    color: accent,
                  ),
                  _SummaryCard(
                    icon: Icons.payments_outlined,
                    title: _fmtMoney(total, 'UAH'),
                    subtitle: 'Сума у вибірці',
                    color: const Color(0xFF14B8A6),
                  ),
                  _SummaryCard(
                    icon: Icons.local_shipping_outlined,
                    title: todayCount.toString(),
                    subtitle: 'Відвантаження сьогодні',
                    color: const Color(0xFF0EA5E9),
                  ),
                  _SummaryCard(
                    icon: Icons.apartment_rounded,
                    title: orgCount.toString(),
                    subtitle: 'Організацій',
                    color: const Color(0xFFF59E0B),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: border),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final partnerFilter = _SearchField(
                    controller: _partnerCtrl,
                    label: 'Партнер',
                    value: _partnerQuery.isEmpty ? 'Усі' : _partnerQuery,
                    onSubmitted: (value) {
                      _partnerQuery = value.trim();
                      _reload();
                    },
                  );
                  final periodFilter = _FilterButton(
                    icon: Icons.calendar_month_outlined,
                    label: 'Період',
                    value: _periodShort,
                    onTap: _pickRange,
                  );
                  final orgFilter = _OrgFilter(
                    orgs: _orgs,
                    value: _orgUid,
                    label: _orgShort,
                    onChanged: (value) {
                      setState(() => _orgUid = value);
                      _reload();
                    },
                  );
                  final resetButton = IconButton.filledTonal(
                    tooltip: 'Скинути фільтри',
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                  );
                  final refreshButton = IconButton.filledTonal(
                    tooltip: 'Оновити',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                  );

                  final narrowFilters = [
                    partnerFilter,
                    periodFilter,
                    orgFilter,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        resetButton,
                        const SizedBox(width: 8),
                        refreshButton,
                      ],
                    ),
                  ];

                  if (wide) {
                    return Row(
                      children: [
                        Expanded(flex: 3, child: partnerFilter),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: periodFilter),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: orgFilter),
                        const SizedBox(width: 10),
                        resetButton,
                        const SizedBox(width: 10),
                        refreshButton,
                      ],
                    );
                  }

                  return Column(
                    children: [
                      for (var i = 0; i < narrowFilters.length; i++) ...[
                        SizedBox(
                          width: double.infinity,
                          child: narrowFilters[i],
                        ),
                        if (i != narrowFilters.length - 1)
                          const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            if (snapshot.hasError)
              _StatePanel(
                border: border,
                panel: panel,
                icon: Icons.cloud_off_outlined,
                title: 'Не вдалося завантажити замовлення',
                subtitle: snapshot.error.toString(),
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
                subtitle: 'Отримую дані з 1С за вибраний період.',
              )
            else if (orders.isEmpty)
              _StatePanel(
                border: border,
                panel: panel,
                icon: Icons.inbox_outlined,
                title: 'Замовлень не знайдено',
                subtitle: 'Змініть період або фільтри.',
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 760) {
                    return _OrdersCards(
                      orders: orders,
                      panel: panel,
                      border: border,
                      text: text,
                      sub: sub,
                      formatDate: _fmtShort,
                      formatMoney: _fmtMoney,
                    );
                  }
                  return _OrdersTable(
                    orders: orders,
                    panel: panel,
                    soft: soft,
                    border: border,
                    text: text,
                    sub: sub,
                    formatDate: _fmtShort,
                    formatMoney: _fmtMoney,
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.children,
    required this.panel,
    required this.border,
  });

  final List<Widget> children;
  final Color panel;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: columns == 4
              ? 4.2
              : columns == 2
                  ? 3.6
                  : 4.4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: children
              .map(
                (child) => Container(
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: border),
                  ),
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.24)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileSummaryStrip extends StatelessWidget {
  const _MobileSummaryStrip({
    required this.panel,
    required this.border,
    required this.orders,
    required this.total,
    required this.today,
    required this.orgs,
  });

  final Color panel;
  final Color border;
  final int orders;
  final String total;
  final int today;
  final int orgs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MobileMetric(
                  label: 'Замовлення',
                  value: orders.toString(),
                  icon: Icons.receipt_long_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MobileMetric(
                  label: 'Сьогодні',
                  value: today.toString(),
                  icon: Icons.local_shipping_outlined,
                  color: const Color(0xFF0EA5E9),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MobileMetric(
                  label: 'Орг.',
                  value: orgs.toString(),
                  icon: Icons.apartment_rounded,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.payments_outlined,
                size: 18,
                color: const Color(0xFF14B8A6),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  total,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MobileMetric extends StatelessWidget {
  const _MobileMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.label,
    required this.value,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String value;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        labelText: label,
        hintText: value,
        suffixIcon: IconButton(
          tooltip: 'Знайти',
          onPressed: () => onSubmitted(controller.text),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          labelText: label,
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _OrgFilter extends StatelessWidget {
  const _OrgFilter({
    required this.orgs,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final List<OrgAccess> orgs;
  final String? value;
  final String label;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.apartment_rounded),
        labelText: 'Організація',
      ),
      hint: Text(label),
      items: [
        const DropdownMenuItem(value: '', child: Text('Усі')),
        for (final org in orgs)
          DropdownMenuItem(
            value: _orgValue(org),
            child: Text(org.name.isEmpty ? _orgValue(org) : org.name),
          ),
      ],
      onChanged: (next) => onChanged(next?.isEmpty == true ? null : next),
    );
  }
}

String _orgValue(OrgAccess org) =>
    org.uid.trim().isNotEmpty ? org.uid.trim() : org.code.trim();

class _OrdersCards extends StatelessWidget {
  const _OrdersCards({
    required this.orders,
    required this.panel,
    required this.border,
    required this.text,
    required this.sub,
    required this.formatDate,
    required this.formatMoney,
  });

  final List<SalesCustomerOrder> orders;
  final Color panel;
  final Color border;
  final Color text;
  final Color sub;
  final String Function(DateTime) formatDate;
  final String Function(double, String) formatMoney;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < orders.length; i++) ...[
          _OrderCard(
            order: orders[i],
            panel: panel,
            border: border,
            text: text,
            sub: sub,
            formatDate: formatDate,
            formatMoney: formatMoney,
            onTap: () => context.push('/sales/customer-orders/${orders[i].id}'),
          ),
          if (i != orders.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.panel,
    required this.border,
    required this.text,
    required this.sub,
    required this.formatDate,
    required this.formatMoney,
    required this.onTap,
  });

  final SalesCustomerOrder order;
  final Color panel;
  final Color border;
  final Color text;
  final Color sub;
  final String Function(DateTime) formatDate;
  final String Function(double, String) formatMoney;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shipmentDate =
        order.shipmentDate == null ? '-' : formatDate(order.shipmentDate!);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _dash(order.partnerName),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: text,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            height: 1.12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dash(order.contractorName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: sub,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 104,
                      maxWidth: 132,
                    ),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatMoney(order.amount, order.currency),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: cs.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '№ ${_dash(order.number)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: sub,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _OrderChip(
                    icon: Icons.calendar_month_outlined,
                    text: shipmentDate,
                    color: cs.primary,
                  ),
                  _OrderChip(
                    icon: Icons.apartment_rounded,
                    text: _dash(order.organizationName),
                    color: const Color(0xFFF59E0B),
                  ),
                  _OrderChip(
                    icon: Icons.warehouse_outlined,
                    text: _dash(order.warehouseName),
                    color: const Color(0xFF0EA5E9),
                  ),
                ],
              ),
              if (order.agreementName.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  order.agreementName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: sub,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderChip extends StatelessWidget {
  const _OrderChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersTable extends StatelessWidget {
  const _OrdersTable({
    required this.orders,
    required this.panel,
    required this.soft,
    required this.border,
    required this.text,
    required this.sub,
    required this.formatDate,
    required this.formatMoney,
  });

  final List<SalesCustomerOrder> orders;
  final Color panel;
  final Color soft;
  final Color border;
  final Color text;
  final Color sub;
  final String Function(DateTime) formatDate;
  final String Function(double, String) formatMoney;

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
        children: [
          _OrderHeader(
            background: soft,
            border: border,
          ),
          for (final order in orders)
            _OrderRow(
              order: order,
              border: border,
              text: text,
              sub: sub,
              formatDate: formatDate,
              formatMoney: formatMoney,
              onTap: () => context.push('/sales/customer-orders/${order.id}'),
            ),
        ],
      ),
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({
    required this.background,
    required this.border,
  });

  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: background,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          _HeaderCell('Організація', flex: 13, color: color),
          _HeaderCell('Партнер / контрагент', flex: 28, color: color),
          _HeaderCell('Сума', flex: 11, color: color),
          _HeaderCell('Оферта', flex: 18, color: color),
          _HeaderCell('Відвантаження', flex: 11, color: color),
          _HeaderCell('Склад', flex: 14, color: color),
          _HeaderCell('№', flex: 7, color: color, alignRight: true),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.order,
    required this.border,
    required this.text,
    required this.sub,
    required this.formatDate,
    required this.formatMoney,
    required this.onTap,
  });

  final SalesCustomerOrder order;
  final Color border;
  final Color text;
  final Color sub;
  final String Function(DateTime) formatDate;
  final String Function(double, String) formatMoney;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shipmentDate =
        order.shipmentDate == null ? '-' : formatDate(order.shipmentDate!);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: border)),
          ),
          child: Row(
            children: [
              _OrderCell(
                order.organizationName,
                flex: 13,
                text: text,
                sub: sub,
              ),
              Expanded(
                flex: 28,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dash(order.partnerName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: text,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _dash(order.contractorName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: sub,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _OrderCell(
                formatMoney(order.amount, order.currency),
                flex: 11,
                text: text,
                sub: sub,
                strong: true,
              ),
              _OrderCell(
                order.agreementName,
                flex: 18,
                text: text,
                sub: sub,
              ),
              _OrderCell(
                shipmentDate,
                flex: 11,
                text: text,
                sub: sub,
              ),
              _OrderCell(
                order.warehouseName,
                flex: 14,
                text: text,
                sub: sub,
              ),
              _OrderCell(
                order.number,
                flex: 7,
                text: text,
                sub: sub,
                alignRight: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _OrderCell extends StatelessWidget {
  const _OrderCell(
    this.value, {
    required this.flex,
    required this.text,
    required this.sub,
    this.strong = false,
    this.alignRight = false,
  });

  final String value;
  final int flex;
  final Color text;
  final Color sub;
  final bool strong;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          _dash(value),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            color: strong ? text : sub,
            fontSize: 12.5,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            height: 1.18,
          ),
        ),
      ),
    );
  }
}

class _DebtReportTable extends StatelessWidget {
  const _DebtReportTable({
    required this.rows,
    required this.formatNumber,
  });

  final List<SalesDebtRow> rows;
  final String Function(double) formatNumber;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (rows.isEmpty) {
      return Center(
        child: Text(
          'Оберіть партнера або дані по розрахунках відсутні.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: .66),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    final totalDebt = rows.fold<double>(0, (sum, row) => sum + row.debt);
    final totalPrepayment =
        rows.fold<double>(0, (sum, row) => sum + row.prepayment);
    final totalBalance = rows.fold<double>(0, (sum, row) => sum + row.balance);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _DebtReportRow(
            contract: 'Договір',
            debt: 'Борг',
            prepayment: 'Передплата',
            balance: 'Сальдо',
            header: true,
          ),
          Expanded(
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: cs.outlineVariant,
              ),
              itemBuilder: (context, index) {
                final row = rows[index];
                return _DebtReportRow(
                  contract: row.contract.isEmpty ? 'Договір' : row.contract,
                  debt: formatNumber(row.debt),
                  prepayment: formatNumber(row.prepayment),
                  balance: formatNumber(row.balance),
                );
              },
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          _DebtReportRow(
            contract: 'Разом',
            debt: formatNumber(totalDebt),
            prepayment: formatNumber(totalPrepayment),
            balance: formatNumber(totalBalance),
            header: true,
          ),
        ],
      ),
    );
  }
}

class _DebtReportRow extends StatelessWidget {
  const _DebtReportRow({
    required this.contract,
    required this.debt,
    required this.prepayment,
    required this.balance,
    this.header = false,
  });

  final String contract;
  final String debt;
  final String prepayment;
  final String balance;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = TextStyle(
      color: header ? cs.onSurface.withValues(alpha: .72) : cs.onSurface,
      fontSize: header ? 12 : 13,
      fontWeight: header ? FontWeight.w900 : FontWeight.w700,
    );
    return Container(
      color: header ? cs.surfaceContainerHighest.withValues(alpha: .38) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              contract,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(debt, textAlign: TextAlign.end, style: style),
          ),
          Expanded(
            flex: 2,
            child: Text(prepayment, textAlign: TextAlign.end, style: style),
          ),
          Expanded(
            flex: 2,
            child: Text(balance, textAlign: TextAlign.end, style: style),
          ),
        ],
      ),
    );
  }
}

String _dash(String value) => value.trim().isEmpty ? '-' : value.trim();

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
            const SizedBox(height: 14),
            action!,
          ],
        ],
      ),
    );
  }
}
