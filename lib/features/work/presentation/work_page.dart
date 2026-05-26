import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../api/auth_provider.dart';
import '../../auth/session_store.dart';
import '../../approvals/approvals_service.dart';
import '../../approvals/domain/payment_request.dart';
import '../../approvals/presentation/new_request_page.dart';

enum WorkTab { approvals, tasks, receiving, events, important }

class WorkPage extends StatefulWidget {
  const WorkPage({super.key});

  @override
  State<WorkPage> createState() => _WorkPageState();
}

class _WorkPageState extends State<WorkPage> {
  WorkTab _tab = WorkTab.approvals;
  String? _selectedDesktopRequestId;
  DateTimeRange? _range;
  PaymentRequestStatus? _statusFilter;
  String _contractorQuery = '';
  String? _orgCodeFilter;
  List<OrgAccess> _orgs = const [];
  String? _lastAppliedRouteSignature;
  Set<String> _incomingRequestIds = const {};
  bool _incomingOnly = false;

  late Future<List<PaymentRequest>> _future;
  final TextEditingController _contractorCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );
    _future = _loadRequests();
    _loadOrgs();
  }

  @override
  void dispose() {
    _contractorCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final uri = GoRouterState.of(context).uri;
    final signature = uri.toString();
    if (_lastAppliedRouteSignature == signature) return;
    _lastAppliedRouteSignature = signature;

    final nextStatus = _parseStatusParam(uri.queryParameters['status']);
    final resetPeriod =
        (uri.queryParameters['period'] ?? '').trim().toLowerCase() == 'all';
    final incomingOnly =
        (uri.queryParameters['scope'] ?? '').trim().toLowerCase() == 'incoming';

    if (nextStatus != _statusFilter ||
        incomingOnly != _incomingOnly ||
        (resetPeriod && _range != null)) {
      setState(() {
        _statusFilter = nextStatus;
        _incomingOnly = incomingOnly;
        if (resetPeriod) {
          _range = null;
        }
      });
    }
  }

  Future<List<PaymentRequest>> _loadRequests() async {
    final service = context.read<ApprovalsService>();

    final my = await service.getMyRequests();
    final incoming = await service.getIncomingRequests();
    final department = await service.getDepartmentRequests();
    _incomingRequestIds = incoming.map((r) => r.id).toSet();

    final byId = <String, PaymentRequest>{};

    // If the same request is present in both lists, keep the incoming copy,
    // because it reflects the current approver context.
    for (final r in [...my, ...department, ...incoming]) {
      byId[r.id] = r;
    }

    final result = byId.values.toList()
      ..sort((a, b) => b.requestDate.compareTo(a.requestDate));

    return result;
  }

  Future<void> _refresh() async {
    final future = _loadRequests();
    setState(() {
      _future = future;
    });
    await future;
  }

  bool get _hasAnyApprovalFilter {
    return _range != null ||
        _statusFilter != null ||
        (_orgCodeFilter?.trim().isNotEmpty ?? false) ||
        _contractorQuery.trim().isNotEmpty;
  }

  String get _periodShort {
    if (_range == null) return 'Увесь';

    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

    final s = _range!.start;
    final e = _range!.end;

    if (s.year == e.year && s.month == e.month && s.day == e.day) {
      return fmt(s);
    }

    return '${fmt(s)}-${fmt(e)}';
  }

  String get _rangeLabel {
    if (_range == null) return 'Увесь період';

    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

    return '${fmt(_range!.start)} - ${fmt(_range!.end)}';
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

  PaymentRequestStatus? _parseStatusParam(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'pending':
        return PaymentRequestStatus.pending;
      case 'preliminary':
        return PaymentRequestStatus.preliminary;
      case 'approved':
        return PaymentRequestStatus.approved;
      case 'approvedbydepartmenthead':
        return PaymentRequestStatus.approvedByDepartmentHead;
      case 'approvedbyfinancedirector':
        return PaymentRequestStatus.approvedByFinanceDirector;
      case 'rejected':
        return PaymentRequestStatus.rejected;
      case 'topaid':
        return PaymentRequestStatus.topaid;
      case 'paid':
        return PaymentRequestStatus.paid;
      case 'draft':
        return PaymentRequestStatus.draft;
      default:
        return null;
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

  List<PaymentRequest> _applyFilters(List<PaymentRequest> raw) {
    var items = raw.toList();

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

    if (_incomingOnly) {
      items = items.where((r) => _incomingRequestIds.contains(r.id)).toList();
    }

    if (_statusFilter != null) {
      items = items.where((r) => r.status == _statusFilter).toList();
    }

    final orgCode = _orgCodeFilter?.trim() ?? '';
    if (orgCode.isNotEmpty) {
      items = items.where((r) => r.orgCode.trim() == orgCode).toList();
    }

    final contractorQuery = _contractorQuery.trim().toLowerCase();
    if (contractorQuery.isNotEmpty) {
      items = items
          .where(
              (r) => r.contractorName.toLowerCase().contains(contractorQuery))
          .toList();
    }

    return items;
  }

  int _countImportant(List<PaymentRequest> items) {
    return items
        .where(
          (r) =>
              r.urgent ||
              r.status == PaymentRequestStatus.rejected ||
              r.status == PaymentRequestStatus.pending ||
              r.status == PaymentRequestStatus.approvedByDepartmentHead ||
              r.status == PaymentRequestStatus.approvedByFinanceDirector,
        )
        .length;
  }

  int _tabCount(WorkTab tab, List<PaymentRequest> approvals) {
    switch (tab) {
      case WorkTab.approvals:
        return approvals.length;
      case WorkTab.tasks:
        return 0;
      case WorkTab.receiving:
        return 0;
      case WorkTab.events:
        return 0;
      case WorkTab.important:
        return _countImportant(approvals);
    }
  }

  String _formatAmount(double amount, String currency) {
    final hasFraction = amount % 1 != 0;
    final formatted =
        hasFraction ? amount.toStringAsFixed(2) : amount.toStringAsFixed(0);
    return '$formatted ${currency.toUpperCase()}';
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year.toString().substring(2)}';
  }

  String _paymentFormText(PaymentForm form) {
    switch (form) {
      case PaymentForm.cash:
        return 'Готівка';
      case PaymentForm.cashless:
        return 'Безготівково';
      case PaymentForm.unknown:
        return 'Форма: —';
    }
  }

  _StatusUi _statusUi(PaymentRequestStatus status, bool isDark) {
    switch (status) {
      case PaymentRequestStatus.preliminary:
        return _StatusUi(
          color: const Color(0xFF0EA5E9),
          bg: isDark ? const Color(0xFF123044) : const Color(0xFFE0F2FE),
          border: isDark ? const Color(0xFF1F5F82) : const Color(0xFFBAE6FD),
        );
      case PaymentRequestStatus.pending:
        return _StatusUi(
          color: const Color(0xFF1976D2),
          bg: isDark ? const Color(0xFF142338) : const Color(0xFFE3F2FD),
          border: isDark ? const Color(0xFF23476D) : const Color(0xFF90CAF9),
        );
      case PaymentRequestStatus.approved:
        return _StatusUi(
          color: const Color(0xFF84CC16),
          bg: isDark ? const Color(0xFF202C10) : const Color(0xFFF7FEE7),
          border: isDark ? const Color(0xFF65A30D) : const Color(0xFFBEF264),
        );
      case PaymentRequestStatus.approvedByDepartmentHead:
        return _StatusUi(
          color: const Color(0xFF4F46E5),
          bg: isDark ? const Color(0xFF1C1E3E) : const Color(0xFFEEF2FF),
          border: isDark ? const Color(0xFF3730A3) : const Color(0xFFC7D2FE),
        );
      case PaymentRequestStatus.approvedByFinanceDirector:
        return _StatusUi(
          color: const Color(0xFF7C3AED),
          bg: isDark ? const Color(0xFF24163A) : const Color(0xFFF3EEFF),
          border: isDark ? const Color(0xFF5B21B6) : const Color(0xFFE4D5FF),
        );
      case PaymentRequestStatus.rejected:
        return _StatusUi(
          color: const Color(0xFFEF4444),
          bg: isDark ? const Color(0xFF341819) : const Color(0xFFFEF2F2),
          border: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCDDDD),
        );
      case PaymentRequestStatus.topaid:
        return _StatusUi(
          color: const Color(0xFFF59E0B),
          bg: isDark ? const Color(0xFF33210F) : const Color(0xFFFFFBEB),
          border: isDark ? const Color(0xFFB45309) : const Color(0xFFFDE68A),
        );
      case PaymentRequestStatus.paid:
        return _StatusUi(
          color: const Color(0xFF0F766E),
          bg: isDark ? const Color(0xFF0F2D2B) : const Color(0xFFF0FDFA),
          border: isDark ? const Color(0xFF14B8A6) : const Color(0xFF99F6E4),
        );
      case PaymentRequestStatus.draft:
        return _StatusUi(
          color: const Color(0xFF94A3B8),
          bg: isDark ? const Color(0xFF1A2432) : const Color(0xFFF8FAFC),
          border: isDark ? const Color(0xFF334155) : const Color(0xFFE7EDF4),
        );
    }
  }

  Color _statusColor(PaymentRequestStatus status) {
    switch (status) {
      case PaymentRequestStatus.preliminary:
        return const Color(0xFF0EA5E9);
      case PaymentRequestStatus.pending:
        return const Color(0xFF1976D2);
      case PaymentRequestStatus.approved:
        return const Color(0xFF84CC16);
      case PaymentRequestStatus.approvedByDepartmentHead:
        return const Color(0xFF4F46E5);
      case PaymentRequestStatus.approvedByFinanceDirector:
        return const Color(0xFF7C3AED);
      case PaymentRequestStatus.rejected:
        return const Color(0xFFEF4444);
      case PaymentRequestStatus.topaid:
        return const Color(0xFFF59E0B);
      case PaymentRequestStatus.paid:
        return const Color(0xFF0F766E);
      case PaymentRequestStatus.draft:
        return const Color(0xFF94A3B8);
    }
  }

  Color _statusBg(PaymentRequestStatus? status, bool isDark) {
    if (status == null) {
      return Theme.of(context).colorScheme.surface;
    }

    final color = _statusColor(status);
    return color.withValues(alpha: isDark ? 0.16 : 0.10);
  }

  void _clearApprovalFilters() {
    setState(() {
      _range = null;
      _statusFilter = null;
      _orgCodeFilter = null;
      _contractorQuery = '';
      _contractorCtrl.text = '';
    });
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
      firstDate: DateTime(now.year - 2),
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

    if (picked != null && mounted) {
      setState(() => _range = picked);
    }
  }

  Future<void> _pickStatus() async {
    final picked = await showModalBottomSheet<PaymentRequestStatus?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final maxHeight = MediaQuery.of(ctx).size.height * 0.82;
        return _FilterSheet(
          title: 'Статус заявки',
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StatusPickTile(
                    label: 'Усі статуси',
                    color: Theme.of(context).colorScheme.onSurface,
                    selected: _statusFilter == null,
                    onTap: () => Navigator.of(ctx).pop(null),
                  ),
                  const SizedBox(height: 8),
                  ...PaymentRequestStatus.values
                      .where((status) => status != PaymentRequestStatus.draft)
                      .map((status) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _StatusPickTile(
                        label: paymentStatusHuman(status),
                        color: _statusColor(status),
                        selected: _statusFilter == status,
                        onTap: () => Navigator.of(ctx).pop(status),
                      ),
                    );
                  }),
                ],
              ),
            ),
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
        final theme = Theme.of(context);
        final cs = theme.colorScheme;

        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Контрагент',
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: TextField(
            controller: _contractorCtrl,
            autofocus: true,
            style: TextStyle(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Введіть частину назви',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
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
        return _FilterSheet(
          title: 'Організація',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusPickTile(
                label: 'Усі',
                color: Theme.of(context).colorScheme.onSurface,
                selected: (_orgCodeFilter?.trim().isEmpty ?? true),
                onTap: () => Navigator.of(ctx).pop(null),
              ),
              const SizedBox(height: 8),
              ..._orgs.map((org) {
                final title = org.name.trim().isEmpty ? org.code : org.name;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _StatusPickTile(
                    label: title,
                    color: Theme.of(context).colorScheme.primary,
                    selected: _orgCodeFilter?.trim() == org.code.trim(),
                    onTap: () => Navigator.of(ctx).pop(org.code.trim()),
                  ),
                );
              }),
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

  Future<void> _openSectionPicker(List<PaymentRequest> approvals) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;

    final selected = await showModalBottomSheet<WorkTab>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final items = [
          (WorkTab.approvals, 'Заявки'),
          (WorkTab.tasks, 'Задачі'),
          (WorkTab.receiving, 'Приймання'),
          (WorkTab.events, 'Події'),
          (WorkTab.important, 'Важливе'),
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Розділ роботи',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...items.map((item) {
                  final count = _tabCount(item.$1, approvals);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).pop(item.$1),
                      child: Ink(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: _tab == item.$1
                              ? cs.primary.withValues(alpha: 0.10)
                              : cs.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _tab == item.$1
                                ? cs.primary.withValues(alpha: 0.25)
                                : border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.$2,
                                style: TextStyle(
                                  color: _tab == item.$1
                                      ? cs.primary
                                      : cs.onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (count > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _tab == item.$1
                                      ? cs.primary.withValues(alpha: 0.14)
                                      : cs.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    color: cs.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _tab = selected;
      });
    }
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
    await _refresh();
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
    await _refresh();
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;
    final isDark = theme.brightness == Brightness.dark;

    return FutureBuilder<List<PaymentRequest>>(
      future: _future,
      builder: (context, snap) {
        final allApprovals = snap.data ?? const <PaymentRequest>[];
        final approvals = _applyFilters(allApprovals);
        final isDesktop = MediaQuery.sizeOf(context).width >= 1100;

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: _tab == WorkTab.approvals && !isDesktop
              ? FloatingActionButton(
                  onPressed: () => context.pushNamed('newPaymentRequest'),
                  child: const Icon(Icons.add_rounded),
                )
              : null,
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: isDesktop
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                    children: [
                      _DesktopWorkShell(
                        tab: _tab,
                        tabLabel: _tabLabel(_tab),
                        allCount: _tabCount(_tab, allApprovals),
                        approvals: approvals,
                        selectedRequestId: _selectedDesktopRequestId,
                        orgLabelForRequest: _orgLabelForRequest,
                        amountFormatter: _formatAmount,
                        dateFormatter: _formatDate,
                        paymentFormFormatter: _paymentFormText,
                        statusUiBuilder: (status) => _statusUi(status, isDark),
                        incomingRequestIds: _incomingRequestIds,
                        isLoading:
                            snap.connectionState != ConnectionState.done &&
                                !snap.hasData,
                        error: snap.error,
                        onCreate: () => context.pushNamed('newPaymentRequest'),
                        onRefresh: _refresh,
                        onSelectTab: (tab) => setState(() => _tab = tab),
                        onSelectRequest: (request) => setState(
                          () => _selectedDesktopRequestId = request.id,
                        ),
                        onOpenRequest: (request) async {
                          await context.pushNamed(
                            'approvalRequestDetails',
                            pathParameters: {'uid': request.id},
                            queryParameters: {
                              if (_incomingRequestIds.contains(request.id))
                                'actions': '1',
                            },
                          );
                          if (!mounted) return;
                          await _refresh();
                        },
                        onCopyRequest: _openCopy,
                        onEditRequest: _openEdit,
                        canEditRequest: (request) =>
                            _isCurrentUserAuthor(request) &&
                            _isEditableStatus(request.status),
                        onStatus: _pickStatus,
                        onPeriod: _pickRange,
                        onOrg: _pickOrg,
                        onContractor: _pickContractor,
                        onClearFilters: _clearApprovalFilters,
                        status: _statusShort,
                        period: _periodShort,
                        org: _orgShort,
                        contractor: _contractorShort,
                        showOrgFilter: _orgs.length > 1,
                        hasFilters: _hasAnyApprovalFilter,
                        border: border,
                        isDark: isDark,
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    children: [
                      _SectionSelector(
                        title: _tabLabel(_tab),
                        count: _tabCount(_tab, allApprovals),
                        onTap: () => _openSectionPicker(allApprovals),
                      ),
                      const SizedBox(height: 10),
                      if (_tab == WorkTab.approvals) ...[
                        _ApprovalFiltersPanel(
                          status: _statusShort,
                          period: _periodShort,
                          org: _orgShort,
                          contractor: _contractorShort,
                          orgTooltip: _orgTooltip,
                          periodTooltip: _rangeLabel,
                          statusAccent: _statusFilter == null
                              ? null
                              : _statusColor(_statusFilter!),
                          statusBg: _statusBg(_statusFilter, isDark),
                          hasFilters: _hasAnyApprovalFilter,
                          showOrgFilter: _orgs.length > 1,
                          onStatus: _pickStatus,
                          onPeriod: _pickRange,
                          onOrg: _pickOrg,
                          onContractor: _pickContractor,
                          onClear: _clearApprovalFilters,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _buildBody(
                        cs: cs,
                        border: border,
                        isDark: isDark,
                        snapshot: snap,
                        approvals: approvals,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  String _tabLabel(WorkTab tab) {
    switch (tab) {
      case WorkTab.approvals:
        return 'Заявки';
      case WorkTab.tasks:
        return 'Задачі';
      case WorkTab.receiving:
        return 'Приймання';
      case WorkTab.events:
        return 'Події';
      case WorkTab.important:
        return 'Важливе';
    }
  }

  Widget _buildBody({
    required ColorScheme cs,
    required Color border,
    required bool isDark,
    required AsyncSnapshot<List<PaymentRequest>> snapshot,
    required List<PaymentRequest> approvals,
  }) {
    if (_tab != WorkTab.approvals) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          'Скоро буде',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.78),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (snapshot.hasError) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded, color: cs.primary, size: 30),
            const SizedBox(height: 10),
            Text(
              'Не вдалося завантажити список',
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${snapshot.error}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.7),
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Спробувати ще раз'),
            ),
          ],
        ),
      );
    }

    if (approvals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              color: cs.onSurface.withValues(alpha: 0.55),
              size: 30,
            ),
            const SizedBox(height: 10),
            Text(
              'Нічого не знайдено',
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'За поточним фільтром немає заявок.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.7),
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: approvals
          .map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ApprovalCard(
                contractor: r.contractorName.trim().isEmpty
                    ? '—'
                    : r.contractorName.trim(),
                org: _orgLabelForRequest(r),
                requesterName: r.requesterName?.trim() ?? '',
                subdivisionName: r.subdivisionName.trim(),
                showRequesterMeta: !_isCurrentUserAuthor(r),
                operationType: paymentOperationTypeHuman(r.operationType),
                requestDate: _formatDate(r.requestDate),
                purpose: r.purpose.trim(),
                amount: _formatAmount(r.amount, r.currency),
                date: _formatDate(r.date),
                paymentForm: _paymentFormText(r.paymentForm),
                statusText: paymentStatusHuman(r.status),
                statusUi: _statusUi(r.status, isDark),
                border: border,
                isDark: isDark,
                onLongPress: () => _showRequestMenu(r),
                onTap: () async {
                  await context.pushNamed(
                    'approvalRequestDetails',
                    pathParameters: {'uid': r.id},
                    queryParameters: {
                      if (_incomingRequestIds.contains(r.id)) 'actions': '1',
                    },
                  );
                  if (!mounted) return;
                  await _refresh();
                },
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DesktopWorkShell extends StatelessWidget {
  const _DesktopWorkShell({
    required this.tab,
    required this.tabLabel,
    required this.allCount,
    required this.approvals,
    required this.selectedRequestId,
    required this.orgLabelForRequest,
    required this.amountFormatter,
    required this.dateFormatter,
    required this.paymentFormFormatter,
    required this.statusUiBuilder,
    required this.incomingRequestIds,
    required this.isLoading,
    required this.error,
    required this.onCreate,
    required this.onRefresh,
    required this.onSelectTab,
    required this.onSelectRequest,
    required this.onOpenRequest,
    required this.onCopyRequest,
    required this.onEditRequest,
    required this.canEditRequest,
    required this.onStatus,
    required this.onPeriod,
    required this.onOrg,
    required this.onContractor,
    required this.onClearFilters,
    required this.status,
    required this.period,
    required this.org,
    required this.contractor,
    required this.showOrgFilter,
    required this.hasFilters,
    required this.border,
    required this.isDark,
  });

  final WorkTab tab;
  final String tabLabel;
  final int allCount;
  final List<PaymentRequest> approvals;
  final String? selectedRequestId;
  final String Function(PaymentRequest request) orgLabelForRequest;
  final String Function(double amount, String currency) amountFormatter;
  final String Function(DateTime date) dateFormatter;
  final String Function(PaymentForm form) paymentFormFormatter;
  final _StatusUi Function(PaymentRequestStatus status) statusUiBuilder;
  final Set<String> incomingRequestIds;
  final bool isLoading;
  final Object? error;
  final VoidCallback onCreate;
  final Future<void> Function() onRefresh;
  final ValueChanged<WorkTab> onSelectTab;
  final ValueChanged<PaymentRequest> onSelectRequest;
  final ValueChanged<PaymentRequest> onOpenRequest;
  final ValueChanged<PaymentRequest> onCopyRequest;
  final ValueChanged<PaymentRequest> onEditRequest;
  final bool Function(PaymentRequest request) canEditRequest;
  final VoidCallback onStatus;
  final VoidCallback onPeriod;
  final VoidCallback onOrg;
  final VoidCallback onContractor;
  final VoidCallback onClearFilters;
  final String status;
  final String period;
  final String org;
  final String contractor;
  final bool showOrgFilter;
  final bool hasFilters;
  final Color border;
  final bool isDark;

  static const _accent = Color(0xFF2F9E97);
  static const _amber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final selected = approvals
            .where((request) => request.id == selectedRequestId)
            .cast<PaymentRequest?>()
            .firstOrNull ??
        (approvals.isNotEmpty ? approvals.first : null);

    final waitingCount = incomingRequestIds.length;
    final toPayCount = approvals
        .where((request) => request.status == PaymentRequestStatus.topaid)
        .length;
    final rejectedCount = approvals
        .where((request) => request.status == PaymentRequestStatus.rejected)
        .length;
    final totalAmount = approvals.fold<double>(
      0,
      (sum, request) => sum + request.amount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DesktopHeroBar(
          activeTab: tab,
          title: tabLabel,
          count: allCount,
          onSelectTab: onSelectTab,
          onCreate: onCreate,
          onRefresh: onRefresh,
        ),
        const SizedBox(height: 14),
        if (tab == WorkTab.approvals) ...[
          _DesktopKpiStrip(
            items: [
              _DesktopKpiData(
                icon: Icons.pending_actions_rounded,
                label: 'Очікують рішення',
                value: '$waitingCount',
                color: _amber,
              ),
              _DesktopKpiData(
                icon: Icons.payments_rounded,
                label: 'До оплати',
                value: '$toPayCount',
                color: const Color(0xFF0F766E),
              ),
              _DesktopKpiData(
                icon: Icons.block_rounded,
                label: 'Відхилено',
                value: '$rejectedCount',
                color: const Color(0xFFEF4444),
              ),
              _DesktopKpiData(
                icon: Icons.analytics_rounded,
                label: 'Сума у вибірці',
                value: amountFormatter(totalAmount, 'UAH'),
                color: _accent,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DesktopFilterBar(
            status: status,
            period: period,
            org: org,
            contractor: contractor,
            showOrgFilter: showOrgFilter,
            hasFilters: hasFilters,
            onStatus: onStatus,
            onPeriod: onPeriod,
            onOrg: onOrg,
            onContractor: onContractor,
            onClear: onClearFilters,
          ),
          const SizedBox(height: 14),
        ],
        if (tab != WorkTab.approvals)
          _DesktopEmptyPanel(
            icon: Icons.construction_rounded,
            title: 'Розділ ще готується',
            subtitle:
                'Заявки вже отримали web-режим. Наступними можна так само розкласти задачі, події та приймання.',
            border: border,
          )
        else if (isLoading)
          _DesktopEmptyPanel(
            icon: Icons.sync_rounded,
            title: 'Завантажуємо заявки',
            subtitle: 'Підтягуємо список із 1С та готуємо таблицю.',
            border: border,
          )
        else if (error != null)
          _DesktopEmptyPanel(
            icon: Icons.error_outline_rounded,
            title: 'Не вдалося завантажити список',
            subtitle: '$error',
            border: border,
            action: FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Спробувати ще раз'),
            ),
          )
        else if (approvals.isEmpty)
          _DesktopEmptyPanel(
            icon: Icons.inbox_outlined,
            title: 'Нічого не знайдено',
            subtitle: 'За поточними фільтрами немає заявок.',
            border: border,
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 1180,
                    child: _DesktopApprovalsTable(
                      approvals: approvals,
                      selectedId: selected?.id,
                      incomingRequestIds: incomingRequestIds,
                      border: border,
                      isDark: isDark,
                      orgLabelForRequest: orgLabelForRequest,
                      amountFormatter: amountFormatter,
                      dateFormatter: dateFormatter,
                      paymentFormFormatter: paymentFormFormatter,
                      statusUiBuilder: statusUiBuilder,
                      onSelectRequest: onSelectRequest,
                      onOpenRequest: onOpenRequest,
                      onCopyRequest: onCopyRequest,
                      onEditRequest: onEditRequest,
                      canEditRequest: canEditRequest,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 360,
                child: _DesktopRequestDetailsPanel(
                  request: selected!,
                  border: border,
                  isDark: isDark,
                  orgLabel: orgLabelForRequest(selected),
                  amount: amountFormatter(selected.amount, selected.currency),
                  date: dateFormatter(selected.date),
                  requestDate: dateFormatter(selected.requestDate),
                  paymentForm: paymentFormFormatter(selected.paymentForm),
                  statusUi: statusUiBuilder(selected.status),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _DesktopHeroBar extends StatelessWidget {
  const _DesktopHeroBar({
    required this.activeTab,
    required this.title,
    required this.count,
    required this.onSelectTab,
    required this.onCreate,
    required this.onRefresh,
  });

  final WorkTab activeTab;
  final String title;
  final int count;
  final ValueChanged<WorkTab> onSelectTab;
  final VoidCallback onCreate;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MOVA Intelligence',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.62),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _DesktopCountBadge(count: count),
                  ],
                ),
              ],
            ),
          ),
          _DesktopTabs(active: activeTab, onSelect: onSelectTab),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            tooltip: 'Оновити',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Нова заявка'),
          ),
        ],
      ),
    );
  }
}

class _DesktopTabs extends StatelessWidget {
  const _DesktopTabs({
    required this.active,
    required this.onSelect,
  });

  final WorkTab active;
  final ValueChanged<WorkTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      (WorkTab.approvals, 'Заявки', Icons.fact_check_rounded),
      (WorkTab.tasks, 'Задачі', Icons.task_alt_rounded),
      (WorkTab.receiving, 'Приймання', Icons.inventory_2_rounded),
      (WorkTab.events, 'Події', Icons.notifications_none_rounded),
      (WorkTab.important, 'Важливе', Icons.priority_high_rounded),
    ];

    return Row(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: _DesktopTabButton(
            selected: active == item.$1,
            label: item.$2,
            icon: item.$3,
            onTap: () => onSelect(item.$1),
          ),
        );
      }).toList(),
    );
  }
}

