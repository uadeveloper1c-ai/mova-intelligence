// lib/features/approvals/presentation/payment_request_details_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../approvals_service.dart';
import '../domain/payment_request.dart';

class PaymentRequestDetailsPage extends StatefulWidget {
  final String requestId;

  const PaymentRequestDetailsPage({
    super.key,
    required this.requestId,
  });

  @override
  State<PaymentRequestDetailsPage> createState() =>
      _PaymentRequestDetailsPageState();
}

class _PaymentRequestDetailsPageState
    extends State<PaymentRequestDetailsPage> {
  PaymentRequest? _request;
  bool _loading = true;
  bool _actionInProgress = false;
  String? _error;

  late final ApprovalsService _service;

  @override
  void initState() {
    super.initState();
    _service = context.read<ApprovalsService>();
    _loadRequest();
  }

  Future<void> _loadRequest() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      debugPrint(
          'PaymentRequestDetailsPage: loading ${widget.requestId}');
      final req = await _service.getRequestById(widget.requestId);
      if (!mounted) return;
      setState(() {
        _request = req;
      });
    } catch (e) {
      debugPrint('PaymentRequestDetailsPage _loadRequest error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Не вдалося завантажити заявку';
      });
      // можно показать тост/снэк, но без тех. подробностей:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка завантаження заявки: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  bool get _canChangeStatus {
    final r = _request;
    if (r == null) return false;
    // менять статус можно только из "На погодженні"
    return r.status == PaymentRequestStatus.pending;
  }

  Future<void> _changeStatus(PaymentRequestStatus newStatus) async {
    final r = _request;
    if (r == null || !_canChangeStatus) return;

    setState(() {
      _actionInProgress = true;
    });

    try {
      debugPrint(
          'PaymentRequestDetailsPage: changeStatus(${r.id}) -> $newStatus');

      // можно использовать changeStatus или approveRequest/rejectRequest
      final updated = await _service.changeStatus(
        requestId: r.id,
        newStatus: newStatus,
      );

      if (!mounted) return;

      // Обновим локальное состояние (на всякий, если останемся на экране)
      setState(() {
        _request = updated;
      });

      final msg = switch (newStatus) {
        PaymentRequestStatus.approved => 'Заявку погоджено',
        PaymentRequestStatus.rejected => 'Заявку відхилено',
        _ => 'Статус заявки змінено',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );

      // 🔹 ВАЖНО: закрываем экран и возвращаем true,
      // чтобы родительский список мог при желании перезагрузиться.
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('PaymentRequestDetailsPage _changeStatus error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Не вдалося змінити статус заявки';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка зміни статусу: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadRequest,
                child: const Text('Спробувати ще раз'),
              ),
            ],
          ),
        ),
      );
    }

    final r = _request;
    if (r == null) {
      // на всякий случай
      return const Center(
        child: Text('Заявку не знайдено'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Заявка №${r.number}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Основная карточка заявки
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DefaultTextStyle(
                  style: theme.textTheme.bodyMedium!,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Сума: ${r.amount.toStringAsFixed(2)} ${r.currency}',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (r.contractorName.isNotEmpty)
                        Text('Контрагент: ${r.contractorName}'),
                      if (r.purpose.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Призначення:'),
                        Text(r.purpose),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Статус: ${paymentStatusHuman(r.status)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (r.requesterName.isNotEmpty)
                        Text('Заявник: ${r.requesterName}'),
                      if (r.approverName.isNotEmpty)
                        Text('Погоджуючий: ${r.approverName}'),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Кнопки действий
            if (_canChangeStatus)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                      _actionInProgress ? null : () => _changeStatus(
                        PaymentRequestStatus.approved,
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('Погодити'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                      _actionInProgress ? null : () => _changeStatus(
                        PaymentRequestStatus.rejected,
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('Відхилити'),
                    ),
                  ),
                ],
              )
            else
              Text(
                'Статус: ${paymentStatusHuman(r.status)}',
                style: theme.textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}
