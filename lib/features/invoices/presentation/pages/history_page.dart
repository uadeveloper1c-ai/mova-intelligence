import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
// импорт модели/адаптера
import '../../domain/invoice.dart'; // ПУТЬ из папки pages к domain

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Invoice>('invoices_history');

    return Scaffold(
      appBar: AppBar(title: const Text('История')),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<Invoice> b, _) {
          if (b.isEmpty) {
            return const Center(child: Text('Пока пусто'));
          }
          return ListView.separated(
            itemCount: b.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final inv = b.getAt(index)!;
              return Dismissible(
                key: ValueKey('inv_$index'),
                background: Container(color: Colors.redAccent),
                onDismissed: (_) => b.deleteAt(index),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text('${inv.number} — ${inv.amount.toStringAsFixed(2)}'),
                  subtitle: Text(
                    '${inv.supplier}\n${inv.date.toIso8601String().split('T').first}',
                    maxLines: 2,
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: box.isNotEmpty
          ? FloatingActionButton.extended(
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Очистить историю?'),
              content: const Text('Это удалит все записи без возможности восстановления.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Очистить')),
              ],
            ),
          );
          if (ok == true) {
            await box.clear();
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('История очищена')),
            );
          }
        },
        icon: const Icon(Icons.delete_sweep_outlined),
        label: const Text('Очистить'),
      )
          : null,
    );
  }
}
