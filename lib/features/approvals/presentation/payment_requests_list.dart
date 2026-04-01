import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mova_intelligence_app/api/auth_provider.dart';
import '../approvals_service.dart';
import '../domain/payment_request.dart';
import 'payment_request_details_page.dart';
import 'widgets/payment_request_card.dart';
import '../../../main.dart';

enum _ApprovalsTab { incoming, mine }

class PaymentRequestsListPage extends StatefulWidget {
  const PaymentRequestsListPage({super.key});

  @override
  State<PaymentRequestsListPage> createState() => _PaymentRequestsListPageState();
}

class _PaymentRequestsListPageState extends State<PaymentRequestsListPage> {
  DateTimeRange? _range;
  PaymentRequestStatus? _statusFilter;
  String _contractorQuery = '';

  late Future<List<PaymentRequest>> _future;

  final Set<String> _hiddenIds = <String>{};
  final TextEditingController _contractorCtrl = TextEditingController();

  VoidCallback? _refreshListener;

  _ApprovalsTab _tab = _ApprovalsTab.mine;

  static const panel = Color(0xFF0F1B2D);
  static const border = Color(0xFF2A3B52);
  static const text = Color(0xFFF3F7FB);
  static const sub = Color(0xFFB7C4D1);
  static const accent = Color(0xFF22D3EE);

