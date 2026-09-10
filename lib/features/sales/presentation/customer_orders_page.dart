import 'dart:async';
import 'dart:math' as math;

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

  Future<void> _showAnalyticsReport() async {
    final fallbackStart = DateTime(2026, 4, 21);
    final today = DateTime.now();
    final range = _range;
    final orders = await context.read<SalesService>().getCustomerOrders(
          dateFrom: range?.start ?? fallbackStart,
          dateTo: range?.end ?? today,
          partner: _partnerQuery,
          orgUid: _orgUid ?? '',
          limit: 5000,
        );
    if (!mounted) return;

    final rowsByDate = <DateTime, _SalesDayAnalytics>{};

    for (final order in orders) {
      final sourceDate = order.shipmentDate ?? order.date;
      if (sourceDate == null) continue;

      final day = DateTime(sourceDate.year, sourceDate.month, sourceDate.day);
      final row = rowsByDate.putIfAbsent(day, () => _SalesDayAnalytics(day));
      row.count += 1;
      row.amount += order.amount;

      final orgKey = (order.organizationUid.isNotEmpty
              ? order.organizationUid
              : order.organizationName)
          .trim();
      if (orgKey.isNotEmpty) row.organizations.add(orgKey);

      final partnerKey = order.partnerName.trim();
      if (partnerKey.isNotEmpty) row.partners.add(partnerKey);
    }

    final rows = rowsByDate.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Аналітика замовлень'),
        content: SizedBox(
          width: 760,
          height: 520,
          child: _OrdersAnalyticsTable(
            rows: rows,
            formatDate: _fmtShort,
            formatMoney: _fmtMoney,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Закрити'),
          ),
        ],
      ),
    );
  }

  Future<void> _showItemsAnalyticsReport() async {
    final fallbackStart = DateTime(2026, 4, 21);
    final today = DateTime.now();
    final range = _range;
    final future = context.read<SalesService>().getItemsAnalytics(
          dateFrom: range?.start ?? fallbackStart,
          dateTo: range?.end ?? today,
          partner: _partnerQuery,
          orgUid: _orgUid ?? '',
          limit: 300,
        );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Попит по номенклатурі'),
        content: SizedBox(
          width: 840,
          height: 560,
          child: FutureBuilder<List<SalesItemAnalyticsRow>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _ReportState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Не вдалося завантажити попит',
                  subtitle: snapshot.error.toString(),
                );
              }
              final rows = snapshot.data ?? const <SalesItemAnalyticsRow>[];
              if (rows.isEmpty) {
                return const _ReportState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Даних по номенклатурі немає',
                  subtitle: 'Змініть період або фільтри.',
                );
              }
              return _ItemsDemandReport(
                rows: rows,
                formatNumber: _fmtNumber,
                formatMoney: _fmtMoney,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Закрити'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTelegramParser() async {
    final service = context.read<SalesService>();
    final controller = TextEditingController();
    SalesTelegramParseResult? result;
    var loading = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> parse() async {
            final text = controller.text.trim();
            if (text.isEmpty) {
              setDialogState(() => error = 'Вставте текст замовлення');
              return;
            }
            setDialogState(() {
              loading = true;
              error = null;
              result = null;
            });
            try {
              final parsed = await service.parseTelegramOrderText(
                text: text,
                orgUid: _orgUid ?? '',
              );
              if (!dialogContext.mounted) return;
              setDialogState(() => result = parsed);
            } catch (e) {
              if (!dialogContext.mounted) return;
              setDialogState(() => error = '$e');
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => loading = false);
              }
            }
          }

          final parsed = result;
          return AlertDialog(
            title: const Text('Розпізнати замовлення'),
            content: SizedBox(
              width: 820,
              height: 620,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: controller,
                    minLines: 5,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Текст з Telegram',
                      hintText: 'Лагер-2\nІпа-3\nБ/а темне - 2',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: loading ? null : parse,
                        icon: loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome_rounded),
                        label: const Text('Розпізнати'),
                      ),
                      const SizedBox(width: 12),
                      if (parsed != null)
                        Text(
                          'Розпізнано: ${parsed.recognizedCount}, невідомо: ${parsed.unrecognizedCount}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                    ],
                  ),
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
                  const SizedBox(height: 12),
                  Expanded(
                    child: parsed == null
                        ? const Center(
                            child: Text('Вставте текст і натисніть розпізнати'),
                          )
                        : _TelegramParsePreview(
                            result: parsed,
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
                      onPressed: loading || orders.isEmpty
                          ? null
                          : _showAnalyticsReport,
                      icon: const Icon(Icons.analytics_outlined, size: 18),
                      label: Text(compact ? 'Аналіз' : 'Аналітика'),
                    ),
                    OutlinedButton.icon(
                      onPressed: loading ? null : _showItemsAnalyticsReport,
                      icon: const Icon(Icons.trending_up_rounded, size: 18),
                      label: Text(compact ? 'Попит' : 'Попит'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _showTelegramParser,
                      icon: const Icon(Icons.text_snippet_outlined, size: 18),
                      label: Text(compact ? 'Текст' : 'З Telegram'),
                    ),
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

class _TelegramParsePreview extends StatelessWidget {
  const _TelegramParsePreview({
    required this.result,
    required this.formatNumber,
  });

  final SalesTelegramParseResult result;
  final String Function(double) formatNumber;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recognized = result.rows;
    final unrecognized = result.unrecognized;
    return ListView(
      children: [
        _TelegramPreviewSection(
          title: 'Розпізнані позиції',
          count: recognized.length,
          icon: Icons.check_circle_outline_rounded,
          color: cs.primary,
          emptyText: 'Поки немає розпізнаних позицій',
          children: [
            for (final row in recognized)
              _TelegramPreviewRow(
                row: row,
                formatNumber: formatNumber,
                color: cs.primary,
              ),
          ],
        ),
        const SizedBox(height: 12),
        _TelegramPreviewSection(
          title: 'Потребують словника',
          count: unrecognized.length,
          icon: Icons.help_outline_rounded,
          color: cs.error,
          emptyText: 'Невідомих рядків немає',
          children: [
            for (final row in unrecognized)
              _TelegramPreviewRow(
                row: row,
                formatNumber: formatNumber,
                color: cs.error,
              ),
          ],
        ),
      ],
    );
  }
}

class _TelegramPreviewSection extends StatelessWidget {
  const _TelegramPreviewSection({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.emptyText,
    required this.children,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .32),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  emptyText,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: .64),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _TelegramPreviewRow extends StatelessWidget {
  const _TelegramPreviewRow({
    required this.row,
    required this.formatNumber,
    required this.color,
  });

  final SalesTelegramParsedRow row;
  final String Function(double) formatNumber;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = row.itemName.trim().isEmpty ? row.alias : row.itemName;
    final subtitle =
        row.sourceLine.trim().isEmpty ? row.alias : row.sourceLine.trim();
    final sourceLabel = row.source == 'alias'
        ? 'словник'
        : row.source == 'catalog'
            ? 'каталог'
            : row.source;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: .62),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (row.suggestions.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    'Схоже на: ${row.suggestions.map((e) => e.name).join(', ')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: .7),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatNumber(row.quantity),
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (row.unitText.isNotEmpty)
                Text(
                  row.unitText,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: .58),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                '$sourceLabel ${row.confidence}%',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: .54),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
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

class _SalesDayAnalytics {
  _SalesDayAnalytics(this.date);

  final DateTime date;
  int count = 0;
  double amount = 0;
  final Set<String> organizations = {};
  final Set<String> partners = {};

  double get average => count == 0 ? 0 : amount / count;
}

enum _AnalyticsView { chart, table }

enum _AnalyticsMetricKind { amount, orders, average }

class _OrdersAnalyticsTable extends StatelessWidget {
  const _OrdersAnalyticsTable({
    required this.rows,
    required this.formatDate,
    required this.formatMoney,
  });

  final List<_SalesDayAnalytics> rows;
  final String Function(DateTime) formatDate;
  final String Function(double, String) formatMoney;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (rows.isEmpty) {
      return Center(
        child: Text(
          'У поточній вибірці немає даних для аналітики.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: .66),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    final totalCount = rows.fold<int>(0, (sum, row) => sum + row.count);
    final totalAmount = rows.fold<double>(0, (sum, row) => sum + row.amount);
    final totalPartners = <String>{};
    final totalOrgs = <String>{};
    for (final row in rows) {
      totalPartners.addAll(row.partners);
      totalOrgs.addAll(row.organizations);
    }
    final dataPeriod = rows.length == 1
        ? formatDate(rows.first.date)
        : '${formatDate(rows.last.date)}-${formatDate(rows.first.date)}';

    var view = _AnalyticsView.chart;
    var selectedMetrics = <_AnalyticsMetricKind>{
      _AnalyticsMetricKind.amount,
      _AnalyticsMetricKind.orders,
    };

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _AnalyticsMetric(
                  title: 'Період даних',
                  value: dataPeriod,
                  icon: Icons.calendar_month_outlined,
                ),
                _AnalyticsMetric(
                  title: 'Замовлення',
                  value: totalCount.toString(),
                  icon: Icons.receipt_long_outlined,
                ),
                _AnalyticsMetric(
                  title: 'Сума',
                  value: formatMoney(totalAmount, 'UAH'),
                  icon: Icons.payments_outlined,
                ),
                _AnalyticsMetric(
                  title: 'Партнери',
                  value: totalPartners.length.toString(),
                  icon: Icons.groups_2_outlined,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<_AnalyticsView>(
                segments: const [
                  ButtonSegment(
                    value: _AnalyticsView.chart,
                    icon: Icon(Icons.stacked_bar_chart_rounded, size: 18),
                    label: Text('Графік'),
                  ),
                  ButtonSegment(
                    value: _AnalyticsView.table,
                    icon: Icon(Icons.table_rows_rounded, size: 18),
                    label: Text('Таблиця'),
                  ),
                ],
                selected: {view},
                onSelectionChanged: (selected) {
                  setDialogState(() => view = selected.first);
                },
              ),
            ),
            if (view == _AnalyticsView.chart) ...[
              const SizedBox(height: 10),
              _AnalyticsMetricToggles(
                selected: selectedMetrics,
                onChanged: (next) {
                  setDialogState(() {
                    selectedMetrics =
                        next.isEmpty ? {_AnalyticsMetricKind.amount} : next;
                  });
                },
              ),
            ],
            const SizedBox(height: 14),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: view == _AnalyticsView.chart
                    ? _OrdersAnalyticsChart(
                        key: const ValueKey('chart'),
                        rows: rows,
                        selectedMetrics: selectedMetrics,
                        formatDate: formatDate,
                        formatMoney: formatMoney,
                      )
                    : _OrdersAnalyticsRowsTable(
                        key: const ValueKey('table'),
                        rows: rows,
                        totalCount: totalCount,
                        totalAmount: totalAmount,
                        totalOrgs: totalOrgs.length,
                        totalPartners: totalPartners.length,
                        formatDate: formatDate,
                        formatMoney: formatMoney,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OrdersAnalyticsRowsTable extends StatelessWidget {
  const _OrdersAnalyticsRowsTable({
    super.key,
    required this.rows,
    required this.totalCount,
    required this.totalAmount,
    required this.totalOrgs,
    required this.totalPartners,
    required this.formatDate,
    required this.formatMoney,
  });

  final List<_SalesDayAnalytics> rows;
  final int totalCount;
  final double totalAmount;
  final int totalOrgs;
  final int totalPartners;
  final String Function(DateTime) formatDate;
  final String Function(double, String) formatMoney;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _AnalyticsRow(
            date: 'Дата',
            count: 'Зам.',
            amount: 'Сума',
            average: 'Середній',
            orgs: 'Орг.',
            partners: 'Партн.',
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
                return _AnalyticsRow(
                  date: formatDate(row.date),
                  count: row.count.toString(),
                  amount: formatMoney(row.amount, 'UAH'),
                  average: formatMoney(row.average, 'UAH'),
                  orgs: row.organizations.length.toString(),
                  partners: row.partners.length.toString(),
                );
              },
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          _AnalyticsRow(
            date: 'Разом',
            count: totalCount.toString(),
            amount: formatMoney(totalAmount, 'UAH'),
            average: formatMoney(
              totalCount == 0 ? 0 : totalAmount / totalCount,
              'UAH',
            ),
            orgs: totalOrgs.toString(),
            partners: totalPartners.toString(),
            header: true,
          ),
        ],
      ),
    );
  }
}

class _AnalyticsMetricToggles extends StatelessWidget {
  const _AnalyticsMetricToggles({
    required this.selected,
    required this.onChanged,
  });

  final Set<_AnalyticsMetricKind> selected;
  final ValueChanged<Set<_AnalyticsMetricKind>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetricToggleChip(
          label: 'Сума',
          color: Theme.of(context).colorScheme.primary,
          selected: selected.contains(_AnalyticsMetricKind.amount),
          onSelected: (value) => _toggle(_AnalyticsMetricKind.amount, value),
        ),
        _MetricToggleChip(
          label: 'Замовлення',
          color: const Color(0xFF0EA5E9),
          selected: selected.contains(_AnalyticsMetricKind.orders),
          onSelected: (value) => _toggle(_AnalyticsMetricKind.orders, value),
        ),
        _MetricToggleChip(
          label: 'Середній чек',
          color: const Color(0xFFF59E0B),
          selected: selected.contains(_AnalyticsMetricKind.average),
          onSelected: (value) => _toggle(_AnalyticsMetricKind.average, value),
        ),
      ],
    );
  }

  void _toggle(_AnalyticsMetricKind metric, bool value) {
    final next = {...selected};
    if (value) {
      next.add(metric);
    } else {
      next.remove(metric);
    }
    onChanged(next);
  }
}

