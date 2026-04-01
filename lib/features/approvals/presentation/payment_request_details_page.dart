import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mova_intelligence_app/api/auth_provider.dart';
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
  bool _attachmentBusy = false;

  static const _bg = Color(0xFF0E1A2B);
  static const _panel = Color(0xFF1A2A40);
  static const _border = Color(0xFF2A3B52);
  static const _text = Color(0xFFF3F7FB);
  static const _sub = Color(0xFFB7C4D1);
  static const _accent = Color(0xFF22D3EE);

  @override
  void initState() {
    super.initState();
    _future = _load();
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

  String _safeText(String? value) {
    if (value == null) return '-';
    final v = value.trim();
    return v.isEmpty ? '-' : v;
  }

  String _fmtDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year}';
  }

  String _fmtAmount(double amount, String currency) {
    return '${amount.toStringAsFixed(0)} ${currency.toUpperCase()}';
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

  Color _statusColor(PaymentRequestStatus status) {
    switch (status) {
      case PaymentRequestStatus.draft:
        return const Color(0xFF94A3B8);
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
    }
  }

  IconData _statusIcon(PaymentRequestStatus status) {
    switch (status) {
      case PaymentRequestStatus.draft:
        return Icons.edit_rounded;
      case PaymentRequestStatus.pending:
        return Icons.schedule_rounded;
      case PaymentRequestStatus.approvedByDepartmentHead:
        return Icons.account_tree_rounded;
      case PaymentRequestStatus.approved:
        return Icons.check_circle_rounded;
      case PaymentRequestStatus.rejected:
        return Icons.cancel_rounded;
      case PaymentRequestStatus.topaid:
        return Icons.payments_rounded;
      case PaymentRequestStatus.paid:
        return Icons.verified_rounded;
    }
  }

  Future<void> _changeStatus(PaymentRequest r, PaymentRequestStatus status) async {
    final service = context.read<ApprovalsService>();

    setState(() => _busy = true);
    try {
      await service.changeStatus(
        requestId: r.id,
        newStatus: status,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == PaymentRequestStatus.approved
                ? 'Заявку погоджено'
                : 'Заявку відхилено',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося змінити статус: $e')),
      );
      setState(() => _busy = false);
      await _reload();

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

  Future<void> _openAttachment(PaymentRequest request) async {
    setState(() => _attachmentBusy = true);

    try {
      final service = context.read<ApprovalsService>();
      final file = await service.downloadAttachment(requestId: request.id);

      if (!mounted) return;

      if (file.isImage) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _AttachmentImagePage(
              title: request.attachment?.name.isNotEmpty == true
                  ? request.attachment!.name
                  : file.fileName,
              bytes: file.bytes,
            ),
          ),
        );
        return;
      }

      if (file.isPdf) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF "${file.fileName}" завантажено. Для вбудованого перегляду PDF додамо viewer окремо.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Файл "${file.fileName}" завантажено (${file.contentType}).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося відкрити вкладення: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _attachmentBusy = false);
      }
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: const TextStyle(
                color: _sub,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _text,
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
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _panel.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _text,
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

  Widget _attachmentSection(PaymentRequest r) {
    final attachment = r.attachment;
    if (attachment == null) {
      return const SizedBox.shrink();
    }

    return _section(
      title: 'Вкладення',
      child: InkWell(
        onTap: _attachmentBusy ? null : () => _openAttachment(r),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
            color: Colors.white.withValues(alpha: 0.03),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _accent.withValues(alpha: 0.20),
                  ),
                ),
                child: _attachmentBusy
                    ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(
                  Icons.attach_file_rounded,
                  color: _accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.name.trim().isEmpty
                          ? 'Вкладення'
                          : attachment.name.trim(),
                      style: const TextStyle(
                        color: _text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Натисніть, щоб відкрити',
                      style: TextStyle(
                        color: _sub,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.open_in_new_rounded,
                color: _sub,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoaded(PaymentRequest r) {
    final auth = context.watch<AuthProvider>();
    final statusColor = _statusColor(r.status);
    final requesterName = _safeText(r.requesterName);
    final approverName = _safeText(r.approverName);
    final formLabel = paymentFormHuman(r.paymentForm);

    final canAct = widget.allowActions &&
        auth.canApprovePayments &&
        (r.status == PaymentRequestStatus.pending ||
            r.status == PaymentRequestStatus.approvedByDepartmentHead);

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              color: _panel.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Icon(_statusIcon(r.status), color: statusColor, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Заявка №${r.number}',
                        style: const TextStyle(
                          color: _text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        r.contractorName.trim().isEmpty ? '—' : r.contractorName,
                        style: const TextStyle(
                          color: _sub,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.30),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_statusIcon(r.status), size: 16, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  paymentStatusHuman(r.status),
                  style: const TextStyle(
                    color: _text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _section(
            title: 'Основне',
            child: Column(
              children: [
                _row('Дата', _fmtDate(r.date)),
                _row('Сума', _fmtAmount(r.amount, r.currency)),
                _row('Форма оплати', formLabel),
                _row('Терміново', r.urgent ? 'Так' : 'Ні'),
                _row('Заявник', requesterName),
                _row('Погоджує', approverName),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _section(
            title: 'Призначення',
            child: Text(
              r.purpose.trim().isEmpty ? '—' : r.purpose.trim(),
              style: const TextStyle(
                color: _text,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          if (r.attachment != null) ...[
            const SizedBox(height: 12),
            _attachmentSection(r),
          ],
          if (canAct) ...[
            const SizedBox(height: 12),
            _section(
              title: 'Дії',
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _changeStatus(r, PaymentRequestStatus.rejected),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Відхилити'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFCA5A5),
                        side: BorderSide(
                          color: const Color(0xFFF97373).withValues(alpha: 0.45),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _changeStatus(r, PaymentRequestStatus.approved),
                      icon: _busy
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.check_rounded),
                      label: const Text('Погодити'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Деталі заявки',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: _text,
        elevation: 0,
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _panel.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_rounded, color: _sub, size: 40),
                      const SizedBox(height: 12),
                      const Text(
                        'Не вдалося завантажити заявку',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _sub,
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
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final r = snapshot.data;
          if (r == null) {
            return const Center(
              child: Text(
                'Заявку не знайдено',
                style: TextStyle(color: _text),
              ),
            );
          }

          return _buildLoaded(r);
        },
      ),
    );
  }
}

class _AttachmentImagePage extends StatelessWidget {
  final String title;
  final Uint8List bytes;

  const _AttachmentImagePage({
    required this.title,
    required this.bytes,
  });

  static const _bg = Color(0xFF0E1A2B);
  static const _text = Color(0xFFF3F7FB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: _text,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.7,
          maxScale: 5,
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Не вдалося відобразити зображення',
                  style: TextStyle(
                    color: _text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}