  @override
  void initState() {
    super.initState();
    _future = Future.value(const <PaymentRequest>[]);

    _refreshListener = () {
      if (!mounted) return;
      _reload();
    };
    approvalsRefreshNotifier.addListener(_refreshListener!);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final auth = context.read<AuthProvider>();
      final canApprove = auth.canApprovePayments;

      setState(() {
        _tab = canApprove ? _ApprovalsTab.incoming : _ApprovalsTab.mine;
      });

      _reload();
    });
  }

  @override
  void dispose() {
    if (_refreshListener != null) {
      approvalsRefreshNotifier.removeListener(_refreshListener!);
    }
    _contractorCtrl.dispose();
    super.dispose();
  }

  bool get _hasAnyFilter =>
      _range != null || _statusFilter != null || _contractorQuery.trim().isNotEmpty;

  bool get _isIncomingTab => _tab == _ApprovalsTab.incoming;

  String get _periodShort => _range == null ? 'Увесь' : 'Обрано';

  String get _statusShort =>
      _statusFilter == null ? 'Усі' : paymentStatusHuman(_statusFilter!);

  String get _contractorShort =>
      _contractorQuery.trim().isEmpty ? 'Усі' : _contractorQuery.trim();

  String get _rangeLabel {
    if (_range == null) return 'Увесь період';

    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

    return '${fmt(_range!.start)} — ${fmt(_range!.end)}';
  }

  Color _statusColor(PaymentRequestStatus s) {
    switch (s) {
      case PaymentRequestStatus.pending:
        return const Color(0xFF38BDF8);
      case PaymentRequestStatus.approvedByDepartmentHead:
        return const Color(0xFFA78BFA);
      case PaymentRequestStatus.approved:
        return const Color(0xFF22C55E);
      case PaymentRequestStatus.rejected:
        return const Color(0xFFF97373);
      case PaymentRequestStatus.topaid:
        return const Color(0xFFA78BFA);
      case PaymentRequestStatus.paid:
        return const Color(0xFF10B981);
      case PaymentRequestStatus.draft:
        return const Color(0xFF94A3B8);
    }
  }

  Future<void> _reload() async {
    final service = context.read<ApprovalsService>();
    final future = _isIncomingTab
        ? service.getIncomingRequests()
        : service.getMyRequests();

    setState(() => _future = future);

    try {
      final fresh = await future;
      if (!mounted) return;
      final freshIds = fresh.map((e) => e.id).toSet();
      setState(() => _hiddenIds.removeWhere((id) => freshIds.contains(id)));
    } catch (_) {}
  }

  Future<void> _onChangeStatus(PaymentRequest r, PaymentRequestStatus newStatus) async {
    final service = context.read<ApprovalsService>();

    try {
      await service.changeStatus(requestId: r.id, newStatus: newStatus);
      if (!mounted) return;

      setState(() => _hiddenIds.add(r.id));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == PaymentRequestStatus.approved
                ? 'Заявку погоджено'
                : 'Заявку відхилено',
          ),
        ),
      );

      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося змінити статус: $e')),
      );
    }
  }

  void _clearFilters() {
    setState(() {
      _range = null;
      _statusFilter = null;
      _contractorQuery = '';
      _contractorCtrl.text = '';
    });
  }

  void _openCreateRequest() {
    context.pushNamed('newPaymentRequest');
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initial = _range ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
      helpText: 'Виберіть період',
      cancelText: 'Скасувати',
      confirmText: 'Готово',
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => _range = picked);
    }
  }

  Future<void> _pickStatus() async {
    final picked = await showModalBottomSheet<PaymentRequestStatus?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _BottomSheetCard(
          title: 'Статус',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusPickTile(
                label: 'Усі',
                color: const Color(0xFF94A3B8),
                selected: _statusFilter == null,
                onTap: () => Navigator.of(ctx).pop(null),
              ),
              const SizedBox(height: 6),
              ...PaymentRequestStatus.values.map((s) {
                final c = _statusColor(s);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _StatusPickTile(
                    label: paymentStatusHuman(s),
                    color: c,
                    selected: _statusFilter == s,
                    onTap: () => Navigator.of(ctx).pop(s),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (picked != null || _statusFilter != null) {
      setState(() => _statusFilter = picked);
    }
  }

  Future<void> _pickContractor() async {
    _contractorCtrl.text = _contractorQuery;

    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: panel.withValues(alpha: 0.98),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'Контрагент',
            style: TextStyle(color: text, fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: _contractorCtrl,
            autofocus: true,
            style: const TextStyle(color: text),
            decoration: InputDecoration(
              hintText: 'Введіть частину назви…',
              hintStyle: TextStyle(color: sub.withValues(alpha: 0.9)),
              prefixIcon: const Icon(Icons.search, color: sub),
              filled: true,
              fillColor: const Color(0xFF16243C),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('__CLEAR__'),
              child: const Text('Очистити'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(_contractorCtrl.text),
              child: const Text('Готово'),
            ),
          ],
        );
      },
    );

    if (picked == null) return;

    if (picked == '__CLEAR__') {
      setState(() {
        _contractorQuery = '';
        _contractorCtrl.text = '';
      });
      return;
    }

    setState(() => _contractorQuery = picked.trim());
  }

  List<PaymentRequest> _applyFilters(List<PaymentRequest> raw) {
    var items = raw.where((r) => !_hiddenIds.contains(r.id)).toList();

    if (_range != null) {
      final start = DateTime(
        _range!.start.year,
        _range!.start.month,
        _range!.start.day,
      );
      final end = DateTime(
        _range!.end.year,
        _range!.end.month,
        _range!.end.day,
        23,
        59,
        59,
      );
      items = items
          .where((r) => !r.date.isBefore(start) && !r.date.isAfter(end))
          .toList();
    }

    if (_statusFilter != null) {
      items = items.where((r) => r.status == _statusFilter).toList();
    }

    final q = _contractorQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items
          .where((r) => r.contractorName.toLowerCase().contains(q))
          .toList();
    }

    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  Map<String, List<PaymentRequest>> _groupByDay(List<PaymentRequest> items) {
    final map = <String, List<PaymentRequest>>{};

    for (final item in items) {
      final key = _dayLabel(item.date);
      map.putIfAbsent(key, () => <PaymentRequest>[]).add(item);
    }

    return map;
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    final diff = today.difference(date).inDays;

    if (diff == 0) return 'Сьогодні';
    if (diff == 1) return 'Вчора';

    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  _ListStats _buildStats(List<PaymentRequest> items) {
    final total = items.length;
    final pending = items.where((e) {
      return e.status == PaymentRequestStatus.pending ||
          e.status == PaymentRequestStatus.approvedByDepartmentHead;
    }).length;
    final amount = items.fold<double>(0, (sum, e) => sum + e.amount);

    return _ListStats(
      total: total,
      pending: pending,
      amountLabel: amount == 0 ? '0' : amount.toStringAsFixed(0),
    );
  }

  void _switchTab(_ApprovalsTab tab) {
    if (_tab == tab) return;
    setState(() {
      _tab = tab;
      _hiddenIds.clear();
    });
    _reload();
  }

  Future<void> _openDetails(PaymentRequest r) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentRequestDetailsPage(
          uid: r.id,
          allowActions: _isIncomingTab,
        ),
      ),
    );

    if (!mounted) return;

    if (updated == true) {
      setState(() => _hiddenIds.add(r.id));
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canApprove = auth.canApprovePayments;

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                children: [
                  if (canApprove) ...[
                    _TabsCard(
                      currentTab: _tab,
                      onIncoming: () => _switchTab(_ApprovalsTab.incoming),
                      onMine: () => _switchTab(_ApprovalsTab.mine),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    decoration: BoxDecoration(
                      color: panel.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _FilterPill2L(
                                icon: Icons.tune_rounded,
                                title: 'Статус',
                                value: _statusShort,
                                accent: _statusFilter == null
                                    ? null
                                    : _statusColor(_statusFilter!),
                                onTap: _pickStatus,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _FilterPill2L(
                                icon: Icons.date_range_rounded,
                                title: 'Період',
                                value: _periodShort,
                                tooltip: _range == null ? 'Увесь період' : _rangeLabel,
                                onTap: _pickRange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _FilterPill2L(
                                icon: Icons.search_rounded,
                                title: 'Контрагент',
                                value: _contractorShort,
                                tooltip: 'Контрагент: $_contractorShort',
                                onTap: _pickContractor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _IconPill(
                              icon: _hasAnyFilter
                                  ? Icons.filter_alt_off_rounded
                                  : Icons.filter_alt_rounded,
                              accent: _hasAnyFilter ? accent : null,
                              onTap: _hasAnyFilter ? _clearFilters : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<PaymentRequest>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const _LoadingState();
                  }

                  if (snapshot.hasError) {
                    return RefreshIndicator(
                      onRefresh: _reload,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
                        children: [
                          _StateCard(
                            icon: Icons.cloud_off_rounded,
                            title: 'Не вдалося завантажити заявки',
                            subtitle: '${snapshot.error}',
                            actionLabel: 'Спробувати ще раз',
                            onAction: _reload,
                          ),
                        ],
                      ),
                    );
                  }

                  final rawItems = snapshot.data ?? const <PaymentRequest>[];
                  final items = _applyFilters(rawItems);
                  final stats = _buildStats(items);

                  if (items.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _reload,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                        children: [
                          _StatsRow(
                            stats: stats,
                            amountSuffix:
                            rawItems.isNotEmpty ? rawItems.first.currency : 'UAH',
                          ),
                          const SizedBox(height: 14),
                          _StateCard(
                            icon: Icons.inbox_outlined,
                            title: _isIncomingTab
                                ? 'Немає вхідних заявок'
                                : 'Немає моїх заявок за обраними фільтрами',
                            subtitle: _isIncomingTab
                                ? 'Зараз немає заявок, які очікують вашого рішення.'
                                : 'Спробуйте змінити період, статус або контрагента.',
                          ),
                        ],
                      ),
                    );
                  }

                  final grouped = _groupByDay(items);
                  final currency = items.first.currency;

                  return RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                      children: [
                        _StatsRow(
                          stats: stats,
                          amountSuffix: currency,
                        ),
                        const SizedBox(height: 14),
                        ...grouped.entries.map((entry) {
                          final groupItems = entry.value;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionLabel(
                                  title: entry.key,
                                  count: groupItems.length,
                                ),
                                const SizedBox(height: 8),
                                ...groupItems.map(
                                      (r) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: PaymentRequestCard(
                                      r: r,
                                      showInlineActions: _isIncomingTab &&
                                          (r.status == PaymentRequestStatus.pending ||
                                              r.status ==
                                                  PaymentRequestStatus
                                                      .approvedByDepartmentHead),
                                      onApprove: () => _onChangeStatus(
                                        r,
                                        PaymentRequestStatus.approved,
                                      ),
                                      onReject: () => _onChangeStatus(
                                        r,
                                        PaymentRequestStatus.rejected,
                                      ),
                                      onTap: () => _openDetails(r),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 18,
          child: SafeArea(
            top: false,
            child: _CreateFab(
              onTap: _openCreateRequest,
              label: 'Нова заявка',
            ),
          ),
        ),
      ],
    );
  }
}

class _TabsCard extends StatelessWidget {
  const _TabsCard({
    required this.currentTab,
    required this.onIncoming,
    required this.onMine,
  });

  final _ApprovalsTab currentTab;
  final VoidCallback onIncoming;
  final VoidCallback onMine;

  static const panel = Color(0xFF0F1B2D);
  static const border = Color(0xFF2A3B52);
  static const text = Color(0xFFF3F7FB);
  static const sub = Color(0xFFB7C4D1);
  static const accent = Color(0xFF22D3EE);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              title: 'Вхідні',
              selected: currentTab == _ApprovalsTab.incoming,
              onTap: onIncoming,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _TabButton(
              title: 'Мої',
              selected: currentTab == _ApprovalsTab.mine,
              onTap: onMine,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  static const text = Color(0xFFF3F7FB);
  static const sub = Color(0xFFB7C4D1);
  static const accent = Color(0xFF22D3EE);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(color: accent.withValues(alpha: 0.30))
              : null,
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: selected ? text : sub,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.stats,
    required this.amountSuffix,
  });

  final _ListStats stats;
  final String amountSuffix;

  static const panel = Color(0xFF0F1B2D);
  static const border = Color(0xFF2A3B52);
  static const text = Color(0xFFF3F7FB);
  static const sub = Color(0xFFB7C4D1);

  @override
  Widget build(BuildContext context) {
    final amountText = '${stats.amountLabel} $amountSuffix';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCell(
              label: 'Усього',
              value: stats.total.toString(),
              icon: Icons.layers_outlined,
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _StatCell(
              label: 'Активні',
              value: stats.pending.toString(),
              icon: Icons.schedule_rounded,
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _StatCell(
              label: 'Сума',
              value: amountText,
              icon: Icons.payments_outlined,
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.icon,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool alignEnd;

  static const text = Color(0xFFF3F7FB);
  static const sub = Color(0xFFB7C4D1);
  static const accent = Color(0xFF22D3EE);

  @override
  Widget build(BuildContext context) {
    final cross = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: cross,
      children: [
        Row(
          mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: accent),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: sub,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: text,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFF2A3B52),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    required this.count,
  });

  final String title;
  final int count;

  static const sub = Color(0xFFB7C4D1);
  static const text = Color(0xFFF3F7FB);
  static const border = Color(0xFF2A3B52);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: text,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: sub,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  static const panel = Color(0xFF16243C);
  static const border = Color(0xFF2A3B52);
  static const text = Color(0xFFF3F7FB);
  static const sub = Color(0xFFB7C4D1);
  static const accent = Color(0xFF22D3EE);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        color: panel.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.24)),
            ),
            child: Icon(icon, color: accent, size: 34),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: sub,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: const [
        _SkeletonBox(height: 62),
        SizedBox(height: 14),
        _SkeletonBox(height: 132),
        SizedBox(height: 10),
        _SkeletonBox(height: 132),
        SizedBox(height: 10),
        _SkeletonBox(height: 132),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF16243C).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A3B52)),
      ),
    );
  }
}

