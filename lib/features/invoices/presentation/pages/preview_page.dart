import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../approvals/approvals_service.dart';
import '../../domain/invoice.dart';

class PreviewPage extends StatelessWidget {
  final Invoice invoice;

  const PreviewPage({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Перевірка рахунку'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ... твои поля с суммой, контрагентом и т.п.

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Створити заявку на оплату'),
                onPressed: () async {
                  final approvals = context.read<ApprovalsService>();

                  try {
                    final req = await approvals.createFromInvoice(
                      invoiceId: invoice.id,                // подставь свои поля
                      amount: invoice.amount,
                      purpose: invoice.purpose,
                      supplierName: invoice.supplierName,
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Заявку ${req.number} відправлено на погодження',
                          ),
                        ),
                      );
                      Navigator.of(context).pop(); // вернуться к списку счетов
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Помилка: $e')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
