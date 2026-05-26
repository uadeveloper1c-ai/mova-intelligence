import 'package:flutter/material.dart';

import '../../domain/payment_request.dart';

class PaymentRequestCard extends StatelessWidget {
  final PaymentRequest r;
  final String orgLabel;
  final String requestDateLabel;
  final String operationTypeLabel;
  final bool showInlineActions;
  final String currentUserUid;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const PaymentRequestCard({
    super.key,
    required this.r,
    this.orgLabel = '',
    this.requestDateLabel = '',
    this.operationTypeLabel = '',
    this.showInlineActions = false,
    this.currentUserUid = '',
    this.onApprove,
    this.onReject,
    this.onTap,
    this.onLongPress,
  });

  static const _bgSoft = Color(0xFFEAF3F5);

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year.toString().substring(2)}';

  _PillModel _statusPill(PaymentRequestStatus status) {
    switch (status) {
      case PaymentRequestStatus.preliminary:
        return const _PillModel(
          label: 'Попередня',
          icon: Icons.event_note_rounded,
          color: Color(0xFF0EA5E9),
          bg: Color(0xFFE0F2FE),
          border: Color(0xFFBAE6FD),
        );
      case PaymentRequestStatus.pending:
        return const _PillModel(
          label: 'На погодженні',
          icon: Icons.schedule_rounded,
          color: Color(0xFF1976D2),
          bg: Color(0xFFE3F2FD),
          border: Color(0xFF90CAF9),
        );
      case PaymentRequestStatus.approved:
        return const _PillModel(
          label: 'Погоджено',
          icon: Icons.check_circle_rounded,
          color: Color(0xFF84CC16),
          bg: Color(0xFFF7FEE7),
          border: Color(0xFFBEF264),
        );
      case PaymentRequestStatus.approvedByDepartmentHead:
        return const _PillModel(
          label: 'Погоджено керівником',
          icon: Icons.account_tree_rounded,
          color: Color(0xFF4F46E5),
          bg: Color(0xFFEEF2FF),
          border: Color(0xFFC7D2FE),
        );
      case PaymentRequestStatus.approvedByFinanceDirector:
        return const _PillModel(
          label: 'Погоджено CFO',
          icon: Icons.workspace_premium_rounded,
          color: Color(0xFF7C3AED),
          bg: Color(0xFFF3EEFF),
          border: Color(0xFFE4D5FF),
        );
      case PaymentRequestStatus.rejected:
        return const _PillModel(
          label: 'Відхилено',
          icon: Icons.cancel_rounded,
          color: Color(0xFFEF4444),
          bg: Color(0xFFFEF2F2),
          border: Color(0xFFFCDDDD),
        );
      case PaymentRequestStatus.topaid:
        return const _PillModel(
          label: 'До оплати',
          icon: Icons.payments_rounded,
          color: Color(0xFFF59E0B),
          bg: Color(0xFFFFFBEB),
          border: Color(0xFFFDE68A),
        );
      case PaymentRequestStatus.paid:
        return const _PillModel(
          label: 'Оплачено',
          icon: Icons.verified_rounded,
          color: Color(0xFF0F766E),
          bg: Color(0xFFF0FDFA),
          border: Color(0xFF99F6E4),
        );
      case PaymentRequestStatus.draft:
        return const _PillModel(
          label: 'Чернетка',
          icon: Icons.edit_rounded,
          color: Color(0xFF94A3B8),
          bg: Color(0xFFF8FAFC),
          border: Color(0xFFE7EDF4),
        );
    }
  }

  _PillModel _paymentFormPill(PaymentForm form) {
    switch (form) {
      case PaymentForm.cash:
        return const _PillModel(
          label: 'Готівка',
          icon: Icons.payments_rounded,
          color: Color(0xFFF59E0B),
          bg: Color(0xFFFFF7E8),
          border: Color(0xFFFBE3B0),
        );
      case PaymentForm.cashless:
        return const _PillModel(
          label: 'Безготівково',
          icon: Icons.account_balance_rounded,
          color: Color(0xFF2F9E97),
          bg: Color(0xFFE8F5F4),
          border: Color(0xFFD0E9E7),
        );
      case PaymentForm.unknown:
        return const _PillModel(
          label: 'Форма: —',
          icon: Icons.help_outline_rounded,
          color: Color(0xFF94A3B8),
          bg: Color(0xFFF8FAFC),
          border: Color(0xFFE7EDF4),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final panel = cs.surface;
    final panelSoft =
        isDark ? cs.surfaceContainerHighest.withValues(alpha: 0.34) : _bgSoft;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;
    final text = cs.onSurface;
    final sub = theme.textTheme.bodyMedium?.color ??
        cs.onSurface.withValues(alpha: 0.72);
    final muted = cs.onSurface.withValues(alpha: isDark ? 0.58 : 0.52);
    final accentSoft = cs.primary.withValues(alpha: isDark ? 0.16 : 0.12);

    final contractor =
        r.contractorName.trim().isEmpty ? '—' : r.contractorName.trim();
    final org = orgLabel.trim();
    final requestDate = requestDateLabel.trim();
    final operationType = operationTypeLabel.trim();
    final purpose = r.purpose.trim();
    final amountStr =
        '${r.amount.toStringAsFixed(0)} ${r.currency.toUpperCase()}';
    final dateStr = _fmtDate(r.date);
    final requesterName = r.requesterName?.trim() ?? '';
    final requesterUid = r.requesterUid.trim();
    final subdivisionName = r.subdivisionName.trim();
    final isOwnRequest =
        requesterUid.isNotEmpty && currentUserUid.trim() == requesterUid;
    final showRequesterMeta =
        !isOwnRequest && (requesterName.isNotEmpty || subdivisionName.isNotEmpty);

    final statusModel = _statusPill(r.status);
    final paymentModel = _paymentFormPill(r.paymentForm);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Ink(
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        contractor,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: text,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: _StatusBadge(model: statusModel),
                    ),
                  ],
                ),
                if (org.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.business_rounded,
                        size: 15,
                        color: muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          org,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: sub,
                            fontSize: 12.8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (operationType.isNotEmpty || requestDate.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      if (operationType.isNotEmpty)
                        Text(
                          operationType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: sub,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      if (requestDate.isNotEmpty)
                        Text(
                          'Заявка: $requestDate',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: muted,
                            fontSize: 11.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ],
                if (showRequesterMeta) ...[
                  const SizedBox(height: 8),
                  if (requesterName.isNotEmpty)
                    Text(
                      'Заявник: $requesterName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: sub,
                        fontSize: 12.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  if (subdivisionName.isNotEmpty) ...[
                    if (requesterName.isNotEmpty) const SizedBox(height: 2),
                    Text(
                      subdivisionName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted,
                        fontSize: 11.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _InfoChip(model: paymentModel),
                    ),
                    const SizedBox(width: 8),
                    _MiniDateChip(dateStr: dateStr),
                  ],
                ),
                if (purpose.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Призначення',
                    style: TextStyle(
                      color: muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    purpose,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: sub,
                      fontSize: 12.8,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: panelSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: accentSoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: cs.primary.withValues(alpha: 0.22)),
                        ),
                        child: Icon(
                          Icons.payments_outlined,
                          color: cs.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Сума заявки',
                              style: TextStyle(
                                color: muted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'До оплати / погодження',
                              style: TextStyle(
                                color: sub,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        amountStr,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: text,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showInlineActions) ...[
                  const SizedBox(height: 14),
                  Divider(color: border, height: 1, thickness: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onReject,
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Відхилити'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFF3C7C7)),
                            backgroundColor: const Color(0xFFFFF5F5),
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
                          onPressed: onApprove,
                          icon: const Icon(Icons.check_rounded),
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
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PillModel {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final Color border;

  const _PillModel({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.border,
  });
}

class _StatusBadge extends StatelessWidget {
  final _PillModel model;

  const _StatusBadge({required this.model});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? model.color.withValues(alpha: 0.16) : model.bg;
    final border = isDark ? model.color.withValues(alpha: 0.30) : model.border;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: model.color.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(model.icon, size: 15, color: model.color),
          const SizedBox(width: 6),
          Text(
            model.label,
            style: TextStyle(
              color: model.color,
              fontSize: 12.2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final _PillModel model;

  const _InfoChip({required this.model});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? model.color.withValues(alpha: 0.14) : model.bg;
    final border = isDark ? model.color.withValues(alpha: 0.28) : model.border;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(model.icon, size: 16, color: model.color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              model.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: model.color,
                fontSize: 12.2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniDateChip extends StatelessWidget {
  final String dateStr;

  const _MiniDateChip({required this.dateStr});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? cs.surfaceContainerHighest.withValues(alpha: 0.34)
        : const Color(0xFFF5F7F9);
    final border = theme.dividerTheme.color ?? cs.outlineVariant;
    final muted = cs.onSurface.withValues(alpha: isDark ? 0.58 : 0.52);
    final sub = theme.textTheme.bodyMedium?.color ??
        cs.onSurface.withValues(alpha: 0.72);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_outlined,
            size: 15,
            color: muted,
          ),
          const SizedBox(width: 6),
          Text(
            dateStr,
            style: TextStyle(
              color: sub,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
