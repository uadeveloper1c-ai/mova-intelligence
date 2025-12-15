import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/payment_request.dart';
import 'incoming_requests_list.dart';
import 'my_requests_list.dart';

class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({super.key});

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage> {
  DateTimeRange? _range;
  PaymentRequestStatus? _statusFilter;
  String _contractorQuery = '';

  String get _rangeLabel {
    if (_range == null) return 'Увесь період';
    final start = _range!.start;
    final end = _range!.end;
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.'
            '${d.month.toString().padLeft(2, '0')}.'
            '${d.year}';
    return '${fmt(start)} — ${fmt(end)}';
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
    );

    if (picked != null) {
      setState(() => _range = picked);
    }
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

  List<DropdownMenuItem<PaymentRequestStatus?>> _buildStatusItems() {
    final items = <DropdownMenuItem<PaymentRequestStatus?>>[];

    items.add(
      const DropdownMenuItem<PaymentRequestStatus?>(
        value: null,
        child: Text('Усі статуси'),
      ),
    );

    for (final s in PaymentRequestStatus.values) {
      items.add(
        DropdownMenuItem<PaymentRequestStatus?>(
          value: s,
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _statusColor(s),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(paymentStatusHuman(s)),
            ],
          ),
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Заявки на оплату'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Column(
            children: [
              Card(
                color: Colors.white.withOpacity(0.95),
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: Colors.black87,
                      unselectedLabelColor: Colors.black54,
                      indicatorColor: Colors.deepPurple,
                      tabs: [
                        Tab(text: 'На погодженні'),
                        Tab(text: 'Мої заявки'),
                      ],
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Нова заявка'),
                                  onPressed: () {
                                    // відкриваємо форму нової заявки
                                    context.pushNamed('newPaymentRequest');
                                    // або: context.push('/approvals/new');
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.date_range),
                                label: Text(_rangeLabel),
                                onPressed: _pickRange,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              SizedBox(
                                width: 170,
                                child: DropdownButtonFormField<
                                    PaymentRequestStatus?>(
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Статус',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                  ),
                                  initialValue: _statusFilter,
                                  items: _buildStatusItems(),
                                  onChanged: (value) {
                                    setState(() => _statusFilter = value);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText: 'Контрагент',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  onChanged: (value) {
                                    setState(() => _contractorQuery = value);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: TabBarView(
                  children: [
                    IncomingRequestsList(
                      range: _range,
                      statusFilter: _statusFilter,
                      contractorQuery: _contractorQuery,
                    ),
                    MyRequestsList(
                      range: _range,
                      statusFilter: _statusFilter,
                      contractorQuery: _contractorQuery,
                    ),
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
