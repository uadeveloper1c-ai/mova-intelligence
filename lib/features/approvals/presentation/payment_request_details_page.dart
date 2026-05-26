import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:mova_intelligence_app/api/auth_provider.dart';
import 'package:mova_intelligence_app/api/push_service.dart';
import 'package:mova_intelligence_app/features/approvals/presentation/new_request_page.dart';
import 'package:mova_intelligence_app/features/auth/session_store.dart';

import '../approvals_service.dart';
import '../domain/payment_request.dart';

class PaymentRequestDetailsPage extends StatefulWidget {
  final String uid;
  final bool allowActions;

  const PaymentRequestDetailsPage({
    super.key,
    required this.uid,
    this.allowActions = false,
  });

  @override
  State<PaymentRequestDetailsPage> createState() =>
      _PaymentRequestDetailsPageState();
}

class _PaymentRequestDetailsPageState extends State<PaymentRequestDetailsPage> {
  late Future<PaymentRequest> _future;
  bool _busy = false;
  String? _openingAttachmentUid;
  Map<String, String> _orgNamesByCode = const {};

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadOrgNames();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PushService>().clearSystemNotifications();
    });
  }

  Future<void> _loadOrgNames() async {
    final session = await SessionStore.loadSession();
    if (!mounted || session == null) return;

    final map = <String, String>{};
    for (final org in session.orgs) {
      final code = org.code.trim();
      if (code.isEmpty) continue;
      map[code] = org.name.trim();
    }

    setState(() {
      _orgNamesByCode = map;
    });
  }

  Future<PaymentRequest> _load() {
    final service = context.read<ApprovalsService>();
    return service.getRequestById(widget.uid);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
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

  Future<void> _openAttachment(PaymentRequestAttachment attachment) async {
    final fileUid = attachment.uid.trim();
    if (fileUid.isEmpty || _openingAttachmentUid != null) return;

    setState(() => _openingAttachmentUid = fileUid);
    try {
      final service = context.read<ApprovalsService>();
      final data = await service.downloadAttachment(fileUid: fileUid);
      if (!mounted) return;

      final lowerName = data.fileName.toLowerCase();
      final isImage = _isImageFile(lowerName, data.contentType);
      final isPdf = _isPdfFile(lowerName, data.contentType);

      if (isImage) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => _AttachmentPreviewDialog(
            fileName: data.fileName,
            bytes: data.bytes,
          ),
        );
        return;
      }

      if (isPdf) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _PdfPreviewPage(
              fileName: data.fileName,
              bytes: data.bytes,
            ),
          ),
        );
        return;
      }

      await _openWithSystemViewer(
        fileName: data.fileName,
        bytes: data.bytes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося відкрити вкладення: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _openingAttachmentUid = null);
      }
    }
  }

  bool _isImageFile(String lowerName, String contentType) {
    return contentType.startsWith('image/') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.webp');
  }

  bool _isPdfFile(String lowerName, String contentType) {
    return contentType == 'application/pdf' || lowerName.endsWith('.pdf');
  }

  Future<void> _openWithSystemViewer({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final safeName = fileName.trim().isEmpty
        ? 'attachment.bin'
        : fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${tempDir.path}${Platform.pathSeparator}$safeName');
    await file.writeAsBytes(bytes, flush: true);

    final result = await OpenFilex.open(file.path);
    if (!mounted) return;

    if (result.type != ResultType.done) {
      final message = result.message.trim();
      throw Exception(
        message.isEmpty ? 'Не вдалося відкрити файл на пристрої' : message,
      );
    }
  }

  String _safeText(String? value) {
    if (value == null) return '—';
    final v = value.trim();
    return v.isEmpty ? '—' : v;
  }

  String _orgLabel(PaymentRequest r) {
    final code = r.orgCode.trim();
    if (code.isEmpty) return '—';

    final name = (_orgNamesByCode[code] ?? '').trim();
    return name.isEmpty ? code : name;
  }

  String _labelOrUid(String name, String uid) {
    final normalizedName = name.trim();
    if (normalizedName.isNotEmpty) return normalizedName;

    final normalizedUid = uid.trim();
    if (normalizedUid.isNotEmpty) return normalizedUid;

    return '—';
  }

  String _fmtDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year}';
  }

  String _fmtAmount(double amount, String currency) {
    final hasFraction = amount % 1 != 0;
    final formatted =
        hasFraction ? amount.toStringAsFixed(2) : amount.toStringAsFixed(0);
    return '$formatted ${currency.toUpperCase()}';
  }

  String paymentFormHuman(PaymentForm form) {
    switch (form) {
      case PaymentForm.cash:
        return 'Готівка';
      case PaymentForm.cashless:
        return 'Безготівково';
      case PaymentForm.unknown:
        return '—';
    }
  }

  bool _isEditableStatus(PaymentRequestStatus status) {
    return status == PaymentRequestStatus.preliminary ||
        status == PaymentRequestStatus.pending;
  }

  bool _isCurrentUserAuthor(AuthProvider auth, PaymentRequest r) {
    final currentUid = auth.currentUser?.uid.trim() ?? '';
    final requesterUid = r.requesterUid.trim();

    if (requesterUid.isEmpty) return true;

    return currentUid.isNotEmpty && currentUid == requesterUid;
  }

  _StatusUi _statusUi(BuildContext context, PaymentRequestStatus status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (status) {
      case PaymentRequestStatus.preliminary:
        return _StatusUi(
          color: const Color(0xFF0EA5E9),
          bg: isDark ? const Color(0xFF123044) : const Color(0xFFE0F2FE),
          border: isDark ? const Color(0xFF1F5F82) : const Color(0xFFBAE6FD),
          icon: Icons.event_note_rounded,
        );

      case PaymentRequestStatus.draft:
        return _StatusUi(
          color: const Color(0xFF94A3B8),
          bg: isDark ? const Color(0xFF1A2432) : const Color(0xFFF8FAFC),
          border: isDark ? const Color(0xFF334155) : const Color(0xFFE7EDF4),
          icon: Icons.edit_rounded,
        );

      case PaymentRequestStatus.pending:
        return _StatusUi(
          color: const Color(0xFF2F80ED),
          bg: isDark ? const Color(0xFF142338) : const Color(0xFFEEF5FF),
          border: isDark ? const Color(0xFF23476D) : const Color(0xFFD9E8FF),
          icon: Icons.schedule_rounded,
        );

      case PaymentRequestStatus.approvedByDepartmentHead:
        return _StatusUi(
          color: const Color(0xFF4F46E5),
          bg: isDark ? const Color(0xFF1C1E3E) : const Color(0xFFEEF2FF),
          border: isDark ? const Color(0xFF3730A3) : const Color(0xFFC7D2FE),
          icon: Icons.account_tree_rounded,
        );
      case PaymentRequestStatus.approvedByFinanceDirector:
        return _StatusUi(
          color: const Color(0xFF7C3AED),
          bg: isDark ? const Color(0xFF24163A) : const Color(0xFFF3EEFF),
          border: isDark ? const Color(0xFF5B21B6) : const Color(0xFFE4D5FF),
          icon: Icons.workspace_premium_rounded,
        );

      case PaymentRequestStatus.approved:
        return _StatusUi(
          color: const Color(0xFF84CC16),
          bg: isDark ? const Color(0xFF202C10) : const Color(0xFFF7FEE7),
          border: isDark ? const Color(0xFF65A30D) : const Color(0xFFBEF264),
          icon: Icons.check_circle_rounded,
        );

      case PaymentRequestStatus.rejected:
        return _StatusUi(
          color: const Color(0xFFEF4444),
          bg: isDark ? const Color(0xFF341819) : const Color(0xFFFEF2F2),
          border: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCDDDD),
          icon: Icons.cancel_rounded,
        );

      case PaymentRequestStatus.topaid:
        return _StatusUi(
          color: const Color(0xFFF59E0B),
          bg: isDark ? const Color(0xFF33210F) : const Color(0xFFFFFBEB),
          border: isDark ? const Color(0xFFB45309) : const Color(0xFFFDE68A),
          icon: Icons.payments_rounded,
        );

      case PaymentRequestStatus.paid:
        return _StatusUi(
          color: const Color(0xFF0F766E),
          bg: isDark ? const Color(0xFF0F2D2B) : const Color(0xFFF0FDFA),
          border: isDark ? const Color(0xFF14B8A6) : const Color(0xFF99F6E4),
          icon: Icons.verified_rounded,
        );
    }
  }

  Future<void> _changeStatus(
    PaymentRequest r,
    PaymentRequestStatus status,
  ) async {
    final service = context.read<ApprovalsService>();

    setState(() => _busy = true);
    try {
      final updated = await service.changeStatus(
        requestId: r.id,
        newStatus: status,
      );

      if (!mounted) return;

      setState(() {
        _future = Future.value(updated);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            switch (status) {
              PaymentRequestStatus.pending =>
                'Заявку відправлено на погодження',
              PaymentRequestStatus.approved => 'Заявку погоджено',
              PaymentRequestStatus.rejected => 'Заявку відхилено',
              _ => 'Статус заявки змінено',
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося змінити статус: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _row(
    BuildContext context,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sub = theme.textTheme.bodyMedium?.color ??
        cs.onSurface.withValues(alpha: 0.72);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: TextStyle(
                color: sub,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required BuildContext context,
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.16 : 0.06,
            ),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildLoaded(PaymentRequest r) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;
    final sub = theme.textTheme.bodyMedium?.color ??
        cs.onSurface.withValues(alpha: 0.72);

    final auth = context.watch<AuthProvider>();
    final statusUi = _statusUi(context, r.status);
    final requesterName = _safeText(r.requesterName);
    final approverName = _safeText(r.approverName);
    final formLabel = paymentFormHuman(r.paymentForm);
    final operationTypeLabel = paymentOperationTypeHuman(r.operationType);
    final attachments = r.attachments;

    final canAct = widget.allowActions &&
        (r.status == PaymentRequestStatus.pending ||
            r.status == PaymentRequestStatus.approvedByDepartmentHead ||
            r.status == PaymentRequestStatus.approvedByFinanceDirector);

    final isAuthor = _isCurrentUserAuthor(auth, r);
    final canEdit = isAuthor && _isEditableStatus(r.status);
    final canSendToApproval =
        isAuthor && r.status == PaymentRequestStatus.preliminary;

    const canCopy = true;

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.16 : 0.06,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: statusUi.bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusUi.border),
                  ),
                  child: Icon(
                    statusUi.icon,
                    color: statusUi.color,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.contractorName.trim().isEmpty
                            ? '—'
                            : r.contractorName,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Платіж: ${_fmtDate(r.date)}',
                        style: TextStyle(
                          color: sub,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: statusUi.bg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusUi.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusUi.icon, size: 16, color: statusUi.color),
                    const SizedBox(width: 8),
                    Text(
                      paymentStatusHuman(r.status),
                      style: TextStyle(
                        color: statusUi.color,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (canEdit)
                FilledButton.icon(
                  onPressed: () => _openEdit(r),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Редагувати'),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              if (canCopy)
                OutlinedButton.icon(
                  onPressed: () => _openCopy(r),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Копіювати'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.onSurface,
                    side: BorderSide(color: border),
                    backgroundColor: cs.surface,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _section(
            context: context,
            title: 'Основне',
            child: Column(
              children: [
                _row(context, 'Дата платежу', _fmtDate(r.date)),
                _row(context, 'Дата заявки', _fmtDate(r.requestDate)),
                _row(context, 'Сума', _fmtAmount(r.amount, r.currency)),
                _row(context, 'Організація', _orgLabel(r)),
                _row(context, 'Вид операції', operationTypeLabel),
                if (r.operationType == PaymentOperationType.salaryPayment) ...[
                  _row(
                    context,
                    'Відомість',
                    _labelOrUid(r.statementName, r.statementUid),
                  ),
                  _row(
                    context,
                    'Каса',
                    _labelOrUid(r.cashboxName, r.cashboxUid),
                  ),
                ],
                if (r.operationType == PaymentOperationType.taxPayment)
                  _row(
                    context,
                    'Податок',
                    _labelOrUid(r.taxName, r.taxUid),
                  ),
                _row(context, 'Форма оплати', formLabel),
                _row(context, 'Терміново', r.urgent ? 'Так' : 'Ні'),
                _row(context, 'Заявник', requesterName),
                _row(context, 'Погоджує', approverName),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _section(
            context: context,
            title: 'Призначення',
            child: Text(
              r.purpose.trim().isEmpty ? '—' : r.purpose.trim(),
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            _section(
              context: context,
              title: 'Вкладення',
              child: Column(
                children: [
                  for (var i = 0; i < attachments.length; i++) ...[
                    _attachmentTile(
                      context: context,
                      attachment: attachments[i],
                      sub: sub,
                      border: border,
                    ),
                    if (i != attachments.length - 1) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
          if (canSendToApproval) ...[
            const SizedBox(height: 12),
            _section(
              context: context,
              title: 'Попередня заявка',
              child: FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _changeStatus(r, PaymentRequestStatus.pending),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('Відправити на погодження'),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
          if (canAct) ...[
            const SizedBox(height: 12),
            _section(
              context: context,
              title: 'Дії',
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () =>
                              _changeStatus(r, PaymentRequestStatus.rejected),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Відхилити'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: BorderSide(
                          color: theme.brightness == Brightness.dark
                              ? const Color(0xFF7F1D1D)
                              : const Color(0xFFF3C7C7),
                        ),
                        backgroundColor: theme.brightness == Brightness.dark
                            ? const Color(0xFF2A1414)
                            : const Color(0xFFFFF5F5),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () =>
                              _changeStatus(r, PaymentRequestStatus.approved),
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: const Text('Погодити'),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
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

  Widget _buildError(Object error) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;
    final sub = theme.textTheme.bodyMedium?.color ??
        cs.onSurface.withValues(alpha: 0.72);

    final accentBg = theme.brightness == Brightness.dark
        ? cs.primary.withValues(alpha: 0.16)
        : cs.primary.withValues(alpha: 0.12);

    final accentBorder = theme.brightness == Brightness.dark
        ? cs.primary.withValues(alpha: 0.30)
        : cs.primary.withValues(alpha: 0.20);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.16 : 0.06,
                ),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accentBorder),
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  color: cs.primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Не вдалося завантажити заявку',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: sub,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Спробувати ще раз'),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachmentTile({
    required BuildContext context,
    required PaymentRequestAttachment attachment,
    required Color sub,
    required Color border,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isOpening = _openingAttachmentUid == attachment.uid.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isOpening ? null : () => _openAttachment(attachment),
      child: Ink(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.attach_file_rounded,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Натисніть, щоб відкрити',
                    style: TextStyle(
                      color: sub,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            isOpening
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  )
                : Icon(
                    Icons.open_in_new_rounded,
                    color: cs.primary,
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Деталі заявки',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<PaymentRequest>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _buildError(snapshot.error!);
          }

          final r = snapshot.data;
          if (r == null) {
            return Center(
              child: Text(
                'Заявку не знайдено',
                style: TextStyle(color: cs.onSurface),
              ),
            );
          }

          return _buildLoaded(r);
        },
      ),
    );
  }
}

class _StatusUi {
  final Color color;
  final Color bg;
  final Color border;
  final IconData icon;

  const _StatusUi({
    required this.color,
    required this.bg,
    required this.border,
    required this.icon,
  });
}

class _AttachmentPreviewDialog extends StatelessWidget {
  final String fileName;
  final Uint8List bytes;

  const _AttachmentPreviewDialog({
    required this.fileName,
    required this.bytes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        color: cs.surface,
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Не вдалося показати зображення',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfPreviewPage extends StatelessWidget {
  final String fileName;
  final Uint8List bytes;

  const _PdfPreviewPage({
    required this.fileName,
    required this.bytes,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SfPdfViewer.memory(
        bytes,
        canShowScrollHead: true,
        canShowPaginationDialog: true,
      ),
    );
  }
}
