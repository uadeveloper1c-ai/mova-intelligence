import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../cold_department_models.dart';
import '../production_service.dart';

class ColdDepartmentPage extends StatefulWidget {
  const ColdDepartmentPage({super.key});

  @override
  State<ColdDepartmentPage> createState() => _ColdDepartmentPageState();
}

class _ColdDepartmentPageState extends State<ColdDepartmentPage> {
  late Future<ColdDepartmentData> _future = _load();

  Future<ColdDepartmentData> _load() =>
      context.read<ProductionService>().getColdDepartment();

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  Future<void> _openAddition(
    ColdDepartmentPassport passport,
    List<ColdDepartmentStockItem> items,
  ) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ColdAdditionDialog(
        passport: passport,
        items: items,
      ),
    );
    if (changed == true && mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Холодне відділення',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Внесення компонентів у ЦКТ та ланцюжок напівфабрикатів',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Оновити',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FutureBuilder<ColdDepartmentData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return _MessageBox(
                  message: _errorText(snapshot.error),
                  onRetry: _refresh,
                );
              }
              final data = snapshot.data!;
              if (data.passports.isEmpty) {
                return const _MessageBox(
                  message: 'Немає паспортів у холодному відділенні',
                );
              }
              return _PassportTable(
                passports: data.passports,
                onAdd: (passport) => _openAddition(passport, data.items),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PassportTable extends StatelessWidget {
  const _PassportTable({
    required this.passports,
    required this.onAdd,
  });

  final List<ColdDepartmentPassport> passports;
  final ValueChanged<ColdDepartmentPassport> onAdd;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowHeight: 42,
              dataRowMinHeight: 54,
              dataRowMaxHeight: 62,
              columnSpacing: 22,
              columns: const [
                DataColumn(label: Text('Партія')),
                DataColumn(label: Text('Початковий продукт')),
                DataColumn(label: Text('Поточний напівфабрикат')),
                DataColumn(label: Text('ЦКТ')),
                DataColumn(label: Text('Об’єм')),
                DataColumn(label: Text('Статус')),
                DataColumn(label: Text('Внесень')),
                DataColumn(label: Text('Дії')),
              ],
              rows: [
                for (final passport in passports)
                  DataRow(cells: [
                    DataCell(Text(
                      '#${passport.batchNumber}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    )),
                    DataCell(Text(passport.productName)),
                    DataCell(SizedBox(
                      width: 250,
                      child: Text(
                        passport.currentProductName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    )),
                    DataCell(Text(passport.cktName)),
                    DataCell(Text('${_num(passport.actualVolume)} л')),
                    DataCell(Chip(
                      label: Text(passport.status),
                      visualDensity: VisualDensity.compact,
                    )),
                    DataCell(Text('${passport.additions.length}')),
                    DataCell(FilledButton.icon(
                      onPressed: passport.actualVolume > 0
                          ? () => onAdd(passport)
                          : null,
                      icon: const Icon(Icons.add_circle_outline, size: 17),
                      label: const Text('Додати'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: const RoundedRectangleBorder(),
                      ),
                    )),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ColdAdditionDialog extends StatefulWidget {
  const _ColdAdditionDialog({
    required this.passport,
    required this.items,
  });

  final ColdDepartmentPassport passport;
  final List<ColdDepartmentStockItem> items;

  @override
  State<_ColdAdditionDialog> createState() => _ColdAdditionDialogState();
}

class _ColdAdditionDialogState extends State<_ColdAdditionDialog> {
  final _comment = TextEditingController();
  final _lines = <_ColdAdditionLine>[_ColdAdditionLine()];
  late final String _operationId;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _operationId =
        '${widget.passport.id}-${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    _comment.dispose();
    super.dispose();
  }

  double _quantityValue(_ColdAdditionLine line) =>
      double.tryParse(line.quantity.text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _submit() async {
    final drafts = <ColdDepartmentAdditionDraft>[];
    final selectedKeys = <String>{};
    for (var index = 0; index < _lines.length; index++) {
      final line = _lines[index];
      final item = line.item;
      if (item == null) {
        setState(() => _error = 'Оберіть компонент у рядку ${index + 1}');
        return;
      }
      final key = '${item.uid}|${item.characteristicUid}';
      if (!selectedKeys.add(key)) {
        setState(() => _error = 'Компонент «${item.name}» обрано двічі');
        return;
      }
      final quantity = _quantityValue(line);
      if (quantity <= 0 || quantity > item.balance) {
        setState(
            () => _error = 'Рядок ${index + 1}: перевірте кількість. Доступно '
                '${_num(item.balance)} ${item.unitName}');
        return;
      }
      drafts.add(ColdDepartmentAdditionDraft(
        itemUid: item.uid,
        characteristicUid: item.characteristicUid,
        quantity: quantity,
      ));
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<ProductionService>().addColdDepartmentAdditions(
            passportUid: widget.passport.id,
            items: drafts,
            operationId: _operationId,
            comment: _comment.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _errorText(error);
      });
    }
  }

  void _addLine() {
    setState(() {
      _lines.add(_ColdAdditionLine());
      _error = null;
    });
  }

  void _removeLine(int index) {
    if (_lines.length == 1) return;
    final line = _lines.removeAt(index);
    line.dispose();
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedItems = _lines
        .map((line) => line.item)
        .whereType<ColdDepartmentStockItem>()
        .toList();
    final resultName = selectedItems.isEmpty
        ? ''
        : '${widget.passport.currentProductName} '
                '${selectedItems.map((item) => item.name).join(' ')}'
            .trim();

    return AlertDialog(
      title: const Text('Додати компоненти у ЦКТ'),
      content: SizedBox(
        width: 820,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Table(
                border: TableBorder.all(color: Theme.of(context).dividerColor),
                children: [
                  _summaryRow('Партія', '#${widget.passport.batchNumber}'),
                  _summaryRow('ЦКТ', widget.passport.cktName),
                  _summaryRow(
                      'Поточний продукт', widget.passport.currentProductName),
                  _summaryRow('Фактичний об’єм',
                      '${_num(widget.passport.actualVolume)} л'),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      color: cs.surfaceContainerHighest,
                      child: const Row(
                        children: [
                          Expanded(
                            child: Text('Компонент',
                                style: TextStyle(fontWeight: FontWeight.w900)),
                          ),
                          SizedBox(width: 12),
                          SizedBox(
                            width: 170,
                            child: Text('Кількість',
                                style: TextStyle(fontWeight: FontWeight.w900)),
                          ),
                          SizedBox(width: 44),
                        ],
                      ),
                    ),
                    for (var index = 0; index < _lines.length; index++)
                      _additionRow(index),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _busy ? null : _addLine,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Додати позицію'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _comment,
                enabled: !_busy,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Коментар'),
              ),
              if (resultName.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: .28),
                    border:
                        Border.all(color: cs.primary.withValues(alpha: .35)),
                  ),
                  child: Text(
                    'Результат: $resultName\n'
                    'Одна специфікація та один документ виробництва для '
                    '${selectedItems.length} поз.',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(
                        color: cs.error, fontWeight: FontWeight.w700)),
              ],
              if (widget.passport.additions.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text('Історія внесень',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                for (final row in widget.passport.additions)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Text(
                      '${row.itemName}: ${_num(row.quantity)} → ${row.afterName}'
                      '${row.documentNumber.isEmpty ? '' : ' · №${row.documentNumber}'}',
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Скасувати'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.precision_manufacturing_outlined, size: 18),
          label: Text(_busy ? 'Створення…' : 'Створити та провести'),
        ),
      ],
    );
  }

  Widget _additionRow(int index) {
    final line = _lines[index];
    final item = line.item;
    final selectedElsewhere = _lines
        .where((candidate) => !identical(candidate, line))
        .map((candidate) => candidate.item)
        .whereType<ColdDepartmentStockItem>()
        .map((candidate) => '${candidate.uid}|${candidate.characteristicUid}')
        .toSet();
    final availableItems = widget.items
        .where((stock) =>
            stock == item ||
            !selectedElsewhere
                .contains('${stock.uid}|${stock.characteristicUid}'))
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DropdownMenu<ColdDepartmentStockItem>(
              key: ValueKey(line),
              width: 540,
              initialSelection: item,
              enableFilter: true,
              enableSearch: true,
              requestFocusOnTap: true,
              menuHeight: 360,
              label: Text('Позиція ${index + 1}'),
              dropdownMenuEntries: [
                for (final stock in availableItems)
                  DropdownMenuEntry(
                    value: stock,
                    label:
                        '${stock.name}${stock.characteristicName.isEmpty ? '' : ' · ${stock.characteristicName}'}',
                    labelWidget: SizedBox(
                      width: 485,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${stock.name}${stock.characteristicName.isEmpty ? '' : ' · ${stock.characteristicName}'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${_num(stock.balance)} ${stock.unitName}'.trim(),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              onSelected: _busy
                  ? null
                  : (value) => setState(() {
                        line.item = value;
                        _error = null;
                      }),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 170,
            child: TextField(
              controller: line.quantity,
              enabled: !_busy,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Кількість',
                suffixText: item?.unitName ?? '',
                helperText:
                    item == null ? null : 'Доступно ${_num(item.balance)}',
              ),
            ),
          ),
          IconButton(
            tooltip: 'Видалити позицію',
            onPressed:
                _busy || _lines.length == 1 ? null : () => _removeLine(index),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }

  TableRow _summaryRow(String label, String value) => TableRow(children: [
        Padding(
          padding: const EdgeInsets.all(9),
          child:
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Padding(
          padding: const EdgeInsets.all(9),
          child:
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      ]);
}

class _ColdAdditionLine {
  ColdDepartmentStockItem? item;
  final quantity = TextEditingController();

  void dispose() => quantity.dispose();
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
        height: 240,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.ac_unit_rounded, size: 40),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторити'),
              ),
            ],
          ],
        ),
      );
}

String _num(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
}

String _errorText(Object? error) {
  final text = error?.toString() ?? 'Невідома помилка';
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}