class _DesktopTabButton extends StatelessWidget {
  const _DesktopTabButton({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withValues(alpha: 0.10) : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.22)
                : cs.outlineVariant.withValues(alpha: 0.0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color:
                  selected ? cs.primary : cs.onSurface.withValues(alpha: 0.62),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.70),
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopKpiData {
  const _DesktopKpiData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _DesktopKpiStrip extends StatelessWidget {
  const _DesktopKpiStrip({required this.items});

  final List<_DesktopKpiData> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: item == items.last ? 0 : 10,
                ),
                child: _DesktopKpiCard(item: item),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DesktopKpiCard extends StatelessWidget {
  const _DesktopKpiCard({required this.item});

  final _DesktopKpiData item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: item.color.withValues(alpha: 0.18)),
            ),
            child: Icon(item.icon, color: item.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.62),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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

class _DesktopFilterBar extends StatelessWidget {
  const _DesktopFilterBar({
    required this.status,
    required this.period,
    required this.org,
    required this.contractor,
    required this.showOrgFilter,
    required this.hasFilters,
    required this.onStatus,
    required this.onPeriod,
    required this.onOrg,
    required this.onContractor,
    required this.onClear,
  });

  final String status;
  final String period;
  final String org;
  final String contractor;
  final bool showOrgFilter;
  final bool hasFilters;
  final VoidCallback onStatus;
  final VoidCallback onPeriod;
  final VoidCallback onOrg;
  final VoidCallback onContractor;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _DesktopSearchChip(
              icon: Icons.search_rounded,
              label: 'Контрагент',
              value: contractor,
              onTap: onContractor,
            ),
          ),
          const SizedBox(width: 8),
          _DesktopSearchChip(
            icon: Icons.tune_rounded,
            label: 'Статус',
            value: status,
            onTap: onStatus,
          ),
          const SizedBox(width: 8),
          _DesktopSearchChip(
            icon: Icons.date_range_rounded,
            label: 'Період',
            value: period,
            onTap: onPeriod,
          ),
          if (showOrgFilter) ...[
            const SizedBox(width: 8),
            Expanded(
              child: _DesktopSearchChip(
                icon: Icons.business_rounded,
                label: 'Організація',
                value: org,
                onTap: onOrg,
              ),
            ),
          ],
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: 'Очистити фільтри',
            onPressed: hasFilters ? onClear : null,
            icon: const Icon(Icons.filter_alt_off_rounded),
          ),
        ],
      ),
    );
  }
}

