import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mova_intelligence_app/api/auth_provider.dart';
import 'package:mova_intelligence_app/features/auth/session_store.dart';
import '../approvals_service.dart';
import '../domain/payment_request.dart';
import 'new_request_page.dart';
import 'payment_request_details_page.dart';
import 'widgets/payment_request_card.dart';

enum _ApprovalsTab { incoming, mine }

class PaymentRequestsListPage extends StatefulWidget {
  const PaymentRequestsListPage({super.key});

  @override
  State<PaymentRequestsListPage> createState() =>
      _PaymentRequestsListPageState();
}

class _PaymentRequestsListPageState extends State<PaymentRequestsListPage> {
  DateTimeRange? _range;
  PaymentRequestStatus? _statusFilter;
  String _contractorQuery = '';
  String? _orgCodeFilter;
  List<OrgAccess> _orgs = const [];

  late Future<List<PaymentRequest>> _future;

  final Set<String> _hiddenIds = <String>{};
  final TextEditingController _contractorCtrl = TextEditingController();

  _ApprovalsTab _tab = _ApprovalsTab.mine;
  String? _lastAppliedRouteSignature;

  static const bg = Color(0xFFF4F6F8);
  static const panel = Colors.white;
  static const panelSoft = Color(0xFFF2F5F7);
  static const border = Color(0xFFD9E1E7);

  static const text = Color(0xFF1E252D);
  static const sub = Color(0xFF4B5563);
  static const muted = Color(0xFF7B8794);

  static const accent = Color(0xFF2F9E97);

