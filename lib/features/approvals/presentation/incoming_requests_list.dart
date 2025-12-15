// lib/features/approvals/presentation/incoming_requests_list.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../approvals_service.dart';
import '../domain/payment_request.dart';

class IncomingRequestsList extends StatefulWidget {
  final DateTimeRange? range;
  final PaymentRequestStatus? statusFilter;
  final String contractorQuery;

  const IncomingRequestsList({
    super.key,
    this.range,
    this.statusFilter,
    this.contractorQuery = '',
  });

  @override
  State<IncomingRequestsList> createState() => _IncomingRequestsListState();
}

class _IncomingRequestsListState extends State<IncomingRequestsList> {
  late Future<List<PaymentRequest>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApprovalsService>().getIncomingRequests();
  }

  Future<void> _reload() async {
    final service = context.read<ApprovalsService>();
    final f = service.getIncomingRequests();
    setState(() {
      _future = f;
    });
    await f;
  }

  Color _statusColor(PaymentRequestStatus status) {
    switch (status) {
      case PaymentRequestStatus.pending:
        return Colors.orange;
      case PaymentRequestStatus.approved:
        return Colors.green;
      case PaymentRequestStatus.rejected:
        return Colors.red;
      case PaymentRequestStatus.topaid:
        return Colors.purple;
      case PaymentRequestStatus.paid:
        return Colors.blue;
      case PaymentRequestStatus.draft:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PaymentRequest>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Помилка завантаження заявок: ${snapshot.error}'),
            ),
          );
        }

        var items = snapshot.data ?? const <PaymentRequest>[];

        // фільтр по періоду
        final range = widget.range;
        if (range != null) {
          final start =
          DateTime(range.start.year, range.start.month, range.start.day);
          final end = DateTime(
              range.end.year, range.end.month, range.end.day, 23, 59, 59);

          bool inRange(DateTime d) =>
              !d.isBefore(start) && !d.isAfter(end);

          items = items.where((r) => inRange(r.date)).toList();
        }

        // фільтр по статусу
        if (widget.statusFilter != null) {
          items =
              items.where((r) => r.status == widget.statusFilter).toList();
        }

        // фільтр по контрагенту
        final q = widget.contractorQuery.trim().toLowerCase();
        if (q.isNotEmpty) {
          items = items
              .where(
                (r) => r.contractorName.toLowerCase().contains(q),
          )
              .toList();
        }

        if (items.isEmpty) {
          return const Center(
            child: Text('Немає заявок, які відповідають фільтру'),
          );
        }

        String fmtDate(DateTime d) =>
            '${d.day.toString().padLeft(2, '0')}.'
                '${d.month.toString().padLeft(2, '0')}.'
                '${d.year}';

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length,
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            itemBuilder: (context, index) {
              final r = items[index];
              final color = _statusColor(r.status);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                elevation: 10, // поглубже тень, ближе к Monobank
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: color,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Номер + сумма
                          Text(
                            '${r.number} — ${r.amount.toStringAsFixed(2)} ${r.currency}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Контрагент
                          Text(
                            'Контрагент: ${r.contractorName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Дата + запитувач
                          Text(
                            'Дата: ${fmtDate(r.date)}\nЗапитувач: ${r.requesterName}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Строка со статусом и кнопками
                          Row(
                            children: [
                              // чіп статусу
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  paymentStatusHuman(r.status),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Відхилити',
                                icon: const Icon(
                                  Icons.close,
                                  size: 20,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _onChangeStatus(
                                  context,
                                  r,
                                  PaymentRequestStatus.rejected,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Погодити',
                                icon: const Icon(
                                  Icons.check,
                                  size: 20,
                                  color: Colors.green,
                                ),
                                onPressed: () => _onChangeStatus(
                                  context,
                                  r,
                                  PaymentRequestStatus.approved,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _onChangeStatus(
      BuildContext context,
      PaymentRequest request,
      PaymentRequestStatus newStatus,
      ) async {
    final service = context.read<ApprovalsService>();

    try {
      await service.changeStatus(
        requestId: request.id,
        newStatus: newStatus,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == PaymentRequestStatus.approved
                ? 'Заявку ${request.number} погоджено'
                : 'Заявку ${request.number} відхилено',
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
}