class _DesktopSearchChip extends StatelessWidget {
  const _DesktopSearchChip({
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
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Ink(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            Icon(icon, color: cs.onSurface.withValues(alpha: 0.58), size: 18),
            const SizedBox(width: 8),
            Text(
              '$label:',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.54),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              color: cs.onSurface.withValues(alpha: 0.50),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopApprovalsTable extends StatelessWidget {
  const _DesktopApprovalsTable({
    required this.approvals,
    required this.selectedId,
    required this.incomingRequestIds,
    required this.border,
    required this.isDark,
    required this.orgLabelForRequest,
    required this.amountFormatter,
    required this.dateFormatter,
    required this.paymentFormFormatter,
    required this.statusUiBuilder,
    required this.onSelectRequest,
    required this.onOpenRequest,
    required this.onCopyRequest,
    required this.onEditRequest,
    required this.canEditRequest,
  });

  final List<PaymentRequest> approvals;
  final String? selectedId;
  final Set<String> incomingRequestIds;
  final Color border;
  final bool isDark;
  final String Function(PaymentRequest request) orgLabelForRequest;
  final String Function(double amount, String currency) amountFormatter;
  final String Function(DateTime date) dateFormatter;
  final String Function(PaymentForm form) paymentFormFormatter;
  final _StatusUi Function(PaymentRequestStatus status) statusUiBuilder;
  final ValueChanged<PaymentRequest> onSelectRequest;
  final ValueChanged<PaymentRequest> onOpenRequest;
  final ValueChanged<PaymentRequest> onCopyRequest;
  final ValueChanged<PaymentRequest> onEditRequest;
  final bool Function(PaymentRequest request) canEditRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 42,
            color: cs.surfaceContainerHighest.withValues(alpha: 0.30),
            child: const Row(
              children: [
                _DesktopTableHeader(flex: 4, text: 'Організація'),
                _DesktopTableHeader(flex: 3, text: 'Контрагент'),
                _DesktopTableHeader(width: 112, text: 'ЄДРПОУ'),
                _DesktopTableHeader(width: 126, text: 'Сума'),
                _DesktopTableHeader(width: 114, text: 'Форма'),
                _DesktopTableHeader(width: 152, text: 'Статус'),
                _DesktopTableHeader(width: 126, text: 'Дата'),
                _DesktopTableHeader(width: 132, text: 'Дії'),
              ],
            ),
          ),
          ...approvals.take(80).map((request) {
            final statusUi = statusUiBuilder(request.status);
            final selected = request.id == selectedId;

            return _DesktopApprovalRow(
              request: request,
              selected: selected,
              statusUi: statusUi,
              org: orgLabelForRequest(request),
              amount: amountFormatter(request.amount, request.currency),
              date: dateFormatter(request.requestDate),
              paymentForm: paymentFormFormatter(request.paymentForm),
              canAct: incomingRequestIds.contains(request.id),
              canEdit: canEditRequest(request),
              onTap: () => onSelectRequest(request),
              onOpen: () => onOpenRequest(request),
              onCopy: () => onCopyRequest(request),
              onEdit: () => onEditRequest(request),
            );
          }),
        ],
      ),
    );
  }
}