  @override
  void initState() {
    super.initState();
    _future = Future.value(const <PaymentRequest>[]);

    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyRouteParamsAndReload();
    });
    _loadOrgs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final uri = GoRouterState.of(context).uri;
    final sig = uri.toString();

    if (_lastAppliedRouteSignature == sig) return;
    _lastAppliedRouteSignature = sig;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyRouteParamsAndReload();
    });
  }

  @override
  void dispose() {
    _contractorCtrl.dispose();
    super.dispose();
  }

  bool get _hasAnyFilter =>
      _range != null ||
      _statusFilter != null ||
      (_orgCodeFilter?.trim().isNotEmpty ?? false) ||
      _contractorQuery.trim().isNotEmpty;

  bool get _isIncomingTab => _tab == _ApprovalsTab.incoming;

  String get _periodShort {
    if (_range == null) return 'Увесь';

    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

    final s = _range!.start;
    final e = _range!.end;

    if (s.year == e.year && s.month == e.month && s.day == e.day) {
      return fmt(s);
    }

    return '${fmt(s)}–${fmt(e)}';
  }

  String get _statusShort =>
      _statusFilter == null ? 'Усі' : paymentStatusHuman(_statusFilter!);

  String get _contractorShort =>
      _contractorQuery.trim().isEmpty ? 'Усі' : _contractorQuery.trim();

  String get _orgShort {
    final code = _orgCodeFilter?.trim() ?? '';
    if (code.isEmpty) return 'Усі';

    for (final org in _orgs) {
      if (org.code.trim() == code) {
        final name = org.name.trim();
        return name.isNotEmpty ? name : code;
      }
    }

    return code;
  }

  String get _orgTooltip {
    final code = _orgCodeFilter?.trim() ?? '';
    if (code.isEmpty) return 'Усі організації';

    for (final org in _orgs) {
      if (org.code.trim() == code) {
        final name = org.name.trim();
        return name.isEmpty ? code : name;
      }
    }

    return code;
  }

  String _orgLabelForRequest(PaymentRequest r) {
    final code = r.orgCode.trim();
    if (code.isEmpty) return '';

    for (final org in _orgs) {
      if (org.code.trim() == code) {
        final name = org.name.trim();
        return name.isNotEmpty ? name : code;
      }
    }

    return code;
  }

  String get _rangeLabel {
    if (_range == null) return 'Увесь період';

    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

    return '${fmt(_range!.start)} — ${fmt(_range!.end)}';
  }

  _ApprovalsTab? _parseTabParam(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'incoming':
        return _ApprovalsTab.incoming;
      case 'mine':
        return _ApprovalsTab.mine;
      default:
        return null;
    }
  }

  PaymentRequestStatus? _parseStatusParam(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'pending':
        return PaymentRequestStatus.pending;
      case 'preliminary':
        return PaymentRequestStatus.preliminary;
      case 'approved':
        return PaymentRequestStatus.approved;
      case 'rejected':
        return PaymentRequestStatus.rejected;
      case 'draft':
        return PaymentRequestStatus.draft;
      case 'topaid':
        return PaymentRequestStatus.topaid;
      case 'paid':
        return PaymentRequestStatus.paid;
      case 'approvedbydepartmenthead':
        return PaymentRequestStatus.approvedByDepartmentHead;
      case 'approvedbyfinancedirector':
        return PaymentRequestStatus.approvedByFinanceDirector;
      default:
        return null;
    }
  }

  void _applyRouteParamsAndReload() {
    final auth = context.read<AuthProvider>();
    final canApprove = auth.canApprovePayments;

    final uri = GoRouterState.of(context).uri;
    final qp = uri.queryParameters;

    var nextTab = _parseTabParam(qp['tab']) ??
        (canApprove ? _ApprovalsTab.incoming : _ApprovalsTab.mine);

    if (nextTab == _ApprovalsTab.incoming && !canApprove) {
      nextTab = _ApprovalsTab.mine;
    }

    var nextStatus = _parseStatusParam(qp['status']);

    if (qp['tab'] == null && nextStatus == PaymentRequestStatus.topaid) {
      nextTab = _ApprovalsTab.mine;
    }

    final now = DateTime.now();
    _range ??= DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );

    setState(() {
      _tab = nextTab;
      _statusFilter = nextStatus;
    });

    _reload();
  }

  Color _statusColor(PaymentRequestStatus s) {
    switch (s) {
      case PaymentRequestStatus.preliminary:
        return const Color(0xFF0EA5E9);
      case PaymentRequestStatus.pending:
        return const Color(0xFF2F80ED);
      case PaymentRequestStatus.approvedByDepartmentHead:
        return const Color(0xFF8B5CF6);
      case PaymentRequestStatus.approvedByFinanceDirector:
        return const Color(0xFF7C3AED);
      case PaymentRequestStatus.approved:
        return const Color(0xFF22C55E);
      case PaymentRequestStatus.rejected:
        return const Color(0xFFEF4444);
      case PaymentRequestStatus.topaid:
        return const Color(0xFFA855F7);
      case PaymentRequestStatus.paid:
        return const Color(0xFF10B981);
      case PaymentRequestStatus.draft:
        return const Color(0xFF94A3B8);
    }
  }

  Color _statusBg(PaymentRequestStatus? s) {
    switch (s) {
      case PaymentRequestStatus.preliminary:
        return const Color(0xFFE0F2FE);
      case PaymentRequestStatus.pending:
        return const Color(0xFFEEF5FF);
      case PaymentRequestStatus.approvedByDepartmentHead:
        return const Color(0xFFF4F0FF);
      case PaymentRequestStatus.approvedByFinanceDirector:
        return const Color(0xFFF3EEFF);
      case PaymentRequestStatus.approved:
        return const Color(0xFFECFDF3);
      case PaymentRequestStatus.rejected:
        return const Color(0xFFFEF2F2);
      case PaymentRequestStatus.topaid:
        return const Color(0xFFFAF5FF);
      case PaymentRequestStatus.paid:
        return const Color(0xFFECFDF5);
      case PaymentRequestStatus.draft:
        return const Color(0xFFF8FAFC);
      case null:
        return Colors.white;
    }
  }

  Future<void> _loadOrgs() async {
    final session = await SessionStore.loadSession();
    if (!mounted || session == null) return;

    final filtered = session.orgs
        .where((e) => e.code.trim().isNotEmpty || e.name.trim().isNotEmpty)
        .toList();

    setState(() {
      _orgs = filtered;
    });
  }

  Future<void> _reload() async {
    final service = context.read<ApprovalsService>();
    final future = _isIncomingTab ? service.getIncomingRequests() : _loadMineLikeRequests();

    setState(() => _future = future);

    try {
      final fresh = await future;
      if (!mounted) return;
      final freshIds = fresh.map((e) => e.id).toSet();
      setState(() => _hiddenIds.removeWhere((id) => freshIds.contains(id)));
    } catch (_) {}
  }

  Future<List<PaymentRequest>> _loadMineLikeRequests() async {
    final service = context.read<ApprovalsService>();
    final my = await service.getMyRequests();
    final department = await service.getDepartmentRequests();

    final byId = <String, PaymentRequest>{};
    for (final item in [...my, ...department]) {
      byId[item.id] = item;
    }

    final result = byId.values.toList()
      ..sort((a, b) => b.requestDate.compareTo(a.requestDate));
    return result;
  }

  Future<void> _onChangeStatus(
      PaymentRequest r, PaymentRequestStatus newStatus) async {
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
    final now = DateTime.now();
    setState(() {
      _range = DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      );
      _statusFilter = null;
      _orgCodeFilter = null;
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
                color: muted,
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
          backgroundColor: panel,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              hintStyle: const TextStyle(color: sub),
              prefixIcon: const Icon(Icons.search, color: sub),
              filled: true,
              fillColor: panelSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
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

  Future<void> _pickOrg() async {
    if (_orgs.isEmpty) return;

    final picked = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _BottomSheetCard(
          title: 'Організація',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusPickTile(
                label: 'Усі',
                color: muted,
                selected: (_orgCodeFilter?.trim().isEmpty ?? true),
                onTap: () => Navigator.of(ctx).pop(null),
              ),
              const SizedBox(height: 6),
              ..._orgs.map((org) {
                final title = org.name.trim().isEmpty ? org.code : org.name;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _StatusPickTile(
                    label: title,
                    color: accent,
                    selected: _orgCodeFilter?.trim() == org.code.trim(),
                    onTap: () => Navigator.of(ctx).pop(org.code.trim()),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (picked != null || _orgCodeFilter != null) {
      setState(() => _orgCodeFilter =
          picked?.trim().isEmpty ?? true ? null : picked?.trim());
    }
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

    final orgCode = _orgCodeFilter?.trim() ?? '';
    if (orgCode.isNotEmpty) {
      items = items.where((r) => r.orgCode.trim() == orgCode).toList();
    }

    final q = _contractorQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items
          .where((r) => r.contractorName.toLowerCase().contains(q))
          .toList();
    }

    items.sort((a, b) => b.requestDate.compareTo(a.requestDate));
    return items;
  }

  Map<String, List<PaymentRequest>> _groupByDay(List<PaymentRequest> items) {
    final map = <String, List<PaymentRequest>>{};

    for (final item in items) {
      final key = _dayLabel(item.requestDate);
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

  String _fmtDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year.toString().substring(2)}';
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentRequestDetailsPage(
          uid: r.id,
          allowActions: _isIncomingTab,
        ),
      ),
    );

    if (!mounted) return;
    await _reload();
  }

  bool _isEditableStatus(PaymentRequestStatus status) {
    return status == PaymentRequestStatus.preliminary ||
        status == PaymentRequestStatus.pending;
  }

  bool _isCurrentUserAuthor(PaymentRequest r) {
    final auth = context.read<AuthProvider>();
    final currentUid = auth.currentUser?.uid.trim() ?? '';
    final requesterUid = r.requesterUid.trim();

    if (requesterUid.isEmpty) return true;

    return currentUid.isNotEmpty && currentUid == requesterUid;
  }

  Future<void> _openEdit(PaymentRequest r) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewRequestPage(
          initial: r,
          mode: RequestFormMode.edit,
        ),
      ),
    );

    if (!mounted) return;
    await _reload();
  }

  Future<void> _openCopy(PaymentRequest r) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewRequestPage(
          initial: r,
          mode: RequestFormMode.copy,
        ),
      ),
    );

    if (!mounted) return;
    await _reload();
  }

  Future<void> _showRequestMenu(PaymentRequest r) async {
    final action = await showModalBottomSheet<_RequestAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RequestActionSheet(
        title: r.contractorName.trim().isEmpty ? 'Заявка' : r.contractorName,
        canEdit: _isCurrentUserAuthor(r) && _isEditableStatus(r.status),
      ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case _RequestAction.copy:
        await _openCopy(r);
        break;
      case _RequestAction.edit:
        await _openEdit(r);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canApprove = auth.canApprovePayments;

    return Stack(
      children: [
        Container(
          color: bg,
          child: Column(
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
                        color: panel,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x140F172A),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
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
                                  accentBg: _statusBg(_statusFilter),
                                  onTap: _pickStatus,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _FilterPill2L(
                                  icon: Icons.date_range_rounded,
                                  title: 'Період',
                                  value: _periodShort,
                                  tooltip: _range == null
                                      ? 'Увесь період'
                                      : _rangeLabel,
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
                              if (_orgs.length > 1) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _FilterPill2L(
                                    icon: Icons.business_rounded,
                                    title: 'Організація',
                                    value: _orgShort,
                                    tooltip: _orgTooltip,
                                    onTap: _pickOrg,
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(width: 8),
                                _IconPill(
                                  icon: _hasAnyFilter
                                      ? Icons.filter_alt_off_rounded
                                      : Icons.filter_alt_rounded,
                                  accent: _hasAnyFilter ? accent : null,
                                  onTap: _hasAnyFilter ? _clearFilters : null,
                                ),
                              ],
                            ],
                          ),
                          if (_orgs.length > 1) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Spacer(),
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
                    if (items.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: _reload,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                          children: [
                            _StateCard(
                              icon: Icons.inbox_outlined,
                                title: _isIncomingTab
                                    ? 'Немає вхідних заявок'
                                    : 'Немає заявок за обраними фільтрами',
                                subtitle: _isIncomingTab
                                    ? 'Зараз немає заявок, які очікують вашого рішення.'
                                    : 'Спробуйте змінити період, статус, організацію або контрагента.',
                            ),
                          ],
                        ),
                      );
                    }

                    final grouped = _groupByDay(items);

                    return RefreshIndicator(
                      onRefresh: _reload,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                        children: [
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
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                 child: PaymentRequestCard(
                                   r: r,
                                   orgLabel: _orgLabelForRequest(r),
                                   currentUserUid:
                                       context.read<AuthProvider>().currentUser?.uid.trim() ?? '',
                                   operationTypeLabel:
                                       paymentOperationTypeHuman(
                                     r.operationType,
                                        ),
                                        requestDateLabel:
                                            _fmtDate(r.requestDate),
                                        showInlineActions: _isIncomingTab &&
                                            (r.status ==
                                                    PaymentRequestStatus
                                                        .pending ||
                                                r.status ==
                                                    PaymentRequestStatus
                                                        .approvedByDepartmentHead ||
                                                r.status ==
                                                    PaymentRequestStatus
                                                        .approvedByFinanceDirector),
                                        onApprove: () => _onChangeStatus(
                                          r,
                                          PaymentRequestStatus.approved,
                                        ),
                                        onReject: () => _onChangeStatus(
                                          r,
                                          PaymentRequestStatus.rejected,
                                        ),
                                        onTap: () => _openDetails(r),
                                        onLongPress: () => _showRequestMenu(r),
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

  static const panel = Colors.white;
  static const border = Color(0xFFD9E1E7);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
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
                title: 'Мої / відділ',
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

  static const sub = Color(0xFF4B5563);
  static const accent = Color(0xFF2F9E97);
  static const accentSoft = Color(0xFFE3F4F2);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFFD1ECE8) : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: selected ? accent : sub,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
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

  static const sub = Color(0xFF4B5563);
  static const text = Color(0xFF1E252D);
  static const border = Color(0xFFD9E1E7);
  static const bg = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: text,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
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

  static const panel = Colors.white;
  static const border = Color(0xFFD9E1E7);
  static const text = Color(0xFF1E252D);
  static const sub = Color(0xFF4B5563);
  static const accent = Color(0xFF2F9E97);
  static const accentSoft = Color(0xFFE3F4F2);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: accentSoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD1ECE8)),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9E1E7)),
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

  static const accent = Color(0xFF2F9E97);

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
            color: accent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x263AAFA9),
                blurRadius: 20,
                offset: Offset(0, 10),
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

