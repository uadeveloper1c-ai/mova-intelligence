import 'package:flutter/material.dart';

import '../../domain/payment_request.dart';

class PaymentRequestCard extends StatelessWidget {
  final PaymentRequest r;
  final bool showInlineActions;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onTap;

  const PaymentRequestCard({
    super.key,
    required this.r,
    this.showInlineActions = false,
    this.onApprove,
    this.onReject,
    this.onTap,
  });

  static const _text = Color(0xFFF3F7FB);
  static const _sub = Color(0xFFC0CDD9);
  static const _muted = Color(0xFF94A3B8);

  static const _bgA = Color(0xFF223553);
  static const _bgB = Color(0xFF16243C);
  static const _stroke = Color(0xFF334155);
  static const _innerStroke = Color(0x26FFFFFF);

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year.toString().substring(2)}';

  _PillModel _statusPill(PaymentRequestStatus status) {
    switch (status) {
      case PaymentRequestStatus.pending:
        return const _PillModel(
          label: 'На погодженні',
          icon: Icons.schedule_rounded,
          color: Color(0xFF38BDF8),
        );
      case PaymentRequestStatus.approved:
        return const _PillModel(
          label: 'Погоджено',
          icon: Icons.check_circle_rounded,
          color: Color(0xFF22C55E),
        );
      case PaymentRequestStatus.approvedByDepartmentHead:
        return const _PillModel(
          label: 'Погоджено керівником',
          icon: Icons.account_tree_rounded,
          color: Color(0xFFA78BFA),
        );
      case PaymentRequestStatus.rejected:
        return const _PillModel(
          label: 'Відхилено',
          icon: Icons.cancel_rounded,
          color: Color(0xFFF97373),
        );
      case PaymentRequestStatus.topaid:
        return const _PillModel(
          label: 'До оплати',
          icon: Icons.payments_rounded,
          color: Color(0xFFA78BFA),
        );
      case PaymentRequestStatus.paid:
        return const _PillModel(
          label: 'Оплачено',
          icon: Icons.verified_rounded,
          color: Color(0xFF10B981),
        );
      case PaymentRequestStatus.draft:
        return const _PillModel(
          label: 'Чернетка',
          icon: Icons.edit_rounded,
          color: Color(0xFF94A3B8),
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
        );
      case PaymentForm.cashless:
        return const _PillModel(
          label: 'Безготівково',
          icon: Icons.account_balance_rounded,
          color: Color(0xFF38BDF8),
        );
      case PaymentForm.unknown:
        return const _PillModel(
          label: 'Форма: —',
          icon: Icons.help_outline_rounded,
          color: Color(0xFF94A3B8),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contractor = r.contractorName.trim().isEmpty ? '—' : r.contractorName.trim();
    final purpose = r.purpose.trim();
    final amountStr = '${r.amount.toStringAsFixed(0)} ${r.currency.toUpperCase()}';
    final dateStr = _fmtDate(r.date);

    final statusModel = _statusPill(r.status);
    final paymentModel = _paymentFormPill(r.paymentForm);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _bgA.withValues(alpha: 0.98),
                _bgB.withValues(alpha: 0.98),
              ],
            ),
            border: Border.all(color: _stroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.26),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: statusModel.color.withValues(alpha: 0.05),
                blurRadius: 26,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _innerStroke),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                top: 10,
                child: IgnorePointer(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            contractor,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _text,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _StatusBadge(model: statusModel),
                      ],
                    ),
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
                    const SizedBox(height: 12),
                    if (purpose.isNotEmpty) ...[
                      const Text(
                        'Призначення',
                        style: TextStyle(
                          color: _muted,
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
                        style: const TextStyle(
                          color: _sub,
                          fontSize: 12.8,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: statusModel.color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: statusModel.color.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Icon(
                              Icons.payments_outlined,
                              color: statusModel.color,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Сума заявки',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'До оплати / погодження',
                                  style: TextStyle(
                                    color: _sub,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            amountStr,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: _text,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showInlineActions) ...[
                      const SizedBox(height: 14),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onReject,
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Відхилити'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                foregroundColor: const Color(0xFFFCA5A5),
                                side: BorderSide(
                                  color: const Color(0xFFF97373).withValues(alpha: 0.45),
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
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                            ),
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
      ),
    );
  }
}

class _PillModel {
  final String label;
  final IconData icon;
  final Color color;

  const _PillModel({
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _StatusBadge extends StatelessWidget {
  final _PillModel model;

  const _StatusBadge({required this.model});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: model.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: model.color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(model.icon, size: 15, color: model.color),
          const SizedBox(width: 6),
          Text(
            model.label,
            style: const TextStyle(
              color: PaymentRequestCard._text,
              fontSize: 11.8,
              fontWeight: FontWeight.w800,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
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
              style: const TextStyle(
                color: PaymentRequestCard._sub,
                fontSize: 12.2,
                fontWeight: FontWeight.w700,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.event_outlined,
            size: 15,
            color: PaymentRequestCard._muted,
          ),
          const SizedBox(width: 6),
          Text(
            dateStr,
            style: const TextStyle(
              color: PaymentRequestCard._sub,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}