class _DesktopTableHeader extends StatelessWidget {
  const _DesktopTableHeader({
    required this.text,
    this.width,
    this.flex,
  });

  final String text;
  final double? width;
  final int? flex;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.62),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );

    if (width != null) return SizedBox(width: width, child: child);
    return Expanded(flex: flex ?? 1, child: child);
  }
}

class _DesktopApprovalRow extends StatelessWidget {
  const _DesktopApprovalRow({
    required this.request,
    required this.selected,
    required this.statusUi,
    required this.org,
    required this.amount,
    required this.date,
    required this.paymentForm,
    required this.canAct,
    required this.canEdit,
    required this.onTap,
    required this.onOpen,
    required this.onCopy,
    required this.onEdit,
  });

  final PaymentRequest request;
  final bool selected;
  final _StatusUi statusUi;
  final String org;
  final String amount;
  final String date;
  final String paymentForm;
  final bool canAct;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color:
          selected ? cs.primary.withValues(alpha: 0.075) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onOpen,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.65),
              ),
              left: BorderSide(
                color: selected ? cs.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              _DesktopTableCell(
                flex: 4,
                text: org.trim().isEmpty ? request.orgCode : org,
                maxLines: 2,
              ),
              _DesktopTableCell(
                flex: 3,
                text: request.contractorName.trim().isEmpty
                    ? '—'
                    : request.contractorName.trim(),
                strong: true,
                maxLines: 2,
              ),
              _DesktopTableCell(
                width: 112,
                text: request.contractorCode.trim().isEmpty
                    ? '—'
                    : request.contractorCode.trim(),
              ),
              _DesktopTableCell(width: 126, text: amount, strong: true),
              _DesktopTableCell(width: 114, text: paymentForm),
              SizedBox(
                width: 152,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _DesktopStatusPill(
                    text: paymentStatusHuman(request.status),
                    statusUi: statusUi,
                  ),
                ),
              ),
              _DesktopTableCell(width: 126, text: date),
              SizedBox(
                width: 132,
                child: Align(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DesktopActionIconButton(
                        tooltip: canAct ? 'Відкрити з діями' : 'Відкрити',
                        icon: canAct
                            ? Icons.rate_review_rounded
                            : Icons.open_in_new_rounded,
                        onPressed: onOpen,
                      ),
                      _DesktopActionIconButton(
                        tooltip: 'Копіювати',
                        icon: Icons.copy_rounded,
                        onPressed: onCopy,
                      ),
                      _DesktopActionIconButton(
                        tooltip:
                            canEdit ? 'Редагувати' : 'Редагування недоступне',
                        icon: Icons.edit_rounded,
                        onPressed: canEdit ? onEdit : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopTableCell extends StatelessWidget {
  const _DesktopTableCell({
    required this.text,
    this.width,
    this.flex,
    this.strong = false,
    this.maxLines = 1,
  });

  final String text;
  final double? width;
  final int? flex;
  final bool strong;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: strong ? cs.onSurface : cs.onSurface.withValues(alpha: 0.72),
            fontSize: 12.5,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ),
    );

    if (width != null) return SizedBox(width: width, child: child);
    return Expanded(flex: flex ?? 1, child: child);
  }
}