enum _RequestAction { copy, edit }

class _RequestActionSheet extends StatelessWidget {
  final String title;
  final bool canEdit;

  const _RequestActionSheet({
    required this.title,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.22 : 0.08,
              ),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _RequestActionTile(
              icon: Icons.copy_rounded,
              title: 'Копіювати',
              subtitle: 'Створити нову заявку на основі цієї',
              onTap: () => Navigator.of(context).pop(_RequestAction.copy),
            ),
            const SizedBox(height: 8),
            _RequestActionTile(
              icon: Icons.edit_rounded,
              title: 'Редагувати',
              subtitle: canEdit
                  ? 'Внести зміни в поточну заявку'
                  : 'Редагування доступне лише автору для непогодженої або попередньої заявки',
              enabled: canEdit,
              onTap: () => Navigator.of(context).pop(_RequestAction.edit),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _RequestActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;
    final contentColor =
        enabled ? cs.onSurface : cs.onSurface.withValues(alpha: 0.42);
    final iconColor =
        enabled ? cs.primary : cs.onSurface.withValues(alpha: 0.34);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? onTap : null,
      child: Ink(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: contentColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color:
                          contentColor.withValues(alpha: enabled ? 0.68 : 0.52),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill2L extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? tooltip;
  final Color? accent;
  final Color? accentBg;
  final VoidCallback onTap;

  const _FilterPill2L({
    required this.icon,
    required this.title,
    required this.value,
    this.tooltip,
    this.accent,
    this.accentBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Colors.white;
    const border = Color(0xFFD9E1E7);
    const text = Color(0xFF1E252D);
    const sub = Color(0xFF4B5563);

    final a = accent;
    final abg = accentBg;

    final content = InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: a == null ? bg : (abg ?? bg),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: a == null ? border : a.withValues(alpha: 0.18)),
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
                  Icon(Icons.expand_more_rounded, color: a ?? sub, size: 18),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: a ?? text,
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
    const bg = Colors.white;
    const border = Color(0xFFD9E1E7);
    const sub = Color(0xFF4B5563);

    final a = accent;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: a == null ? bg : const Color(0xFFE3F4F2),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: a == null ? border : const Color(0xFFD1ECE8)),
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
    const panel = Colors.white;
    const border = Color(0xFFD9E1E7);
    const text = Color(0xFF1E252D);

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x140F172A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD5DEE8),
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
    const panel = Colors.white;
    const border = Color(0xFFD9E1E7);
    const text = Color(0xFF1E252D);
    const sub = Color(0xFF4B5563);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.45) : border,
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