class _CreateFab extends StatelessWidget {
  const _CreateFab({
    required this.onTap,
    required this.label,
  });

  final VoidCallback onTap;
  final String label;

  static const accent = Color(0xFF22D3EE);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListStats {
  final int total;
  final int pending;
  final String amountLabel;

  const _ListStats({
    required this.total,
    required this.pending,
    required this.amountLabel,
  });
}

class _FilterPill2L extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? tooltip;
  final Color? accent;
  final VoidCallback onTap;

  const _FilterPill2L({
    required this.icon,
    required this.title,
    required this.value,
    this.tooltip,
    this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF16243C);
    const border = Color(0xFF2A3B52);
    const text = Color(0xFFF3F7FB);
    const sub = Color(0xFFB7C4D1);

    final a = accent;

    final content = InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: a == null
              ? const []
              : [
            BoxShadow(
              color: a.withValues(alpha: 0.16),
              blurRadius: 14,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: a ?? sub),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: sub,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.expand_more_rounded, color: sub, size: 18),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: text,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (tooltip == null) return content;
    return Tooltip(message: tooltip!, child: content);
  }
}

class _IconPill extends StatelessWidget {
  final IconData icon;
  final Color? accent;
  final VoidCallback? onTap;

  const _IconPill({
    required this.icon,
    this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF16243C);
    const border = Color(0xFF2A3B52);
    const sub = Color(0xFFB7C4D1);

    final a = accent;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: a == null
              ? const []
              : [
            BoxShadow(
              color: a.withValues(alpha: 0.16),
              blurRadius: 14,
            ),
          ],
        ),
        child: Icon(icon, color: a ?? sub),
      ),
    );
  }
}

class _BottomSheetCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _BottomSheetCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    const panel = Color(0xFF16243C);
    const border = Color(0xFF2A3B52);
    const text = Color(0xFFF3F7FB);

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: panel.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusPickTile extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatusPickTile({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const panel = Color(0xFF0F1B2D);
    const border = Color(0xFF2A3B52);
    const text = Color(0xFFF3F7FB);
    const sub = Color(0xFFB7C4D1);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: panel.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.65) : border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? color : sub,
              ),
            ],
          ),
        ),
      ),
    );
  }
}