class _MetricToggleChip extends StatelessWidget {
  const _MetricToggleChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final Color color;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      label: Text(label),
      avatar: Icon(
        selected ? Icons.check_rounded : Icons.circle,
        size: selected ? 16 : 10,
        color: color,
      ),
      selectedColor: color.withValues(alpha: .16),
      checkmarkColor: color,
      side: BorderSide(
        color: selected
            ? color.withValues(alpha: .62)
            : color.withValues(alpha: .28),
      ),
      onSelected: onSelected,
    );
  }
}

class _OrdersAnalyticsChart extends StatefulWidget {
  const _OrdersAnalyticsChart({
    super.key,
    required this.rows,
    required this.selectedMetrics,
    required this.formatDate,
    required this.formatMoney,
  });

  final List<_SalesDayAnalytics> rows;
  final Set<_AnalyticsMetricKind> selectedMetrics;
  final String Function(DateTime) formatDate;
  final String Function(double, String) formatMoney;

  @override
  State<_OrdersAnalyticsChart> createState() => _OrdersAnalyticsChartState();
}

class _OrdersAnalyticsChartState extends State<_OrdersAnalyticsChart> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chartRows = widget.rows.reversed.toList();
    final activeMetrics = widget.selectedMetrics.isEmpty
        ? {_AnalyticsMetricKind.amount}
        : widget.selectedMetrics;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.stacked_bar_chart_rounded,
                  size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Динаміка по днях',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                activeMetrics.length == 1
                    ? _analyticsMetricTitle(activeMetrics.first)
                    : 'кожен показник у своєму масштабі',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: .58),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final minWidth = math.max(
                    constraints.maxWidth,
                    chartRows.length * 118.0,
                  );
                  return Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: minWidth > constraints.maxWidth,
                    trackVisibility: minWidth > constraints.maxWidth,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: minWidth,
                        height: constraints.maxHeight,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: _AnalyticsLineChart(
                            rows: chartRows,
                            selectedMetrics: activeMetrics,
                            formatDate: widget.formatDate,
                            formatMoney: widget.formatMoney,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsLineChart extends StatelessWidget {
  const _AnalyticsLineChart({
    required this.rows,
    required this.selectedMetrics,
    required this.formatDate,
    required this.formatMoney,
  });

  final List<_SalesDayAnalytics> rows;
  final Set<_AnalyticsMetricKind> selectedMetrics;
  final String Function(DateTime) formatDate;
  final String Function(double, String) formatMoney;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = _analyticsMetricColors(cs);
    final showAmountAxis = selectedMetrics.length == 1 &&
        selectedMetrics.contains(_AnalyticsMetricKind.amount);
    final topValue = _analyticsMetricMax(rows, _AnalyticsMetricKind.amount);
    final midValue = topValue / 2;

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _AnalyticsLineChartPainter(
              rows: rows,
              selectedMetrics: selectedMetrics,
              colors: colors,
              grid: cs.outlineVariant.withValues(alpha: .52),
            ),
          ),
        ),
        if (showAmountAxis) ...[
          Positioned(
            left: 0,
            top: 8,
            child: _ChartAxisLabel(text: formatMoney(topValue, 'UAH')),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: _ChartAxisLabel(text: formatMoney(midValue, 'UAH')),
            ),
          ),
          const Positioned(
            left: 0,
            bottom: 28,
            child: _ChartAxisLabel(text: '0'),
          ),
        ],
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              showAmountAxis ? 76 : 16,
              16,
              16,
              28,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (rows.isEmpty) return const SizedBox.shrink();
                final chartSize =
                    Size(constraints.maxWidth, constraints.maxHeight);
                final visibleMetrics = _analyticsMetricDrawOrder
                    .where(selectedMetrics.contains)
                    .toList();
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final metric in visibleMetrics)
                      for (var i = 0; i < rows.length; i++)
                        Builder(
                          builder: (context) {
                            final points = _chartPointsForMetric(
                              rows: rows,
                              size: chartSize,
                              metric: metric,
                              maxValue: _analyticsMetricMax(rows, metric),
                            );
                            final point = points[i];
                            final top = (point.dy +
                                    _analyticsMetricLabelOffset(
                                      metric,
                                      visibleMetrics.length,
                                    ))
                                .clamp(0.0, constraints.maxHeight - 18);
                            return Positioned(
                              left: point.dx - 41,
                              top: top,
                              width: 82,
                              child: Tooltip(
                                message: _analyticsMetricTooltip(
                                  rows[i],
                                  formatDate,
                                  formatMoney,
                                ),
                                child: Text(
                                  _analyticsMetricLabel(rows[i], metric),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors[metric],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    for (var i = 0; i < rows.length; i++)
                      Positioned(
                        left: (rows.length == 1
                                ? constraints.maxWidth / 2
                                : constraints.maxWidth *
                                    i /
                                    (rows.length - 1)) -
                            36,
                        bottom: -24,
                        width: 72,
                        child: Text(
                          formatDate(rows[i].date),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: .7),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ChartAxisLabel extends StatelessWidget {
  const _ChartAxisLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .54),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AnalyticsLineChartPainter extends CustomPainter {
  const _AnalyticsLineChartPainter({
    required this.rows,
    required this.selectedMetrics,
    required this.colors,
    required this.grid,
  });

  final List<_SalesDayAnalytics> rows;
  final Set<_AnalyticsMetricKind> selectedMetrics;
  final Map<_AnalyticsMetricKind, Color> colors;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final showAmountAxis = selectedMetrics.length == 1 &&
        selectedMetrics.contains(_AnalyticsMetricKind.amount);
    final chartPadding = EdgeInsets.fromLTRB(
      showAmountAxis ? 76 : 16,
      16,
      16,
      28,
    );
    final chartSize = Size(
      size.width - chartPadding.left - chartPadding.right,
      size.height - chartPadding.top - chartPadding.bottom,
    );
    final origin = Offset(chartPadding.left, chartPadding.top);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final ratio in const [0.0, .5, 1.0]) {
      final y = origin.dy + chartSize.height * ratio;
      canvas.drawLine(
        Offset(origin.dx, y),
        Offset(origin.dx + chartSize.width, y),
        gridPaint,
      );
    }

    if (rows.isEmpty) return;

    for (final metric
        in _analyticsMetricDrawOrder.where(selectedMetrics.contains)) {
      final color = colors[metric] ?? const Color(0xFF2DD4BF);
      final maxValue = _analyticsMetricMax(rows, metric);
      final points = _chartPointsForMetric(
        rows: rows,
        size: chartSize,
        metric: metric,
        maxValue: maxValue,
      ).map((point) => point + origin).toList();
      if (points.isEmpty) continue;

      if (points.length == 1) {
        canvas.drawCircle(points.first, 5, Paint()..color = color);
        continue;
      }

      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        final previous = points[i - 1];
        final current = points[i];
        final controlX = previous.dx + (current.dx - previous.dx) / 2;
        linePath.cubicTo(
          controlX,
          previous.dy,
          controlX,
          current.dy,
          current.dx,
          current.dy,
        );
      }

      if (metric == _AnalyticsMetricKind.amount) {
        final fillPath = Path.from(linePath)
          ..lineTo(points.last.dx, origin.dy + chartSize.height)
          ..lineTo(points.first.dx, origin.dy + chartSize.height)
          ..close();

        canvas.drawPath(
          fillPath,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: .24),
                color.withValues(alpha: .03),
              ],
            ).createShader(
              Rect.fromLTWH(
                origin.dx,
                origin.dy,
                chartSize.width,
                chartSize.height,
              ),
            ),
        );
      }

      canvas.drawPath(
        linePath,
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );

      final pointBorder = Paint()..color = color.withValues(alpha: .22);
      final pointFill = Paint()..color = color;
      for (final point in points) {
        canvas.drawCircle(point, 6, pointBorder);
        canvas.drawCircle(point, 3.5, pointFill);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AnalyticsLineChartPainter oldDelegate) {
    return oldDelegate.rows != rows ||
        oldDelegate.selectedMetrics != selectedMetrics ||
        oldDelegate.colors != colors ||
        oldDelegate.grid != grid;
  }
}

Map<_AnalyticsMetricKind, Color> _analyticsMetricColors(ColorScheme cs) {
  return {
    _AnalyticsMetricKind.amount: cs.primary,
    _AnalyticsMetricKind.orders: const Color(0xFF0EA5E9),
    _AnalyticsMetricKind.average: const Color(0xFFF59E0B),
  };
}

const _analyticsMetricDrawOrder = [
  _AnalyticsMetricKind.amount,
  _AnalyticsMetricKind.orders,
  _AnalyticsMetricKind.average,
];

String _analyticsMetricTitle(_AnalyticsMetricKind metric) {
  return switch (metric) {
    _AnalyticsMetricKind.amount => 'сума',
    _AnalyticsMetricKind.orders => 'замовлення',
    _AnalyticsMetricKind.average => 'середній чек',
  };
}

double _analyticsMetricValue(
  _SalesDayAnalytics row,
  _AnalyticsMetricKind metric,
) {
  return switch (metric) {
    _AnalyticsMetricKind.amount => row.amount,
    _AnalyticsMetricKind.orders => row.count.toDouble(),
    _AnalyticsMetricKind.average => row.average,
  };
}

double _analyticsMetricMax(
  List<_SalesDayAnalytics> rows,
  _AnalyticsMetricKind metric,
) {
  return rows.fold<double>(
    0,
    (max, row) => math.max(max, _analyticsMetricValue(row, metric)),
  );
}

double _analyticsMetricLabelOffset(
  _AnalyticsMetricKind metric,
  int metricsCount,
) {
  if (metricsCount <= 1) return -28;
  return switch (metric) {
    _AnalyticsMetricKind.amount => -42,
    _AnalyticsMetricKind.orders => -26,
    _AnalyticsMetricKind.average => 8,
  };
}

String _analyticsMetricLabel(
  _SalesDayAnalytics row,
  _AnalyticsMetricKind metric,
) {
  return switch (metric) {
    _AnalyticsMetricKind.amount => _compactChartNumber(row.amount),
    _AnalyticsMetricKind.orders => row.count.toString(),
    _AnalyticsMetricKind.average => _compactChartNumber(row.average),
  };
}

String _compactChartNumber(double value) {
  final abs = value.abs();
  if (abs >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (abs >= 1000) {
    final text = (value / 1000).toStringAsFixed(abs >= 10000 ? 0 : 1);
    return '${text}K';
  }
  return value
      .toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)
      .replaceAll('.', ',');
}

String _analyticsMetricTooltip(
  _SalesDayAnalytics row,
  String Function(DateTime) formatDate,
  String Function(double, String) formatMoney,
) {
  return '${formatDate(row.date)}\n'
      'Сума: ${formatMoney(row.amount, 'UAH')}\n'
      'Замовлення: ${row.count}\n'
      'Середній: ${formatMoney(row.average, 'UAH')}';
}

List<Offset> _chartPointsForMetric({
  required List<_SalesDayAnalytics> rows,
  required Size size,
  required _AnalyticsMetricKind metric,
  required double maxValue,
}) {
  if (rows.isEmpty) return const [];
  if (rows.length == 1) {
    final value = _analyticsMetricValue(rows.first, metric);
    final ratio = maxValue <= 0 ? 0.0 : value / maxValue;
    return [
      Offset(size.width / 2, size.height * (1 - ratio.clamp(0.0, 1.0))),
    ];
  }

  return [
    for (var i = 0; i < rows.length; i++)
      Offset(
        size.width * i / (rows.length - 1),
        size.height *
            (1 -
                (maxValue <= 0
                    ? 0.0
                    : (_analyticsMetricValue(rows[i], metric) / maxValue)
                        .clamp(0.0, 1.0))),
      ),
  ];
}

class _AnalyticsMetric extends StatelessWidget {
  const _AnalyticsMetric({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 152),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: .62),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
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

enum _ItemsDemandView { top, growth, decline }

enum _ItemsDemandDisplay { table, chart }

class _ItemsDemandReport extends StatefulWidget {
  const _ItemsDemandReport({
    required this.rows,
    required this.formatNumber,
    required this.formatMoney,
  });

  final List<SalesItemAnalyticsRow> rows;
  final String Function(double) formatNumber;
  final String Function(double, String) formatMoney;

  @override
  State<_ItemsDemandReport> createState() => _ItemsDemandReportState();
}

class _ItemsDemandReportState extends State<_ItemsDemandReport> {
  _ItemsDemandView _view = _ItemsDemandView.top;
  _ItemsDemandDisplay _display = _ItemsDemandDisplay.chart;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = widget.rows;
    final totalQuantity =
        rows.fold<double>(0, (sum, row) => sum + row.quantity);
    final totalAmount = rows.fold<double>(0, (sum, row) => sum + row.amount);
    final growing = rows.where((row) => row.deltaQuantity > 0).length;
    final falling = rows.where((row) => row.deltaQuantity < 0).length;
    final displayRows = _displayRows(rows);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _AnalyticsMetric(
              title: 'Позицій',
              value: rows.length.toString(),
              icon: Icons.inventory_2_outlined,
            ),
            _AnalyticsMetric(
              title: 'Кількість',
              value: widget.formatNumber(totalQuantity),
              icon: Icons.stacked_bar_chart_rounded,
            ),
            _AnalyticsMetric(
              title: 'Сума',
              value: widget.formatMoney(totalAmount, 'UAH'),
              icon: Icons.payments_outlined,
            ),
            _AnalyticsMetric(
              title: 'Зростає',
              value: growing.toString(),
              icon: Icons.trending_up_rounded,
            ),
            _AnalyticsMetric(
              title: 'Падає',
              value: falling.toString(),
              icon: Icons.trending_down_rounded,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<_ItemsDemandView>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _ItemsDemandView.top,
                  icon: Icon(Icons.format_list_numbered_rounded, size: 18),
                  label: Text('Топ'),
                ),
                ButtonSegment(
                  value: _ItemsDemandView.growth,
                  icon: Icon(Icons.trending_up_rounded, size: 18),
                  label: Text('Зростає'),
                ),
                ButtonSegment(
                  value: _ItemsDemandView.decline,
                  icon: Icon(Icons.trending_down_rounded, size: 18),
                  label: Text('Падає'),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (selected) {
                setState(() => _view = selected.first);
              },
            ),
            SegmentedButton<_ItemsDemandDisplay>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _ItemsDemandDisplay.chart,
                  icon: Icon(Icons.bar_chart_rounded, size: 18),
                  label: Text('Графік'),
                ),
                ButtonSegment(
                  value: _ItemsDemandDisplay.table,
                  icon: Icon(Icons.table_rows_rounded, size: 18),
                  label: Text('Таблиця'),
                ),
              ],
              selected: {_display},
              onSelectionChanged: (selected) {
                setState(() => _display = selected.first);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: displayRows.isEmpty
                ? _ReportState(
                    icon: _view == _ItemsDemandView.growth
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    title: _view == _ItemsDemandView.growth
                        ? 'Зростання не знайдено'
                        : 'Падіння не знайдено',
                    subtitle: 'За вибраний період таких позицій немає.',
                  )
                : _display == _ItemsDemandDisplay.chart
                    ? _ItemsDemandChart(
                        rows: displayRows,
                        view: _view,
                        formatNumber: widget.formatNumber,
                      )
                    : _ItemsDemandRowsTable(
                        rows: displayRows,
                        formatNumber: widget.formatNumber,
                      ),
          ),
        ),
      ],
    );
  }

  List<SalesItemAnalyticsRow> _displayRows(List<SalesItemAnalyticsRow> rows) {
    final next = switch (_view) {
      _ItemsDemandView.top => [...rows],
      _ItemsDemandView.growth =>
        rows.where((row) => row.deltaQuantity > 0).toList(),
      _ItemsDemandView.decline =>
        rows.where((row) => row.deltaQuantity < 0).toList(),
    };

    switch (_view) {
      case _ItemsDemandView.top:
        next.sort((a, b) {
          final byQuantity = b.quantity.compareTo(a.quantity);
          return byQuantity != 0 ? byQuantity : b.amount.compareTo(a.amount);
        });
      case _ItemsDemandView.growth:
        next.sort((a, b) {
          final byDelta = b.deltaQuantity.compareTo(a.deltaQuantity);
          return byDelta != 0
              ? byDelta
              : b.deltaPercent.compareTo(a.deltaPercent);
        });
      case _ItemsDemandView.decline:
        next.sort((a, b) {
          final byDelta = a.deltaQuantity.compareTo(b.deltaQuantity);
          return byDelta != 0
              ? byDelta
              : a.deltaPercent.compareTo(b.deltaPercent);
        });
    }
    return next;
  }
}