class _DesktopActionIconButton extends StatelessWidget {
  const _DesktopActionIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        padding: EdgeInsets.zero,
        iconSize: 18,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

class _DesktopRequestDetailsPanel extends StatelessWidget {
  const _DesktopRequestDetailsPanel({
    required this.request,
    required this.border,
    required this.isDark,
    required this.orgLabel,
    required this.amount,
    required this.date,
    required this.requestDate,
    required this.paymentForm,
    required this.statusUi,
  });

  final PaymentRequest request;
  final Color border;
  final bool isDark;
  final String orgLabel;
  final String amount;
  final String date;
  final String requestDate;
  final String paymentForm;
  final _StatusUi statusUi;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.contractorName.trim().isEmpty
                      ? 'Заявка'
                      : request.contractorName.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _DesktopStatusPill(
                text: paymentStatusHuman(request.status),
                statusUi: statusUi,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            amount,
            style: TextStyle(
              color: cs.primary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            paymentOperationTypeHuman(request.operationType),
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.62),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _DesktopDetailGrid(
            items: [
              (
                'Організація',
                orgLabel.trim().isEmpty ? request.orgCode : orgLabel
              ),
              (
                'ЄДРПОУ',
                request.contractorCode.trim().isEmpty
                    ? '—'
                    : request.contractorCode
              ),
              ('Форма', paymentForm),
              ('Дата оплати', date),
              ('Створено', requestDate),
              (
                'Заявник',
                request.requesterName?.trim().isEmpty ?? true
                    ? '—'
                    : request.requesterName!.trim()
              ),
            ],
          ),
          if (request.purpose.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            _DesktopPanelSection(
              title: 'Призначення',
              child: Text(
                request.purpose.trim(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.78),
                  fontSize: 12.8,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _DesktopPanelSection(
            title: 'Маршрут погодження',
            child: Column(
              children: _approvalRouteFor(request)
                  .map((step) => _RouteStep(
                        label: step.$1,
                        done: step.$2,
                        active: step.$3,
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          _DesktopPanelSection(
            title: 'Вкладення',
            trailing: '${request.attachments.length}',
            child: request.attachments.isEmpty
                ? Text(
                    'Файли ще не додані',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.58),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Column(
                    children: request.attachments
                        .take(3)
                        .map(
                          (attachment) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.attach_file_rounded,
                                  color: cs.primary,
                                  size: 17,
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    attachment.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: cs.onSurface,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  List<(String, bool, bool)> _approvalRouteFor(PaymentRequest request) {
    final status = request.status;
    final amount = request.amount;
    final needsCfo = amount > 20000;
    final needsOwner = amount > 100000;

    return [
      (
        'Керівник підрозділу',
        status == PaymentRequestStatus.approvedByDepartmentHead ||
            status == PaymentRequestStatus.approvedByFinanceDirector ||
            status == PaymentRequestStatus.approved ||
            status == PaymentRequestStatus.topaid ||
            status == PaymentRequestStatus.paid,
        status == PaymentRequestStatus.pending,
      ),
      if (needsCfo)
        (
          'Фінансовий директор',
          status == PaymentRequestStatus.approvedByFinanceDirector ||
              status == PaymentRequestStatus.approved ||
              status == PaymentRequestStatus.topaid ||
              status == PaymentRequestStatus.paid,
          status == PaymentRequestStatus.approvedByDepartmentHead,
        ),
      if (needsOwner)
        (
          'Власник',
          status == PaymentRequestStatus.approved ||
              status == PaymentRequestStatus.topaid ||
              status == PaymentRequestStatus.paid,
          status == PaymentRequestStatus.approvedByFinanceDirector,
        ),
      (
        'Бухгалтерія',
        status == PaymentRequestStatus.paid,
        status == PaymentRequestStatus.topaid,
      ),
    ];
  }
}

class _DesktopDetailGrid extends StatelessWidget {
  const _DesktopDetailGrid({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => SizedBox(
              width: 158,
              child: _DesktopDetailTile(label: item.$1, value: item.$2),
            ),
          )
          .toList(),
    );
  }
}

class _DesktopDetailTile extends StatelessWidget {
  const _DesktopDetailTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.58)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.52),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value.trim().isEmpty ? '—' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 12.2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopPanelSection extends StatelessWidget {
  const _DesktopPanelSection({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.58)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.58),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _RouteStep extends StatelessWidget {
  const _RouteStep({
    required this.label,
    required this.done,
    required this.active,
  });

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = done
        ? const Color(0xFF16A34A)
        : active
            ? const Color(0xFFF59E0B)
            : cs.onSurface.withValues(alpha: 0.34);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : active
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
            color: color,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: done || active
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.58),
                fontSize: 12.6,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopStatusPill extends StatelessWidget {
  const _DesktopStatusPill({
    required this.text,
    required this.statusUi,
  });

  final String text;
  final _StatusUi statusUi;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: statusUi.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: statusUi.border),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: statusUi.color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DesktopCountBadge extends StatelessWidget {
  const _DesktopCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: cs.primary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DesktopEmptyPanel extends StatelessWidget {
  const _DesktopEmptyPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.border,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color border;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 42, 24, 42),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 38, color: cs.primary),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.66),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

class _SectionSelector extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback onTap;

  const _SectionSelector({
    required this.title,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Icon(Icons.menu_rounded, color: cs.onSurface, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              if (count > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: cs.onSurface.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApprovalFiltersPanel extends StatelessWidget {
  final String status;
  final String period;
  final String org;
  final String contractor;
  final String orgTooltip;
  final String periodTooltip;
  final Color? statusAccent;
  final Color statusBg;
  final bool hasFilters;
  final bool showOrgFilter;
  final VoidCallback onStatus;
  final VoidCallback onPeriod;
  final VoidCallback onOrg;
  final VoidCallback onContractor;
  final VoidCallback onClear;

  const _ApprovalFiltersPanel({
    required this.status,
    required this.period,
    required this.org,
    required this.contractor,
    required this.orgTooltip,
    required this.periodTooltip,
    required this.statusAccent,
    required this.statusBg,
    required this.hasFilters,
    required this.showOrgFilter,
    required this.onStatus,
    required this.onPeriod,
    required this.onOrg,
    required this.onContractor,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _FilterPill(
                  icon: Icons.tune_rounded,
                  title: 'Статус',
                  value: status,
                  accent: statusAccent,
                  accentBg: statusBg,
                  onTap: onStatus,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterPill(
                  icon: Icons.date_range_rounded,
                  title: 'Період',
                  value: period,
                  tooltip: periodTooltip,
                  onTap: onPeriod,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _FilterPill(
                  icon: Icons.search_rounded,
                  title: 'Контрагент',
                  value: contractor,
                  tooltip: 'Контрагент: $contractor',
                  onTap: onContractor,
                ),
              ),
              if (showOrgFilter) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _FilterPill(
                    icon: Icons.business_rounded,
                    title: 'Організація',
                    value: org,
                    tooltip: orgTooltip,
                    onTap: onOrg,
                  ),
                ),
              ] else ...[
                const SizedBox(width: 8),
                _ClearFilterButton(
                  enabled: hasFilters,
                  onTap: onClear,
                ),
              ],
            ],
          ),
          if (showOrgFilter) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                _ClearFilterButton(
                  enabled: hasFilters,
                  onTap: onClear,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? tooltip;
  final Color? accent;
  final Color? accentBg;
  final VoidCallback onTap;

  const _FilterPill({
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;
    final a = accent;

    final content = InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          color: a == null ? cs.surface : (accentBg ?? cs.surface),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: a == null ? border : a.withValues(alpha: 0.24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 18, color: a ?? cs.onSurface.withValues(alpha: 0.66)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.66),
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.expand_more_rounded,
                  color: a ?? cs.onSurface.withValues(alpha: 0.66),
                  size: 18,
                ),
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
                  color: a ?? cs.onSurface,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (tooltip == null) return content;
    return Tooltip(message: tooltip!, child: content);
  }
}

class _ClearFilterButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _ClearFilterButton({
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? onTap : null,
      child: Ink(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: enabled ? cs.primary.withValues(alpha: 0.12) : cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled ? cs.primary.withValues(alpha: 0.22) : border,
          ),
        ),
        child: Icon(
          enabled ? Icons.filter_alt_off_rounded : Icons.filter_alt_rounded,
          color: enabled ? cs.primary : cs.onSurface.withValues(alpha: 0.58),
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

class _ApprovalCard extends StatelessWidget {
  final String contractor;
  final String org;
  final String requesterName;
  final String subdivisionName;
  final bool showRequesterMeta;
  final String operationType;
  final String requestDate;
  final String purpose;
  final String paymentForm;
  final String amount;
  final String date;
  final String statusText;
  final _StatusUi statusUi;
  final Color border;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ApprovalCard({
    required this.contractor,
    required this.org,
    required this.requesterName,
    required this.subdivisionName,
    required this.showRequesterMeta,
    required this.operationType,
    required this.requestDate,
    required this.purpose,
    required this.paymentForm,
    required this.amount,
    required this.date,
    required this.statusText,
    required this.statusUi,
    required this.border,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final paymentAccent = cs.primary;
    final paymentBg = isDark
        ? cs.primary.withValues(alpha: 0.10)
        : cs.primary.withValues(alpha: 0.08);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 7,
                height: 54,
                decoration: BoxDecoration(
                  color: statusUi.color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contractor,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                        height: 1.15,
                      ),
                    ),
                    if (org.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.business_rounded,
                            size: 14,
                            color: cs.onSurface.withValues(alpha: 0.62),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              org,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.74),
                                fontSize: 12.6,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (operationType.trim().isNotEmpty ||
                        requestDate.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          if (operationType.trim().isNotEmpty)
                            Text(
                              operationType,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.74),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          Text(
                            'Заявка: $requestDate',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.60),
                              fontSize: 11.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (showRequesterMeta &&
                        (requesterName.trim().isNotEmpty ||
                            subdivisionName.trim().isNotEmpty)) ...[
                      const SizedBox(height: 6),
                      if (requesterName.trim().isNotEmpty)
                        Text(
                          'Заявник: ${requesterName.trim()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.74),
                            fontSize: 12.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      if (subdivisionName.trim().isNotEmpty) ...[
                        if (requesterName.trim().isNotEmpty)
                          const SizedBox(height: 2),
                        Text(
                          subdivisionName.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.60),
                            fontSize: 11.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                    if (purpose.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        purpose,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.74),
                          fontSize: 12.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaChip(
                          icon: Icons.account_balance_rounded,
                          text: paymentForm,
                          bg: paymentBg,
                          border: paymentAccent.withValues(alpha: 0.20),
                          color: paymentAccent,
                        ),
                        _MetaChip(
                          icon: Icons.payments_outlined,
                          text: amount,
                          bg: cs.surface,
                          border: border,
                          color: cs.onSurface.withValues(alpha: 0.82),
                        ),
                        _MetaChip(
                          icon: Icons.event_outlined,
                          text: date,
                          bg: cs.surface,
                          border: border,
                          color: cs.onSurface.withValues(alpha: 0.82),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: statusUi.bg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusUi.border),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusUi.color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  final String title;
  final Widget child;

  const _FilterSheet({
    required this.title,
    required this.child,
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
            Text(
              title,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w900,
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.10) : cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.42) : border,
          ),
        ),
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
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? color : cs.onSurface.withValues(alpha: 0.58),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color bg;
  final Color border;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.text,
    required this.bg,
    required this.border,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11.6,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusUi {
  final Color color;
  final Color bg;
  final Color border;

  const _StatusUi({
    required this.color,
    required this.bg,
    required this.border,
  });
}
