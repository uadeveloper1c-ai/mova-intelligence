import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../production_service.dart';

class ProductionRequestDetailsPage extends StatefulWidget {
  const ProductionRequestDetailsPage({super.key, required this.uid});

  final String uid;

  @override
  State<ProductionRequestDetailsPage> createState() =>
      _ProductionRequestDetailsPageState();
}

class _ProductionRequestDetailsPageState
    extends State<ProductionRequestDetailsPage> {
  late Future<ProductionRequest> _future;
  bool _isCancelling = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _future = context.read<ProductionService>().getRequestById(widget.uid);
  }

  Future<void> _refresh() async {
    final future = context.read<ProductionService>().getRequestById(widget.uid);
    setState(() => _future = future);
    await future;
  }

  Future<void> _editRequest(ProductionRequest request) async {
    final quantityControllers = [
      for (final line in request.lines)
        TextEditingController(text: _formatQuantity(line.quantity)),
    ];
    final commentController = TextEditingController(
      text: _displayComment(request.comment),
    );
    var requiredDate = request.desiredReceiptDate ?? DateTime.now();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Редагувати замовлення №${request.number}'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Бажана дата надходження'),
                    subtitle: Text(_formatDate(requiredDate)),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: dialogContext,
                        initialDate: requiredDate,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 1),
                        ),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365),
                        ),
                      );
                      if (selected != null) {
                        setDialogState(() => requiredDate = selected);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  for (var index = 0;
                      index < request.lines.length;
                      index++) ...[
                    TextField(
                      controller: quantityControllers[index],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: request.lines[index].itemName,
                        suffixText: request.lines[index].unitName,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: commentController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Коментар'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Після передачі до WMS редагування буде заблоковано.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Скасувати'),
            ),
            FilledButton(
              onPressed: () {
                final quantities = <double>[];
                for (final controller in quantityControllers) {
                  final value = double.tryParse(
                    controller.text.trim().replaceAll(',', '.'),
                  );
                  if (value == null || value <= 0) return;
                  quantities.add(value);
                }
                Navigator.pop(dialogContext, {
                  'requiredDate': requiredDate,
                  'comment': commentController.text.trim(),
                  'quantities': quantities,
                });
              },
              child: const Text('Зберегти'),
            ),
          ],
        ),
      ),
    );

    for (final controller in quantityControllers) {
      controller.dispose();
    }
    commentController.dispose();
    if (result == null || !mounted) return;

    setState(() => _isEditing = true);
    try {
      final updated = await context.read<ProductionService>().updateRequest(
            uid: request.id,
            requiredDate: result['requiredDate'] as DateTime,
            comment: result['comment'] as String,
            quantities: List<double>.from(result['quantities'] as List),
          );
      if (!mounted) return;
      setState(() => _future = Future.value(updated));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Замовлення оновлено')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isEditing = false);
    }
  }

  Future<void> _cancelRequest(ProductionRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Скасувати замовлення?'),
        content: Text(
          'Замовлення №${request.number} ще не передано до WMS і буде скасовано в 1С. Цю дію не можна скасувати.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Залишити'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Скасувати замовлення'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);
    try {
      await context.read<ProductionService>().cancelRequest(request.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Замовлення скасовано')),
      );
      context.pop(true);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      setState(() => _isCancelling = false);
    }
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _displayComment(String value) {
    var text = value.trim();
    if (text.startsWith('[MOVA]')) {
      text = text.substring(6).trim();
    }
    while (text.startsWith(';')) {
      text = text.substring(1).trim();
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<ProductionRequest>(
        future: _future,
        builder: (context, snapshot) {
          final request = snapshot.data;
          return ListView(
            padding: EdgeInsets.all(desktop ? 20 : 12),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Назад',
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Замовлення на переміщення',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (request != null)
                          Text(
                            request.number.isEmpty
                                ? request.title
                                : '№ ${request.number}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: .62),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Оновити',
                    onPressed:
                        snapshot.connectionState == ConnectionState.waiting
                            ? null
                            : _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                _DetailsPanel(
                  border: border,
                  child: ListTile(
                    leading: const Icon(Icons.error_outline_rounded),
                    title: const Text('Не вдалося завантажити замовлення'),
                    subtitle: Text('${snapshot.error}'),
                  ),
                )
              else if (request != null) ...[
                _DetailsPanel(
                  border: border,
                  child: Column(
                    children: [
                      _InfoRow(label: 'Статус', value: request.status),
                      _InfoRow(
                        label: 'WMS',
                        value: request.wmsStatus.trim().isEmpty
                            ? 'Не вигружено'
                            : request.wmsStatus,
                      ),
                      _InfoRow(
                          label: 'Дата', value: _formatDate(request.createdAt)),
                      if (request.desiredReceiptDate != null)
                        _InfoRow(
                          label: 'Бажана дата надходження',
                          value: _formatDate(request.desiredReceiptDate!),
                        ),
                      if (request.wmsStatus.trim().isEmpty &&
                          request.wmsDispatchAt != null)
                        _InfoRow(
                          label: 'Автовідправлення до WMS',
                          value:
                              '${_formatDate(request.wmsDispatchAt!)} ${request.wmsDispatchAt!.hour.toString().padLeft(2, '0')}:${request.wmsDispatchAt!.minute.toString().padLeft(2, '0')}',
                        ),
                      if (request.organization.trim().isNotEmpty)
                        _InfoRow(
                            label: 'Організація', value: request.organization),
                      _InfoRow(
                        label: 'Склад-відправник',
                        value: request.sourceWarehouse,
                      ),
                      _InfoRow(
                        label: 'Склад-отримувач',
                        value: request.destinationWarehouse,
                      ),
                      if (_displayComment(request.comment).isNotEmpty)
                        _InfoRow(
                          label: 'Коментар',
                          value: _displayComment(request.comment),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _DetailsPanel(
                  border: border,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: Text(
                          'Товари',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (request.lines.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Text(
                            'Рядки не повернулись з API',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: .58),
                            ),
                          ),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 34,
                            dataRowMinHeight: 38,
                            dataRowMaxHeight: 44,
                            horizontalMargin: 12,
                            columnSpacing: 22,
                            border: TableBorder.all(color: border),
                            columns: const [
                              DataColumn(label: Text('N')),
                              DataColumn(label: Text('Номенклатура')),
                              DataColumn(label: Text('Дія')),
                              DataColumn(
                                  label: Text('Кількість'), numeric: true),
                              DataColumn(label: Text('Од.')),
                            ],
                            rows: [
                              for (final line in request.lines)
                                DataRow(cells: [
                                  DataCell(Text(line.number == 0
                                      ? '—'
                                      : '${line.number}')),
                                  DataCell(SizedBox(
                                      width: 320, child: Text(line.itemName))),
                                  DataCell(SizedBox(
                                    width: 220,
                                    child: Text(
                                        line.supplyActionName.trim().isEmpty
                                            ? '—'
                                            : line.supplyActionName),
                                  )),
                                  DataCell(
                                      Text(_formatQuantity(line.quantity))),
                                  DataCell(Text(line.unitName.trim().isEmpty
                                      ? '—'
                                      : line.unitName)),
                                ]),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (request.canEdit || request.canCancel) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      if (request.canEdit)
                        OutlinedButton.icon(
                          onPressed: _isEditing || _isCancelling
                              ? null
                              : () => _editRequest(request),
                          icon: _isEditing
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.edit_outlined),
                          label:
                              Text(_isEditing ? 'Збереження…' : 'Редагувати'),
                        ),
                      if (request.canCancel)
                        FilledButton.icon(
                          onPressed: _isEditing || _isCancelling
                              ? null
                              : () => _cancelRequest(request),
                          icon: _isCancelling
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.cancel_outlined),
                          label: Text(
                            _isCancelling
                                ? 'Скасування…'
                                : 'Скасувати замовлення',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.error,
                            foregroundColor: cs.onError,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({required this.border, required this.child});

  final Color border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: .58),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