class _ItemsDemandRowsTable extends StatelessWidget {
  const _ItemsDemandRowsTable({
    required this.rows,
    required this.formatNumber,
  });

  final List<SalesItemAnalyticsRow> rows;
  final String Function(double) formatNumber;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        const _DemandRow(
          item: 'Номенклатура',
          unit: 'Од.',
          current: 'Поточ.',
          previous: 'Було',
          delta: 'Delta',
          percent: '%',
          orders: 'Зам.',
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
              return _DemandRow(
                item: row.itemName,
                unit: row.unitName.trim().isEmpty ? '-' : row.unitName,
                current: formatNumber(row.quantity),
                previous: formatNumber(row.previousQuantity),
                delta: _signedNumber(row.deltaQuantity, formatNumber),
                percent: _percent(row.deltaPercent),
                orders: row.orders.toString(),
                deltaPositive: row.deltaQuantity > 0,
                deltaNegative: row.deltaQuantity < 0,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ItemsDemandChart extends StatelessWidget {
  const _ItemsDemandChart({
    required this.rows,
    required this.view,
    required this.formatNumber,
  });

  final List<SalesItemAnalyticsRow> rows;
  final _ItemsDemandView view;
  final String Function(double) formatNumber;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxValue = rows.fold<double>(
      0,
      (max, row) {
        final current = row.quantity.abs();
        final previous = row.previousQuantity.abs();
        final value = current > previous ? current : previous;
        return value > max ? value : max;
      },
    );
    final title = switch (view) {
      _ItemsDemandView.top => 'Топ продажів за кількістю',
      _ItemsDemandView.growth => 'Що виросло проти попереднього періоду',
      _ItemsDemandView.decline => 'Що просіло проти попереднього періоду',
    };
    final accent = switch (view) {
      _ItemsDemandView.top => cs.primary,
      _ItemsDemandView.growth => const Color(0xFF22C55E),
      _ItemsDemandView.decline => const Color(0xFFEF4444),
    };
    const growthColor = Color(0xFF22C55E);
    const declineColor = Color(0xFFEF4444);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                'зараз / було / зміна',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: .58),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final row = rows[index];
                final currentFactor = maxValue == 0
                    ? 0.0
                    : (row.quantity.abs() / maxValue).clamp(0, 1).toDouble();
                final previousFactor = maxValue == 0
                    ? 0.0
                    : (row.previousQuantity.abs() / maxValue)
                        .clamp(0, 1)
                        .toDouble();
                final changeColor = row.deltaQuantity > 0
                    ? growthColor
                    : row.deltaQuantity < 0
                        ? declineColor
                        : cs.onSurface.withValues(alpha: .62);
                return _DemandBar(
                  index: index + 1,
                  title: row.itemName,
                  subtitle: row.unitName.trim().isEmpty ? '-' : row.unitName,
                  currentValue: formatNumber(row.quantity),
                  previousValue: formatNumber(row.previousQuantity),
                  deltaValue: _signedNumber(row.deltaQuantity, formatNumber),
                  percent: _percent(row.deltaPercent),
                  currentFactor: currentFactor,
                  previousFactor: previousFactor,
                  currentColor:
                      view == _ItemsDemandView.top ? changeColor : accent,
                  changeColor: changeColor,
                  mutedColor: cs.surfaceContainerHighest.withValues(alpha: .52),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DemandBar extends StatelessWidget {
  const _DemandBar({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.currentValue,
    required this.previousValue,
    required this.deltaValue,
    required this.percent,
    required this.currentFactor,
    required this.previousFactor,
    required this.currentColor,
    required this.changeColor,
    required this.mutedColor,
  });

  final int index;
  final String title;
  final String subtitle;
  final String currentValue;
  final String previousValue;
  final String deltaValue;
  final String percent;
  final double currentFactor;
  final double previousFactor;
  final Color currentColor;
  final Color changeColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                index.toString().padLeft(2, '0'),
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: .46),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 192,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Зараз',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: .48),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      currentValue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: currentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const SizedBox(width: 28),
            Expanded(
              child: Column(
                children: [
                  _DemandMiniBar(
                    factor: currentFactor,
                    color: currentColor,
                    trackColor: mutedColor,
                    height: 10,
                  ),
                  const SizedBox(height: 4),
                  _DemandMiniBar(
                    factor: previousFactor,
                    color: cs.onSurface.withValues(alpha: .30),
                    trackColor: mutedColor.withValues(alpha: .70),
                    height: 7,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 192,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Було',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: .48),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          previousValue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: .66),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: .52),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        deltaValue,
                        style: TextStyle(
                          color: changeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          percent,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: changeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DemandMiniBar extends StatelessWidget {
  const _DemandMiniBar({
    required this.factor,
    required this.color,
    required this.trackColor,
    required this.height,
  });

  final double factor;
  final Color color;
  final Color trackColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        FractionallySizedBox(
          widthFactor: factor,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ],
    );
  }
}

class _DemandRow extends StatelessWidget {
  const _DemandRow({
    required this.item,
    required this.unit,
    required this.current,
    required this.previous,
    required this.delta,
    required this.percent,
    required this.orders,
    this.header = false,
    this.deltaPositive = false,
    this.deltaNegative = false,
  });

  final String item;
  final String unit;
  final String current;
  final String previous;
  final String delta;
  final String percent;
  final String orders;
  final bool header;
  final bool deltaPositive;
  final bool deltaNegative;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final deltaColor = deltaPositive
        ? const Color(0xFF22C55E)
        : deltaNegative
            ? const Color(0xFFEF4444)
            : cs.onSurface.withValues(alpha: .72);
    final style = TextStyle(
      color: header ? cs.onSurface.withValues(alpha: .72) : cs.onSurface,
      fontSize: header ? 12 : 13,
      fontWeight: header ? FontWeight.w900 : FontWeight.w700,
    );
    final deltaStyle = style.copyWith(color: header ? style.color : deltaColor);

    return Container(
      color: header ? cs.surfaceContainerHighest.withValues(alpha: .38) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Text(
              item,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(unit, textAlign: TextAlign.end, style: style),
          ),
          Expanded(
            flex: 2,
            child: Text(current, textAlign: TextAlign.end, style: style),
          ),
          Expanded(
            flex: 2,
            child: Text(previous, textAlign: TextAlign.end, style: style),
          ),
          Expanded(
            flex: 2,
            child: Text(delta, textAlign: TextAlign.end, style: deltaStyle),
          ),
          Expanded(
            flex: 2,
            child: Text(percent, textAlign: TextAlign.end, style: deltaStyle),
          ),
          Expanded(
            flex: 1,
            child: Text(orders, textAlign: TextAlign.end, style: style),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsRow extends StatelessWidget {
  const _AnalyticsRow({
    required this.date,
    required this.count,
    required this.amount,
    required this.average,
    required this.orgs,
    required this.partners,
    this.header = false,
  });

  final String date;
  final String count;
  final String amount;
  final String average;
  final String orgs;
  final String partners;
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
            flex: 2,
            child: Text(date, style: style),
          ),
          Expanded(
            flex: 1,
            child: Text(count, textAlign: TextAlign.end, style: style),
          ),
          Expanded(
            flex: 3,
            child: Text(amount, textAlign: TextAlign.end, style: style),
          ),
          Expanded(
            flex: 3,
            child: Text(average, textAlign: TextAlign.end, style: style),
          ),
          Expanded(
            flex: 1,
            child: Text(orgs, textAlign: TextAlign.end, style: style),
          ),
          Expanded(
            flex: 1,
            child: Text(partners, textAlign: TextAlign.end, style: style),
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

class _ReportState extends StatelessWidget {
  const _ReportState({
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: cs.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: .68),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _signedNumber(double value, String Function(double) formatNumber) {
  final text = formatNumber(value.abs());
  if (value > 0) return '+$text';
  if (value < 0) return '-$text';
  return text;
}

String _percent(double value) {
  final sign = value > 0 ? '+' : '';
  final fixed =
      value.abs() >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '$sign${fixed.replaceAll('.', ',')}%';
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
